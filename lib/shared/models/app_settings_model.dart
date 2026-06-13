// Example freezed model showing two locked conventions:
//   1. Per-field @JsonKey if you need rename (none needed here).
//   2. JsonConverter for non-trivial types (Color <-> int).
//
// When a freezed constructor parameter uses @JsonKey, add
//   // ignore_for_file: invalid_annotation_target
// to the top of the model file.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings_model.freezed.dart';
part 'app_settings_model.g.dart';

extension ThemeModeX on ThemeMode {
  static ThemeMode fromString(String? value) => switch (value) {
        'system' => ThemeMode.system,
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

enum AppLanguage { english, chinese }

extension AppLanguageX on AppLanguage {
  static AppLanguage fromString(String? value) => switch (value) {
        'chinese' || 'zh' || 'zh_TW' => AppLanguage.chinese,
        'english' || 'en' => AppLanguage.english,
        _ => _systemDefault(),
      };

  static AppLanguage _systemDefault() {
    final locales = ui.PlatformDispatcher.instance.locales;
    final code = (locales.isNotEmpty ? locales.first.languageCode : 'en')
        .toLowerCase();
    return code == 'zh' ? AppLanguage.chinese : AppLanguage.english;
  }

  Locale get locale => switch (this) {
        AppLanguage.english => const Locale('en'),
        AppLanguage.chinese => const Locale('zh', 'TW'),
      };
}

class ColorIntConverter implements JsonConverter<Color, int> {
  const ColorIntConverter();

  @override
  Color fromJson(int json) => Color(json);

  @override
  int toJson(Color object) => object.toARGB32();
}

@freezed
abstract class AppSettingsModel with _$AppSettingsModel {
  const factory AppSettingsModel({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(AppLanguage.english) AppLanguage language,
    @ColorIntConverter() @Default(Colors.deepPurple) Color themeColor,
  }) = _AppSettingsModel;

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsModelFromJson(json);
}
