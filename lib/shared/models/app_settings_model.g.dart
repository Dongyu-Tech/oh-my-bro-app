// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppSettingsModel _$AppSettingsModelFromJson(Map<String, dynamic> json) =>
    _AppSettingsModel(
      themeMode:
          $enumDecodeNullable(_$ThemeModeEnumMap, json['themeMode']) ??
          ThemeMode.system,
      language:
          $enumDecodeNullable(_$AppLanguageEnumMap, json['language']) ??
          AppLanguage.english,
      themeColor: json['themeColor'] == null
          ? Colors.deepPurple
          : const ColorIntConverter().fromJson(
              (json['themeColor'] as num).toInt(),
            ),
    );

Map<String, dynamic> _$AppSettingsModelToJson(_AppSettingsModel instance) =>
    <String, dynamic>{
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
      'language': _$AppLanguageEnumMap[instance.language]!,
      'themeColor': const ColorIntConverter().toJson(instance.themeColor),
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};

const _$AppLanguageEnumMap = {
  AppLanguage.english: 'english',
  AppLanguage.chinese: 'chinese',
};
