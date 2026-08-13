import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// "Join by room code" as a bottom sheet — the entry point from 首頁.
///
/// Pops itself before handing the resolved group back, so the caller pushes
/// onto the page underneath rather than onto a sheet that is going away.
Future<void> showJoinRoomSheet(
  BuildContext context, {
  required void Function(String groupId) onJoined,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => BrutalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'join_title'.tr(),
            style: BrutalText.headlineLgMobile(fontSize: 22),
          ),
          const SizedBox(height: 16),
          JoinRoomForm(
            onJoined: (groupId) {
              Navigator.of(sheetContext).pop();
              onJoined(groupId);
            },
          ),
        ],
      ),
    ),
  );
}

/// The room-code form itself: 6-digit field + join button.
///
/// Shared by [showJoinRoomSheet] and `JoinRoomPage` (the `/join` route, whose
/// path mirrors the invite link `https://ohmybro.app/join/<code>` and is kept
/// as the landing spot for when deep links get wired). One implementation, so
/// the two entry points cannot drift apart.
///
/// Resolution is still local-only: it matches the code against groups on THIS
/// device. Cross-device join needs the server-side `join_group` RPC — see
/// BACKEND_HANDOFF.md §4.
class JoinRoomForm extends ConsumerStatefulWidget {
  const JoinRoomForm({super.key, required this.onJoined});

  final void Function(String groupId) onJoined;

  @override
  ConsumerState<JoinRoomForm> createState() => _JoinRoomFormState();
}

class _JoinRoomFormState extends ConsumerState<JoinRoomForm> {
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
    FocusScope.of(context).unfocus();
    widget.onJoined(match.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: brutalDecoration(
            color: BrutalColors.surface,
            radius: BrutalSpec.cardRadius,
            offset: BrutalSpec.shadowOffsetMobile,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            controller: _codeCtrl,
            autofocus: true,
            cursorColor: BrutalColors.onBackground,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            onSubmitted: (_) => _join(),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: BrutalText.display(fontSize: 40).copyWith(letterSpacing: 10),
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
    );
  }
}
