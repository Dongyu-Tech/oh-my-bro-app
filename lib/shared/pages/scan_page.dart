import 'dart:async';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/models/bro_code.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Camera QR scanner for 夥伴 → 掃描. Pops a [BroCode] on a code we understand;
/// the caller resolves it against `public.users` and does the adding.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    // Without this the same code re-fires ~4x/second while it stays in frame.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Set once we've popped, so a detection already in flight can't pop twice.
  bool _handled = false;

  /// Last payload we rejected, so holding an unknown code in frame complains
  /// once instead of on every frame.
  String? _lastRejected;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final code = BroCode.parse(barcode.rawValue);
      if (code != null) {
        _handled = true;
        context.pop(code);
        return;
      }
    }

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw != null && raw != _lastRejected) {
      _lastRejected = raw;
      showErrorSnakeBar('scan_invalid'.tr());
    }
  }

  /// Toggle the flashlight, tolerating a camera that never came up.
  ///
  /// [MobileScannerController.toggleTorch] throws `controllerUninitialized`
  /// when `start()` failed — no camera (every iOS Simulator), permission
  /// denied, or the native plugin missing. That throw is async and would
  /// otherwise surface as an unhandled exception, so check the controller's
  /// own state first and still catch, since the camera can drop between the
  /// check and the call.
  Future<void> _toggleTorch() async {
    final state = _controller.value;
    if (!state.isRunning || state.torchState == TorchState.unavailable) {
      showErrorSnakeBar('scan_torch_unavailable'.tr());
      return;
    }
    try {
      await _controller.toggleTorch();
    } on MobileScannerException {
      if (!mounted) return;
      showErrorSnakeBar('scan_torch_unavailable'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                child: Row(
                  children: [
                    const BrutalBackButton(),
                    const SizedBox(width: 12),
                    Text(
                      'scan_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: brutalDecoration(
                          color: BrutalColors.onBackground,
                          radius: BrutalSpec.cardRadius,
                          offset: BrutalSpec.shadowOffsetMobile,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: MobileScanner(
                            controller: _controller,
                            onDetect: _onDetect,
                            placeholderBuilder: (_) => const ColoredBox(
                              color: BrutalColors.surfaceContainerHigh,
                            ),
                            errorBuilder: (_, error) =>
                                _ScannerError(error: error),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'scan_hint'.tr(),
                        textAlign: TextAlign.center,
                        style: BrutalText.labelBold(
                          fontSize: 14,
                          color: BrutalColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Drive the button from the controller's own state rather
                      // than a local bool, so it can't claim the torch is on
                      // after a toggle the camera rejected — and so it reads
                      // "unavailable" on hardware without a flash.
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          final on = state.torchState == TorchState.on;
                          final usable =
                              state.isRunning &&
                              state.torchState != TorchState.unavailable;
                          return Opacity(
                            opacity: usable ? 1 : 0.45,
                            child: PressableBrutal(
                              onTap: _toggleTorch,
                              color: on
                                  ? BrutalColors.primaryContainer
                                  : BrutalColors.surface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    on
                                        ? LucideIcons.flashlight
                                        : LucideIcons.flashlightOff,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'scan_torch'.tr(),
                                    style: BrutalText.labelBold(fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fills the preview box when the camera can't run — most often because the
/// user declined the permission, which no amount of retrying fixes.
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: BrutalColors.surfaceContainerHigh,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? LucideIcons.cameraOff : LucideIcons.triangleAlert,
                size: 48,
                color: BrutalColors.onBackground,
              ),
              const SizedBox(height: 12),
              Text(
                (denied ? 'scan_permission_denied' : 'scan_error').tr(),
                textAlign: TextAlign.center,
                style: BrutalText.labelBold(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
