import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../app.dart';

/// Red-tinted snackbar for errors. Uses the global ScaffoldMessenger key so it
/// works without a BuildContext and is safe across async gaps.
void showErrorSnakeBar(String message) {
  debugPrint('[App Error] $message');
  App.scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.redAccent,
    ),
  );
}

/// Plain short-lived informational snackbar.
void showMessage(String message) {
  App.scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      duration: const Duration(seconds: 1),
    ),
  );
}

/// Convenience for "not implemented yet" UX touches.
void comingSoon() {
  App.scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(
        'coming_soon'.tr(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      duration: const Duration(seconds: 1),
    ),
  );
}
