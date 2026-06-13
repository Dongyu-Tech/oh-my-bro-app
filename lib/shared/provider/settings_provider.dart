import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';
import '../repositories/app_settings_repository.dart';

/// Throwing-placeholder DI seam — main.dart overrides this with the actual
/// instance via `ProviderScope.overrides`. Pattern works for any async-loaded
/// singleton (SharedPreferences, AppDatabase, Dio with auth, etc).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden before use.',
  ),
);

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(sharedPreferencesProvider));
});

class SettingsNotifier extends Notifier<AppSettingsModel> {
  late final AppSettingsRepository _repo;

  @override
  AppSettingsModel build() {
    _repo = ref.watch(appSettingsRepositoryProvider);
    return _repo.load();
  }

  Future<void> reload() async => state = _repo.load();

  Future<void> saveThemeMode(ThemeMode mode) async {
    state = await _repo.save(state.copyWith(themeMode: mode));
  }

  Future<void> saveLanguage(AppLanguage language) async {
    state = await _repo.save(state.copyWith(language: language));
  }

  Future<void> saveThemeColor(Color color) async {
    state = await _repo.save(state.copyWith(themeColor: color));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettingsModel>(SettingsNotifier.new);
