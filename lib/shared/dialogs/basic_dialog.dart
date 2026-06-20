import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

enum ConfirmType { primary, delete }

/// Brutalism-styled dialog shell (DESIGN.md): opaque warm surface, thick black
/// border + hard shadow (no blur), Bricolage/Space Grotesk type. Every `show*`
/// helper below renders through this so dialogs match the rest of the app.
class _BrutalDialog extends StatelessWidget {
  const _BrutalDialog({
    this.icon,
    required this.title,
    this.content,
    required this.actions,
  });

  final Widget? icon;
  final String title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        decoration: brutalDecoration(
          color: BrutalColors.surface,
          radius: BrutalSpec.cardRadius,
          offset: BrutalSpec.shadowOffset,
          borderWidth: BrutalSpec.borderWidth,
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: const IconThemeData(
                  color: BrutalColors.onBackground,
                  size: 32,
                ),
                child: Center(child: icon),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: BrutalText.headlineLgMobile(fontSize: 22),
            ),
            if (content != null) ...[
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    textAlign: TextAlign.center,
                    style: BrutalText.body(
                      fontSize: 15,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                    child: content!,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Brutalism action button (filled, hard shadow, press animation) used inside
/// [_BrutalDialog].
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      onTap: onTap,
      color: color,
      radius: BrutalSpec.pillRadius,
      restOffset: BrutalSpec.shadowOffsetMobile,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: BrutalText.labelBold(fontSize: 15, color: textColor),
      ),
    );
  }
}

/// Confirm-button colour pair for the given [ConfirmType] (yellow primary vs.
/// red destructive).
(Color bg, Color fg) _confirmColors(ConfirmType type) =>
    type == ConfirmType.delete
    ? (BrutalColors.dangerBanner, BrutalColors.onError)
    : (BrutalColors.primaryContainer, BrutalColors.onBackground);

const _dismissBg = BrutalColors.surfaceContainerHigh;
const _dismissFg = BrutalColors.onBackground;

Future<void> showBasicDialog(
  BuildContext context, {
  required String title,
  required String text,
  String? buttonText,
  VoidCallback? onDismiss,
  VoidCallback? onClick,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _BrutalDialog(
      title: title,
      content: Text(text),
      actions: [
        _DialogButton(
          label: buttonText ?? 'confirm'.tr(),
          color: BrutalColors.primaryContainer,
          textColor: BrutalColors.onBackground,
          onTap: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );

  if (result == true) {
    onClick?.call();
  } else {
    onDismiss?.call();
  }
}

Future<void> showContentDialog(
  BuildContext context, {
  required String title,
  Widget? content,
  String? dismissText,
  String? confirmText,
  ConfirmType confirmType = ConfirmType.primary,
  VoidCallback? onDismiss,
  VoidCallback? onClick,
}) async {
  final (confirmBg, confirmFg) = _confirmColors(confirmType);
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _BrutalDialog(
      title: title,
      content: content,
      actions: [
        _DialogButton(
          label: dismissText ?? 'cancel'.tr(),
          color: _dismissBg,
          textColor: _dismissFg,
          onTap: () => Navigator.of(dialogContext).pop(false),
        ),
        _DialogButton(
          label: confirmText ?? 'confirm'.tr(),
          color: confirmBg,
          textColor: confirmFg,
          onTap: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );

  if (result == true) {
    onClick?.call();
  } else {
    onDismiss?.call();
  }
}

Future<void> showConfirmLeaveDialog(
  BuildContext context, {
  Icon? icon,
  required String title,
  required String text,
  String? confirmText,
  ConfirmType confirmType = ConfirmType.primary,
  String? dismissText,
  VoidCallback? onDismiss,
  required VoidCallback onConfirm,
}) async {
  final (confirmBg, confirmFg) = _confirmColors(confirmType);
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _BrutalDialog(
      icon: icon,
      title: title,
      content: Text(text),
      actions: [
        _DialogButton(
          label: dismissText ?? 'cancel'.tr(),
          color: _dismissBg,
          textColor: _dismissFg,
          onTap: () => Navigator.of(dialogContext).pop(false),
        ),
        _DialogButton(
          label: confirmText ?? 'confirm'.tr(),
          color: confirmBg,
          textColor: confirmFg,
          onTap: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );

  result == true ? onConfirm() : onDismiss?.call();
}

Future<void> showOptionsDialog(
  BuildContext context, {
  required String title,
  required Map<String, String> optionsMap,
  String? selectedKey,
  required void Function(String) onChanged,
}) async {
  if (optionsMap.isEmpty) {
    await showBasicDialog(context, title: title, text: '');
    return;
  }

  final entries = optionsMap.entries.toList();
  final result = await showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _BrutalDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            PressableBrutal(
              onTap: () => Navigator.of(dialogContext).pop(entries[i].key),
              color: entries[i].key == selectedKey
                  ? BrutalColors.primaryContainer
                  : BrutalColors.surfaceContainerHigh,
              radius: BrutalSpec.pillRadius,
              restOffset: BrutalSpec.shadowOffsetMobile,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.centerLeft,
              child: Text(
                entries[i].value,
                style: BrutalText.labelBold(fontSize: 15),
              ),
            ),
          ],
        ],
      ),
      actions: [
        _DialogButton(
          label: 'cancel'.tr(),
          color: _dismissBg,
          textColor: _dismissFg,
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );

  if (result == null || result == selectedKey) return;
  onChanged(result);
}
