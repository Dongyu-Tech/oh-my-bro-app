import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';

/// SharedPreferences-backed repository for AppSettingsModel.
///
/// Keys are namespaced under `settings.*` so SP dumps remain greppable.
/// Add a new key here only when you actually persist a new setting — values
/// kept solely in memory belong in the notifier, not here.
enum AppSettingsKey {
  themeMode('settings.theme_mode'),
  language('settings.language'),
  themeColor('settings.theme_color');

  const AppSettingsKey(this.value);
  final String value;
}

class AppSettingsRepository {
  AppSettingsRepository(this._sp);

  final SharedPreferences _sp;

  Future<AppSettingsModel> save(AppSettingsModel model) async {
    await _sp.setString(AppSettingsKey.themeMode.value, model.themeMode.name);
    await _sp.setString(AppSettingsKey.language.value, model.language.name);
    await _sp.setInt(
      AppSettingsKey.themeColor.value,
      model.themeColor.toARGB32(),
    );
    return load();
  }

  AppSettingsModel load() {
    final themeMode =
        ThemeModeX.fromString(_sp.getString(AppSettingsKey.themeMode.value));
    final language =
        AppLanguageX.fromString(_sp.getString(AppSettingsKey.language.value));
    final colorInt = _sp.getInt(AppSettingsKey.themeColor.value);

    return AppSettingsModel(
      themeMode: themeMode,
      language: language,
      themeColor: colorInt != null
          ? const ColorIntConverter().fromJson(colorInt)
          : Colors.deepPurple,
    );
  }
}
