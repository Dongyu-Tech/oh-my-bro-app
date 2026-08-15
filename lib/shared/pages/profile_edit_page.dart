import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/models/app_user_model.dart';
import 'package:heymybro/shared/pages/handle_setup_page.dart'
    show validateHandle, kHandleMaxLength, HandleProblemMessage;
import 'package:heymybro/shared/provider/user_provider.dart';
import 'package:heymybro/shared/repositories/user_repository.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Oldest birthday the picker offers. A hard floor beats a plausible-looking
/// but wrong "120 years ago" computed at build time.
final _kEarliestBirthday = DateTime(1900);

/// Edit your own `public.users` row. Reached from the account page's avatar.
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _nameCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  Gender? _gender;
  DateTime? _birthday;
  bool _saving = false;

  /// Filled once from the loaded profile; without this the controllers would be
  /// reset on every rebuild and eat the user's typing.
  bool _seeded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _handleCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _seed(AppUserModel profile) {
    if (_seeded) return;
    _seeded = true;
    _nameCtrl.text = profile.displayName ?? '';
    _handleCtrl.text = profile.handle ?? '';
    _bioCtrl.text = profile.bio ?? '';
    _gender = profile.gender;
    _birthday = profile.birthday;
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: _kEarliestBirthday,
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _birthday = picked);
  }

  Future<void> _save(AppUserModel profile) async {
    final problem = validateHandle(_handleCtrl.text);
    if (problem != null) {
      showErrorSnakeBar(
        problem.messageKey.tr(
          namedArgs: {'min': '3', 'max': '$kHandleMaxLength'},
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await ref
        .read(userRepositoryProvider)
        .saveMe(
          profile.copyWith(
            handle: _handleCtrl.text.trim(),
            displayName: _nameCtrl.text.trim(),
            gender: _gender,
            birthday: _birthday,
            bio: _bioCtrl.text.trim(),
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Ok():
        ref.invalidate(myProfileProvider);
        showMessage('profile_saved'.tr());
        if (mounted) context.pop();
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
    final async = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                child: Row(
                  children: [
                    const BrutalBackButton(),
                    const SizedBox(width: 12),
                    Text(
                      'profile_edit_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (async) {
                  AsyncData(value: final profile) when profile != null => _form(
                    profile,
                  ),
                  AsyncData() => _message('profile_unavailable'.tr()),
                  AsyncError(error: final e) => _message(e.toString()),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: BrutalText.labelBold(
          fontSize: 15,
          color: BrutalColors.onSurfaceVariant,
        ),
      ),
    ),
  );

  Widget _form(AppUserModel profile) {
    _seed(profile);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        _Label('profile_field_name'.tr()),
        _Field(controller: _nameCtrl, hint: 'profile_field_name_hint'.tr()),
        const SizedBox(height: 18),

        _Label('profile_field_handle'.tr()),
        _Field(
          controller: _handleCtrl,
          hint: 'handle_placeholder'.tr(),
          prefix: '@',
          maxLength: kHandleMaxLength,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
          ],
        ),
        const SizedBox(height: 18),

        _Label('profile_field_gender'.tr()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in Gender.values)
              PressableBrutal(
                onTap: () => setState(() => _gender = _gender == g ? null : g),
                color: _gender == g
                    ? BrutalColors.primaryContainer
                    : BrutalColors.surface,
                restOffset: _gender == g ? 3 : 2,
                pressedOffset: 1,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  'gender_${g.wire}'.tr(),
                  style: BrutalText.labelBold(fontSize: 14),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),

        _Label('profile_field_birthday'.tr()),
        PressableBrutal(
          onTap: _pickBirthday,
          color: BrutalColors.surface,
          restOffset: 3,
          pressedOffset: 1,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            _birthday == null
                ? 'profile_field_birthday_hint'.tr()
                : DateFormat('yyyy / MM / dd').format(_birthday!),
            style: BrutalText.body(
              fontSize: 16,
              color: _birthday == null
                  ? BrutalColors.onSurfaceVariant
                  : BrutalColors.onBackground,
            ),
          ),
        ),
        const SizedBox(height: 18),

        _Label('profile_field_bio'.tr()),
        _Field(
          controller: _bioCtrl,
          hint: 'profile_field_bio_hint'.tr(),
          maxLength: 200,
          maxLines: 3,
        ),
        const SizedBox(height: 26),

        PressableBrutal(
          onTap: _saving ? null : () => _save(profile),
          color: _saving
              ? BrutalColors.surfaceContainerHigh
              : BrutalColors.primaryContainer,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            (_saving ? 'handle_saving' : 'common_save').tr(),
            style: BrutalText.labelBold(fontSize: 17),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: BrutalText.labelBold(fontSize: 14)),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.prefix,
    this.maxLength,
    this.maxLines = 1,
    this.formatters,
  });

  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                prefix!,
                style: BrutalText.headlineLgMobile(fontSize: 18),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: BrutalColors.onBackground,
              maxLength: maxLength,
              maxLines: maxLines,
              inputFormatters: formatters,
              style: BrutalText.body(fontSize: 16),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: BrutalText.body(
                  fontSize: 16,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
