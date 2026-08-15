import 'package:flutter/widgets.dart';

import 'package:heymybro/shared/dialogs/basic_dialog.dart';

/// A shared yes/no confirm dialog. Returns true only if the user confirms.
/// [danger] tints the confirm action red for destructive actions.
///
/// Thin alias over [confirmBrutal] so the whole app renders confirms through the
/// one brutalist dialog shell (filled buttons, hard shadow) — matching every
/// other button in the app.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool danger = false,
}) => confirmBrutal(
  context,
  title: title,
  message: message,
  confirmLabel: confirmLabel,
  type: danger ? ConfirmType.delete : ConfirmType.primary,
);
