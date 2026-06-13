import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'core/routing/router.dart';
import 'shared/models/app_settings_model.dart';
import 'shared/provider/settings_provider.dart';
import 'shared/widgets/app_keyboard_focus_guard.dart';
import 'shared/widgets/brutalism.dart';

class App extends ConsumerWidget {
  const App({super.key});

  // Global key so any async-aware helper (showErrorSnakeBar etc.) can show
  // a snackbar without needing a BuildContext.
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final themeColor = ref.watch(settingsProvider.select((s) => s.themeColor));
    final locale = ref.watch(settingsProvider.select((s) => s.language.locale));

    return MaterialApp.router(
      title: Constants.appName,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      locale: locale,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
        brightness: Brightness.light,
        scaffoldBackgroundColor: BrutalColors.cream,
        canvasColor: BrutalColors.cream,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeColor,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          AppKeyboardFocusGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}
