import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:heymybro/shared/models/bro_code.dart';
import 'package:heymybro/shared/widgets/brutal_qr.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// How much of the screen the sheet takes. Left to size itself the sheet hugs
/// its content and the code comes out barely bigger than the card that opened
/// it; taken full-screen it buries the barrier and needs a close button of its
/// own. Half, pinned, is the balance.
const double _kSheetHeightFraction = 0.5;

/// Bottom sheet showing the signed-in user's share code as a QR big enough to
/// scan across a table, with the screen turned up to full for as long as it is
/// open.
///
/// Opened from the 帳號 → 掃描分享 ID card, which owns the small preview of the
/// same code. [payload] is a [BroCode] string — it carries the account id, so
/// the scanning device can resolve a real user rather than guess at a name.
/// [label] is the human-readable line printed underneath (their `@handle`);
/// the QR itself is not something anyone can read off the screen.
Future<void> showShareIdSheet(
  BuildContext context, {
  required String payload,
  required String label,
  DateTime? expiresAt,
}) {
  assert(payload.isNotEmpty, 'share ID sheet needs a payload to encode');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Fixed height, full width. Passing constraints also drops Material's own
    // max-width cap, which would otherwise inset the sheet on wider screens.
    constraints: BoxConstraints.tightFor(
      height: MediaQuery.sizeOf(context).height * _kSheetHeightFraction,
    ),
    builder: (_) =>
        ShareIdSheet(payload: payload, label: label, expiresAt: expiresAt),
  );
}

/// The sheet body. Public so it can be found in widget tests and reused if the
/// share ID ever wants a route of its own; the way in is [showShareIdSheet].
class ShareIdSheet extends StatefulWidget {
  const ShareIdSheet({
    super.key,
    required this.payload,
    required this.label,
    this.expiresAt,
  });

  /// What the QR encodes — see [BroCode].
  final String payload;

  /// What a human reads under it.
  final String label;

  /// When the code stops working. Shown so nobody holds up a dead square
  /// wondering why the other phone keeps refusing it.
  final DateTime? expiresAt;

  @override
  State<ShareIdSheet> createState() => _ShareIdSheetState();
}

class _ShareIdSheetState extends State<ShareIdSheet> {
  @override
  void initState() {
    super.initState();
    _setBrightness(full: true);
  }

  @override
  void dispose() {
    // Fire-and-forget: the state is gone before the platform call lands, and
    // there is nothing left to report to.
    _setBrightness(full: false);
    super.dispose();
  }

  /// Application-scoped brightness only — no permission, and the OS restores
  /// the user's own level for every other app. Failures are deliberately
  /// swallowed: a desktop build, an emulator without the plugin, or an OS that
  /// refuses still leaves a perfectly scannable QR on screen.
  Future<void> _setBrightness({required bool full}) async {
    try {
      if (full) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(1);
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (_) {
      // Brightness is a nicety, never a precondition for showing the code.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrutalSheet(
      child: Column(
        children: [
          Text(
            'account_share_id_sheet_title'.tr(),
            style: BrutalText.headlineLgMobile(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'account_share_id_sheet_hint'.tr(),
            textAlign: TextAlign.center,
            style: BrutalText.body(
              fontSize: 14,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          // The code takes whatever the text leaves, so it is as large as the
          // half-screen allows without any of it needing to be measured here.
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side =
                      math.min(constraints.maxWidth, constraints.maxHeight) -
                      BrutalSpec.shadowOffsetMobile;
                  return BrutalQrCode(
                    data: widget.payload,
                    size: side,
                    radius: BrutalSpec.cardRadius,
                    shadowOffset: BrutalSpec.shadowOffsetMobile,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: BrutalText.labelBold(fontSize: 15),
          ),
          if (widget.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'share_id_expires'.tr(
                namedArgs: {'time': DateFormat.Hm().format(widget.expiresAt!)},
              ),
              textAlign: TextAlign.center,
              style: BrutalText.labelBold(
                fontSize: 12,
                color: BrutalColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
