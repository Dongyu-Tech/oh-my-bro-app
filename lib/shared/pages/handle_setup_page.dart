import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/provider/auth_provider.dart';
import 'package:heymybro/shared/provider/user_provider.dart';
import 'package:heymybro/shared/repositories/user_repository.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Mirrors the `users_handle_format` check on `public.users`. Kept in sync by
/// hand — the server is the authority, this only spares the user a round trip.
const int kHandleMinLength = 3;
const int kHandleMaxLength = 20;

enum HandleProblem { empty, tooShort, tooLong, badChars }

/// Client-side pre-flight for a handle. Null means "looks fine" — it does NOT
/// mean available; only the server's unique index can answer that.
HandleProblem? validateHandle(String raw) {
  final handle = raw.trim();
  if (handle.isEmpty) return HandleProblem.empty;
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(handle)) {
    // Checked before length so "王小明" reports the real problem rather than
    // telling someone to add more characters.
    return HandleProblem.badChars;
  }
  if (handle.length < kHandleMinLength) return HandleProblem.tooShort;
  if (handle.length > kHandleMaxLength) return HandleProblem.tooLong;
  return null;
}

extension HandleProblemMessage on HandleProblem {
  String get messageKey => switch (this) {
    HandleProblem.empty => 'handle_error_empty',
    HandleProblem.tooShort => 'handle_error_short',
    HandleProblem.tooLong => 'handle_error_long',
    HandleProblem.badChars => 'handle_error_chars',
  };
}

/// One-time gate after sign-in: pick the handle other people will use to find
/// you. The router pins signed-in users here until [AppUserModel.handle] is set,
/// so there is no back button — only a sign-out escape hatch.
class HandleSetupPage extends ConsumerStatefulWidget {
  const HandleSetupPage({super.key});

  @override
  ConsumerState<HandleSetupPage> createState() => _HandleSetupPageState();
}

class _HandleSetupPageState extends ConsumerState<HandleSetupPage> {
  final _ctrl = TextEditingController();
  HandleProblem? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = validateHandle(_ctrl.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }

    final profile = ref.read(myProfileProvider).asData?.value;
    if (profile == null) {
      showErrorSnakeBar('handle_no_profile'.tr());
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    final result = await ref
        .read(userRepositoryProvider)
        .saveMe(profile.copyWith(handle: _ctrl.text.trim()));

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Ok():
        // Flipping needsHandleProvider is what releases the router gate.
        ref.invalidate(myProfileProvider);
      case Error(error: HandleTakenException()):
        showErrorSnakeBar('handle_taken'.tr());
      case Error(error: HandleInvalidException()):
        showErrorSnakeBar('handle_error_chars'.tr());
      case Error(error: final e):
        showErrorSnakeBar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              SizedBox(
                height: 120,
                child: Center(
                  child: Image.asset(
                    'assets/mascot/stickers/01_main-pointing.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: MarkerHighlight(
                  child: Text(
                    'handle_setup_title'.tr(),
                    style: BrutalText.headlineLgMobile(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'handle_setup_hint'.tr(),
                style: BrutalText.body(
                  fontSize: 14,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: brutalDecoration(
                  color: BrutalColors.surface,
                  radius: BrutalSpec.pillRadius,
                  offset: 3,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('@', style: BrutalText.headlineLgMobile(fontSize: 22)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        cursorColor: BrutalColors.onBackground,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: kHandleMaxLength,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        onChanged: (_) {
                          if (_problem != null) setState(() => _problem = null);
                        },
                        // Block the characters the server would reject anyway,
                        // so the field can't be typed into an invalid state.
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_]'),
                          ),
                        ],
                        style: BrutalText.body(fontSize: 18),
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          border: InputBorder.none,
                          hintText: 'handle_placeholder'.tr(),
                          hintStyle: BrutalText.body(
                            fontSize: 18,
                            color: BrutalColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(
                  _problem!.messageKey.tr(
                    namedArgs: {
                      'min': '$kHandleMinLength',
                      'max': '$kHandleMaxLength',
                    },
                  ),
                  style: BrutalText.labelBold(
                    fontSize: 13,
                    color: BrutalColors.secondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PressableBrutal(
                onTap: _saving ? null : _submit,
                color: _saving
                    ? BrutalColors.surfaceContainerHigh
                    : BrutalColors.primaryContainer,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  (_saving ? 'handle_saving' : 'handle_confirm').tr(),
                  style: BrutalText.labelBold(fontSize: 17),
                ),
              ),
              const SizedBox(height: 18),
              // Without this the screen is a dead end for anyone who signed in
              // with the wrong account.
              Center(
                child: GestureDetector(
                  onTap: () => ref.read(authServiceProvider).signOut(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'account_logout'.tr(),
                      style: BrutalText.labelBold(
                        fontSize: 14,
                        color: BrutalColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
