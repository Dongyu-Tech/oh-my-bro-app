import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/services/auth_service.dart';
import 'core/services/dev_auth_service.dart';
import 'core/services/supabase_google_auth_service.dart';
import 'shared/provider/auth_provider.dart';
import 'shared/provider/debt_provider.dart';
import 'shared/provider/friendship_provider.dart';
import 'shared/provider/settings_provider.dart';
import 'shared/provider/user_provider.dart';
import 'shared/repositories/debt_repository.dart';
import 'shared/repositories/friendship_repository.dart';
import 'shared/repositories/user_repository.dart';

// Compile-time config, injected at build time via --dart-define. This is the
// only config channel that survives onto a device: a mobile app cannot read
// your host machine's .env at runtime.
//
// In dev, source it from 1Password at BUILD time via the wrapper:
//   tool/dev.sh run
// Do NOT use --dart-define-from-file=.env — 1Password exposes `.env` as a named
// pipe, and that flag gates on File.existsSync(), which is false for a FIFO.
const _secretKey = String.fromEnvironment('SECRET_KEY');
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
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
      if (_supabasePublishableKey.isNotEmpty)
        'SUPABASE_PUBLISHABLE_KEY': _supabasePublishableKey,
      if (_webClientId.isNotEmpty) 'WEB_CLIENT_ID': _webClientId,
      if (_iosClientId.isNotEmpty) 'IOS_CLIENT_ID': _iosClientId,
    },
  );

  // Real Google + Supabase auth when its config is present; otherwise the no-op
  // service so the app still boots (CI, missing .env, tests).
  final backend = await _resolveBackend();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    ProviderScope(
      overrides: [
        // Inject the resolved SharedPreferences instance so anything
        // depending on sharedPreferencesProvider can synchronously read it.
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        // Swap the no-op auth seam for the resolved real/no-op implementation.
        authServiceProvider.overrideWithValue(backend.auth),
        // Only reachable once Supabase.initialize has run; otherwise the
        // unavailable seam keeps profile reads failing cleanly.
        if (backend.supabaseReady) ...[
          userRepositoryProvider.overrideWithValue(SupabaseUserRepository()),
          friendshipRepositoryProvider.overrideWithValue(
            SupabaseFriendshipRepository(),
          ),
          debtRepositoryProvider.overrideWithValue(SupabaseDebtRepository()),
        ],
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
///
/// [_Backend.supabaseReady] reports whether `Supabase.initialize` actually ran,
/// which is what any other Supabase-backed provider must gate on — touching
/// `Supabase.instance` before that throws.
Future<_Backend> _resolveBackend() async {
  // Prefer compile-time dart-defines (the channel that works on-device); fall
  // back to a bundled .env via dotenv if one is ever present.
  final url = _config(_supabaseUrl, 'SUPABASE_URL');
  final publishableKey = _config(
    _supabasePublishableKey,
    'SUPABASE_PUBLISHABLE_KEY',
  );
  final webClientId = _config(_webClientId, 'WEB_CLIENT_ID');
  final iosClientId = _config(_iosClientId, 'IOS_CLIENT_ID');

  if (url == null ||
      publishableKey == null ||
      webClientId == null ||
      iosClientId == null) {
    // No real auth config. In debug builds use a dev bypass so the app is
    // reachable for local UI work (tap "Sign in with Google" → fake user →
    // into the app); release builds stay signed-out via the no-op service.
    return _Backend(
      auth: kDebugMode ? DevAuthService() : NoopAuthService(),
      supabaseReady: false,
    );
  }

  // `sb_publishable_…` key. Publishable keys can be rotated and revoked
  // independently of the secret key; the legacy `anon` JWT could not, and is
  // being removed by Supabase. The key is public by design — RLS is the real
  // boundary.
  await Supabase.initialize(url: url, publishableKey: publishableKey);
  return _Backend(
    auth: SupabaseGoogleAuthService(
      webClientId: webClientId,
      iosClientId: iosClientId,
    ),
    supabaseReady: true,
  );
}

/// What boot resolved: the auth implementation, plus whether Supabase itself
/// came up (so other backed providers know if they can be wired).
class _Backend {
  const _Backend({required this.auth, required this.supabaseReady});

  final AuthService auth;
  final bool supabaseReady;
}

/// Compile-time dart-define value if set, else the dotenv (`.env`) value, else
/// null. Empty strings (an unset `String.fromEnvironment`) count as absent.
String? _config(String compileTime, String dotenvKey) {
  if (compileTime.isNotEmpty) return compileTime;
  final fromEnv = dotenv.maybeGet(dotenvKey);
  return (fromEnv != null && fromEnv.isNotEmpty) ? fromEnv : null;
}
