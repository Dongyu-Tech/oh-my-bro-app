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

/// Invite-first landing for a gathering: the big room code + QR to share, the
/// list of who's in, and a way into recording/splitting. This is the "揪人"
/// stage — you broadcast an invite, people join by code, then you split.
///
/// Local demo: sharing and cross-device join are stubs (see the note banner);
/// a real build wires these through the backend.
class RoomPage extends ConsumerWidget {
  const RoomPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref
        .watch(groupsProvider)
        .asData
        ?.value
        .firstWhereOrNull((g) => g.id == groupId);
    final members =
        ref.watch(groupMembersProvider(groupId)).asData?.value ?? const [];

    if (group == null) {
      return const Scaffold(
        backgroundColor: BrutalColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final code = roomCodeFor(groupId);

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                child: Row(
                  children: [
                    const BrutalBackButton(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BrutalText.headlineLgMobile(fontSize: 24),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // The room code — the star of the invite stage.
                    Container(
                      decoration: brutalDecoration(
                        color: Color(group.colorValue),
                        radius: BrutalSpec.cardRadius,
                        offset: BrutalSpec.shadowOffsetMobile,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'room_code_label'.tr(),
                            style: BrutalText.labelBold(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: code));
                              showMessage('invite_copied'.tr());
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              code,
                              style: BrutalText.display(
                                fontSize: 52,
                              ).copyWith(letterSpacing: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: brutalDecoration(
                          color: BrutalColors.surface,
                          radius: BrutalSpec.cardRadius,
                          offset: 4,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.qrCode, size: 92),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'invite_scan'.tr(),
                        style: BrutalText.labelBold(
                          fontSize: 13,
                          color: BrutalColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PressableBrutal(
                      onTap: comingSoon,
                      color: BrutalColors.primaryContainer,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.share2, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'room_share'.tr(),
                            style: BrutalText.labelBold(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DemoNote(),
                    const SizedBox(height: 22),
                    Text(
                      'room_participants'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in members)
                          BrutalPill(
                            color: m.isMe
                                ? BrutalColors.primaryContainer
                                : BrutalColors.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            child: Text(
                              m.isMe ? 'group_me'.tr() : m.name,
                              style: BrutalText.labelBold(fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: PressableBrutal(
                  onTap: () => context.push('/group/$groupId'),
                  color: BrutalColors.primaryContainer,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.receipt, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'room_start'.tr(),
                        style: BrutalText.labelBold(fontSize: 17),
                      ),
                    ],
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

class _DemoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surfaceContainerHigh,
        radius: BrutalSpec.pillRadius,
        offset: 0,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(
            LucideIcons.info,
            size: 16,
            color: BrutalColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'room_demo_note'.tr(),
              style: BrutalText.labelBold(
                fontSize: 12,
                color: BrutalColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
