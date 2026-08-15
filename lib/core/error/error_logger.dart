import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app.dart';

/// Console-only trace of what a subsystem actually did. Never reaches the user.
///
/// For the cases where the code is right in every test and still wrong on a
/// device: the only way to find out which step disagrees with expectation is
/// to have each step say what it saw.
void logAppTrace(String where, String detail) {
  if (kDebugMode) debugPrint('[$where] $detail');
}

/// Console-only detail about a failure. Never reaches the user.
///
/// The snackbar has to say something a person can act on, which usually means
/// something vague like "couldn't send that". That is fine for them and
/// useless for you: it is the same sentence whether the server refused, the
/// network died, or a code path returned something nobody expected. Log the
/// specific cause here so the console can tell those apart.
void logAppError(String where, Object? cause, [StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  debugPrint('[App Error] $where${cause == null ? '' : ' — $cause'}');
  if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
}

/// Red-tinted snackbar for errors. Uses the global ScaffoldMessenger key so it
/// works without a BuildContext and is safe across async gaps.
///
/// Pass [cause] whenever the message shown is a generic stand-in for something
/// more specific — it is logged, never displayed.
void showErrorSnakeBar(String message, {Object? cause}) {
  if (kDebugMode) {
    debugPrint('[App Error] $message${cause == null ? '' : ' — $cause'}');
  }
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
