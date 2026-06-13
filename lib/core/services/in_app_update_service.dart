import 'dart:io';

import 'package:flutter/services.dart';

import '../error/result.dart';

/// Thin MethodChannel wrapper for Android in-app updates.
///
/// The Dart side just bridges into the platform plugin you wire up on the
/// Android side (typically `com.google.android.play:app-update`). iOS is a
/// no-op until/unless you implement an equivalent App Store check.
class InAppUpdateService {
  static const _channel = MethodChannel('com.dongyutech.heymybro/in_app_update');

  /// Returns true if a Play Store update is available. iOS always returns
  /// false (no native implementation by design).
  Future<Result<bool>> checkForUpdate() async {
    if (!Platform.isAndroid) return const Result.ok(false);
    try {
      final available = await _channel.invokeMethod<bool>('checkForUpdate');
      return Result.ok(available ?? false);
    } on PlatformException catch (e) {
      return Result.error(e);
    }
  }

  /// Trigger an immediate (blocking) update flow on Android.
  Future<Result<void>> startImmediateUpdate() async {
    if (!Platform.isAndroid) return const Result.ok(null);
    try {
      await _channel.invokeMethod('startImmediateUpdate');
      return const Result.ok(null);
    } on PlatformException catch (e) {
      return Result.error(e);
    }
  }

  /// Trigger a flexible (background download) update flow on Android.
  Future<Result<void>> startFlexibleUpdate() async {
    if (!Platform.isAndroid) return const Result.ok(null);
    try {
      await _channel.invokeMethod('startFlexibleUpdate');
      return const Result.ok(null);
    } on PlatformException catch (e) {
      return Result.error(e);
    }
  }

  /// Complete a flexible update that has finished downloading. Call after
  /// the user accepts the install prompt.
  Future<Result<void>> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return const Result.ok(null);
    try {
      await _channel.invokeMethod('completeFlexibleUpdate');
      return const Result.ok(null);
    } on PlatformException catch (e) {
      return Result.error(e);
    }
  }
}
