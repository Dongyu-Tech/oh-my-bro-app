import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/services/auth_service.dart';
import 'core/services/supabase_google_auth_service.dart';
import 'shared/provider/auth_provider.dart';
import 'shared/provider/settings_provider.dart';

// Compile-time config, injected at build time via --dart-define /
// --dart-define-from-file. This is the only config channel that survives onto a
// device: a mobile app cannot read your host machine's .env at runtime. In dev,
// source it from your 1Password-injected .env at BUILD time:
//   flutter run --dart-define-from-file=.env
const _secretKey = String.fromEnvironment('SECRET_KEY');
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _webClientId = String.fromEnvironment('WEB_CLIENT_ID');
const _iosClientId = String.fromEnvironment('IOS_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  // Mirror compile-time defines into dotenv for any code that reads via dotenv.
  // `.env` is still loaded for convenience but is optional and is NOT bundled on
  // mobile, so the dart-defines above are the source of truth there.
  await dotenv.load(
    fileName: '.env',
    isOptional: true,
    mergeWith: {
      if (_secretKey.isNotEmpty) 'SECRET_KEY': _secretKey,
      if (_supabaseUrl.isNotEmpty) 'SUPABASE_URL': _supabaseUrl,
      if (_supabaseAnonKey.isNotEmpty) 'SUPABASE_ANON_KEY': _supabaseAnonKey,
      if (_webClientId.isNotEmpty) 'WEB_CLIENT_ID': _webClientId,
      if (_iosClientId.isNotEmpty) 'IOS_CLIENT_ID': _iosClientId,
    },
  );

  // Real Google + Supabase auth when its config is present; otherwise the no-op
  // service so the app still boots (CI, missing .env, tests).
  final authService = await _resolveAuthService();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    ProviderScope(
      overrides: [
        // Inject the resolved SharedPreferences instance so anything
        // depending on sharedPreferencesProvider can synchronously read it.
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        // Swap the no-op auth seam for the resolved real/no-op implementation.
        authServiceProvider.overrideWithValue(authService),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
        path: 'assets/translations/strings.csv',
        assetLoader: CsvAssetLoader(),
        fallbackLocale: const Locale('en'),
        child: const App(),
      ),
    ),
  );
}

/// Builds the real Supabase-backed auth service when all required config is
/// present (initializing Supabase first), else falls back to [NoopAuthService]
/// so the app still boots without a backend (keeps `.env` optional).
Future<AuthService> _resolveAuthService() async {
  // Prefer compile-time dart-defines (the channel that works on-device); fall
  // back to a bundled .env via dotenv if one is ever present.
  final url = _config(_supabaseUrl, 'SUPABASE_URL');
  final anonKey = _config(_supabaseAnonKey, 'SUPABASE_ANON_KEY');
  final webClientId = _config(_webClientId, 'WEB_CLIENT_ID');
  final iosClientId = _config(_iosClientId, 'IOS_CLIENT_ID');

  if (url == null ||
      anonKey == null ||
      webClientId == null ||
      iosClientId == null) {
    return NoopAuthService();
  }

  // The project supplies a legacy `anon` key, for which `anonKey` is the correct
  // parameter. Switch to `publishableKey` when migrating to the newer
  // `sb_publishable_…` key format.
  // ignore: deprecated_member_use
  await Supabase.initialize(url: url, anonKey: anonKey);
  return SupabaseGoogleAuthService(
    webClientId: webClientId,
    iosClientId: iosClientId,
  );
}

/// Compile-time dart-define value if set, else the dotenv (`.env`) value, else
/// null. Empty strings (an unset `String.fromEnvironment`) count as absent.
String? _config(String compileTime, String dotenvKey) {
  if (compileTime.isNotEmpty) return compileTime;
  final fromEnv = dotenv.maybeGet(dotenvKey);
  return (fromEnv != null && fromEnv.isNotEmpty) ? fromEnv : null;
}
