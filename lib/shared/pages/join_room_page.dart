import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// "Enter a room code to join." Local demo: matches the code against groups on
/// THIS device (so a code you created here resolves); a real cross-device join
/// needs the backend, which the not-found message calls out.
class JoinRoomPage extends ConsumerStatefulWidget {
  const JoinRoomPage({super.key});

  @override
  ConsumerState<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends ConsumerState<JoinRoomPage> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _join() {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      showErrorSnakeBar('join_hint'.tr());
      return;
    }
    final groups = ref.read(groupsProvider).asData?.value ?? const [];
    final match = groups.where((g) => roomCodeFor(g.id) == code).firstOrNull;
    if (match == null) {
      showErrorSnakeBar('join_not_found'.tr());
      return;
    }
    context.pushReplacement('/group/${match.id}/room');
  }

  @override
  Widget build(BuildContext context) {
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
                      'join_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
                    Container(
                      decoration: brutalDecoration(
                        color: BrutalColors.surface,
                        radius: BrutalSpec.cardRadius,
                        offset: BrutalSpec.shadowOffsetMobile,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: _codeCtrl,
                        cursorColor: BrutalColors.onBackground,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: BrutalText.display(
                          fontSize: 40,
                        ).copyWith(letterSpacing: 10),
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: '••••••',
                          hintStyle: BrutalText.display(
                            fontSize: 40,
                            color: BrutalColors.outline,
                          ).copyWith(letterSpacing: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'join_hint'.tr(),
                        style: BrutalText.labelBold(
                          fontSize: 13,
                          color: BrutalColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PressableBrutal(
                      onTap: _join,
                      color: BrutalColors.primaryContainer,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.logIn, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'join_button'.tr(),
                            style: BrutalText.labelBold(fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
