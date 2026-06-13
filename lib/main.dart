import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'shared/provider/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  // SECRET_KEY may come from .env (dev) or --dart-define=SECRET_KEY=... (CI).
  const secretKey = String.fromEnvironment('SECRET_KEY');
  await dotenv.load(
    fileName: '.env',
    isOptional: true,
    mergeWith: secretKey.isEmpty ? const {} : {'SECRET_KEY': secretKey},
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    ProviderScope(
      overrides: [
        // Inject the resolved SharedPreferences instance so anything
        // depending on sharedPreferencesProvider can synchronously read it.
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
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
