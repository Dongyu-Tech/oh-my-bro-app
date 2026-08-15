import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The full list of gatherings (active + archived), pushed from the home
/// "view all" link. Home shows only the active ones.
class GatheringsListPage extends ConsumerWidget {
  const GatheringsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(gatheringsProvider);
    final active = groups.where((g) => !g.isArchived).toList();
    final archived = groups.where((g) => g.isArchived).toList();

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
                      'group_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: (active.isEmpty && archived.isEmpty)
                    ? Center(
                        child: Text(
                          'home_empty'.tr(),
                          style: BrutalText.labelBold(
                            fontSize: 14,
                            color: BrutalColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          for (final g in active)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: _GatheringCard(group: g),
                            ),
                          if (archived.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'group_section_archived'.tr(),
                              style: BrutalText.labelBold(
                                fontSize: 14,
                                color: BrutalColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final g in archived)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 11),
                                child: Opacity(
                                  opacity: 0.6,
                                  child: _GatheringCard(group: g),
                                ),
                              ),
                          ],
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

class _GatheringCard extends ConsumerWidget {
  const _GatheringCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(groupMembersProvider(group.id)).asData?.value ?? const [];
    final myNet =
        ref.watch(groupSummaryProvider(group.id)).asData?.value.myNet ?? 0;
    final money = NumberFormat.decimalPattern();

    final (String label, Color color, String text) = switch (myNet) {
      > 0 => (
        'group_you_get_back'.tr(),
        BrutalColors.secondary,
        '+\$${money.format(myNet)}',
      ),
      < 0 => (
        'group_you_owe'.tr(),
        BrutalColors.onBackground,
        '-\$${money.format(-myNet)}',
      ),
      _ => ('group_settled'.tr(), BrutalColors.onSurfaceVariant, ''),
    };

    return GestureDetector(
      onTap: () => context.push('/group/${group.id}'),
      behavior: HitTestBehavior.opaque,
      child: BrutalCard(
        color: BrutalColors.surface,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: brutalDecoration(
                color: Color(group.colorValue),
                radius: BrutalSpec.pillRadius,
                offset: 0,
                borderWidth: BrutalSpec.borderWidthThin,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrutalText.headlineLgMobile(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'group_members_count'.tr(
                      namedArgs: {'count': '${members.length}'},
                    ),
                    style: BrutalText.labelBold(
                      fontSize: 12,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: BrutalText.labelBold(
                    fontSize: 11,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: BrutalText.headlineLgMobile(
                      fontSize: 18,
                      color: color,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
