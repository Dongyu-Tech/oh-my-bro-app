import 'package:flutter/material.dart';

extension TextStyleExtension on TextStyle? {
  TextStyle? get bold => this?.copyWith(fontWeight: FontWeight.w700);
}

/// Shorthand theme access from a [BuildContext].
///
/// * `context.textTheme` — Material text theme.
/// * `context.colorScheme` — Material color scheme (set in `app.dart`).
///
/// Note: silversole's `context.tokens` (an `AppTokens` ThemeExtension) was
/// dropped when porting this file — Oh My Bro styles through `BrutalColors` in
/// `shared/widgets/brutalism.dart`, not a Material ThemeExtension.
extension ContextThemeX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

extension ListExtension<T> on List<T> {
  /// Example:
  /// ```dart
  /// final numbers = <int>[1, 2, 3, 5, 6, 7];
  /// final result = numbers.takeLast(4); // (3, 5, 6, 7)
  /// final takeNeg = numbers.skip(-1); // () - no elements.
  /// final takeLastAll = numbers.skip(100); // (1, 2, 3, 5, 6, 7) - all elements.
  /// ```
  List<T> takeLast(int count) {
    if (count <= 0) return <T>[];
    if (count >= length) return this;
    return skip((length - count).clamp(0, length)).toList(growable: false);
  }
}
