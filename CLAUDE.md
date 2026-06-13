# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Oh My Bro" — a Flutter expense-ledger / shared-spending app. Dart package name is
`heymybro` (so all internal imports are `package:heymybro/...`), app id is
`com.dongyutech.heymybro`, display name is "Oh My Bro". UI is a "Rough Comic
Neo-Brutalism" design (see `DESIGN.md` and `lib/shared/widgets/brutalism.dart`).

**This repo is an early scaffold.** Many files are deliberate _seams_ — abstract
services, a throwing DI placeholder, an empty Drift database, and commented-out
example code showing the intended pattern (see `lib/core/database/database.dart`,
`lib/core/services/auth_service.dart`, `lib/core/routing/router.dart`). When adding
a feature, fill in these seams following the inline example comments rather than
inventing a new structure. The visible ledger/nav screens are mostly hardcoded
sample data, not yet DB-backed.

## Commands

```bash
flutter pub get                                            # install deps
dart run build_runner build --delete-conflicting-outputs   # codegen (REQUIRED, see below)
dart run build_runner watch  --delete-conflicting-outputs  # codegen in watch mode
flutter analyze                                            # lint/static analysis
flutter test                                              # all tests
flutter test test/simple_test.dart                        # a single test file
flutter run                                               # run on device/emulator
flutter build apk --debug                                 # what CI builds
```

Release/CI builds inject the secret as `--dart-define=SECRET_KEY=...` instead of a
`.env` file (see "Configuration & secrets" below).

CI (`.github/workflows/flutter-ci.yml`) runs, in order: `pub get` → `build_runner
build` → `flutter analyze --no-fatal-warnings --no-fatal-infos` → `flutter test` →
`flutter build apk --debug`. Match this locally before pushing.

## Codegen is mandatory

Drift, freezed, and json_serializable all generate `*.g.dart` / `*.freezed.dart`
files. **These generated files ARE committed** (see the note at the bottom of
`.gitignore`). After editing any `@freezed` model, Drift table, or
`@DriftDatabase`, re-run `build_runner` or `analyze`/`test` will fail on stale or
missing generated code. Edit the source `.dart` file, never the generated output.

## Architecture

```
lib/
  main.dart            # boot: EasyLocalization + SharedPreferences + dotenv, then ProviderScope
  app.dart             # MaterialApp.router; theme driven by settingsProvider; global scaffoldMessengerKey
  constants.dart       # compile-time constants only (no runtime config)
  core/
    database/          # Drift AppDatabase (currently table-less scaffold)
    routing/           # single go_router instance
    error/             # Result<T> sealed type + snackbar helpers
    services/          # auth / backup / in-app-update — abstract or no-op seams
  shared/
    provider/          # Riverpod providers (the app's wiring layer)
    repositories/      # persistence wrappers (e.g. SharedPreferences)
    models/            # freezed immutable models
    pages/             # screens (AppShell hosts the 4-tab IndexedStack)
    widgets/           # brutalism.dart design system
```

### State & dependency injection (Riverpod)

The DI strategy is the most important pattern to understand:

- **Throwing placeholder + override.** `sharedPreferencesProvider` throws
  `UnimplementedError` by default; `main.dart` resolves the async singleton and
  injects it via `ProviderScope(overrides: [...])`. Use this same pattern for any
  async-loaded singleton (DB, authenticated Dio, etc).
- **No-op default + override.** `authServiceProvider` returns `NoopAuthService`
  (always signed out) so the app compiles and boots without a backend. Wire a real
  implementation by extending the abstract `AuthService` and overriding the provider
  in `main.dart`.
- Providers compose: `settingsProvider` (a `Notifier`) → `appSettingsRepositoryProvider`
  → `sharedPreferencesProvider`. UI reads slices with `.select(...)` to limit rebuilds.
- **Drift → UI:** expose Drift `.watch()` queries as a `StreamProvider`; derive
  totals/filters/groupings by re-mapping that stream with `whenData`, not by
  re-querying Drift in a second provider (see comments in `database_provider.dart`).

### Error handling

Domain code (services, repositories) returns `Result<T>` — a sealed
`Ok<T> | Error<T>` (`lib/core/error/result.dart`). Call sites `switch` on it instead
of try/catch. For user-facing messages, `lib/core/error/error_logger.dart` provides
`showErrorSnakeBar`, `showMessage`, and `comingSoon()` that use `App.scaffoldMessengerKey`
— so they work across async gaps without a `BuildContext`.

### Database / backup coupling

`AppDatabase.schemaVersion` and `BackupService.supportedSchemaVersions` are coupled:
bumping the Drift schema requires adding an `onUpgrade` clause **and** updating
`BackupService.supportedSchemaVersions` (and a `_migrate` transform for old backups)
in the same commit, or older JSON backups silently fail to restore.

### freezed model conventions

- Use a `JsonConverter` for non-trivial field types (see `ColorIntConverter` in
  `app_settings_model.dart`).
- When a freezed constructor parameter uses `@JsonKey`, add
  `// ignore_for_file: invalid_annotation_target` at the top of the model file.

## Localization

Strings live in a CSV, **not** ARB/JSON: `assets/translations/strings.csv` with
columns `key,en,zh_TW`, loaded via `easy_localization` + `CsvAssetLoader`. Supported
locales are `en` and `zh` (`TW`); fallback is `en`. Add a new row to the CSV and read
it with `'my_key'.tr()`. Do not hardcode user-facing strings.

## Design system

All visual styling goes through `lib/shared/widgets/brutalism.dart`: `BrutalColors`,
`BrutalSpec` (border widths, hard-shadow offsets, radii), `BrutalText` (Google Fonts
roles), `brutalDecoration()`, and components `BrutalCard` / `BrutalPill` /
`PressableBrutal`. These mirror the HTML reference in `assets/page_reference/ledger.html`
and the tokens in `DESIGN.md`. Build new screens from these primitives rather than raw
`Container`/`BoxDecoration`, and update tokens in this one file when the design changes.

## Configuration & secrets

`SECRET_KEY` is read from `.env` in development (via `flutter_dotenv`, gitignored) or
from `--dart-define=SECRET_KEY=...` in CI/release; `main.dart` merges whichever is
present. `.env` is optional — the app boots fine without it (CI just `touch`es an empty
one). Compile-time constants belong in `constants.dart`; never put runtime config there.

## Dependency stack is locked

`pubspec.yaml` marks the core stack "do not substitute": **flutter_riverpod**,
**drift** (+ `drift_flutter`, `sqlite3_flutter_libs`), **freezed**, **json_serializable**,
**go_router**, **easy_localization**, **dio**, **shared_preferences**, **flutter_dotenv**.
Prefer these over alternatives. The commented dependency block in `pubspec.yaml` lists
the pre-approved packages (auth, file picker, share sheet, etc.) to uncomment as needed.
