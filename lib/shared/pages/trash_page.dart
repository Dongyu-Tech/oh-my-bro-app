import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';
import 'package:heymybro/shared/widgets/confirm_dialog.dart';

/// Opens the 回收桶 as a floating panel over the current page, with the page
/// blurred behind it. Deleted items appear as full-width banners, each
/// restorable or purgeable forever.
Future<void> showTrashModal(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'trash',
    barrierColor: BrutalColors.onBackground.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const _TrashPanel(),
    transitionBuilder: (ctx, anim, sec, child) {
      final t = Curves.easeOut.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7 * t, sigmaY: 7 * t),
        child: FadeTransition(
          opacity: anim,
          child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
        ),
      );
    },
  );
}

/// A labelled "回收桶" button — drop it in a page's title row to open the bin.
class TrashButton extends StatelessWidget {
  const TrashButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      onTap: onTap,
      color: BrutalColors.surface,
      radius: BrutalSpec.pillRadius,
      padding: const EdgeInsets.fromLTRB(11, 8, 13, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.trash2,
            size: 19,
            color: BrutalColors.onBackground,
          ),
          const SizedBox(width: 5),
          Text('trash_open'.tr(), style: BrutalText.labelBold(fontSize: 13)),
        ],
      ),
    );
  }
}

class _TrashPanel extends ConsumerWidget {
  const _TrashPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupSvc = ref.read(groupServiceProvider);
    final friendSvc = ref.read(friendServiceProvider);
    final money = NumberFormat.decimalPattern();

    final groups = ref.watch(trashedGroupsProvider).asData?.value ?? const [];
    final expenses =
        ref.watch(trashedExpensesProvider).asData?.value ?? const [];
    final personal =
        ref.watch(trashedPersonalEntriesProvider).asData?.value ?? const [];
    final friends = ref.watch(trashedFriendsProvider).asData?.value ?? const [];

    // Grouped by kind so it's clear what each deleted item is, instead of one
    // flat pile distinguished only by icon colour.
    final sections = <({String labelKey, List<Widget> banners})>[
      (
        labelKey: 'trash_section_groups',
        banners: [
          for (final g in groups)
            _TrashBanner(
              color: Color(g.colorValue),
              icon: LucideIcons.users,
              title: g.name,
              onRestore: () => groupSvc.restoreGroup(g.id),
              onPurge: () => _purge(context, () => groupSvc.purgeGroup(g.id)),
            ),
        ],
      ),
      (
        labelKey: 'trash_section_expenses',
        banners: [
          for (final e in expenses)
            _TrashBanner(
              color: BrutalColors.secondary,
              icon: LucideIcons.receipt,
              title: e.title,
              trailing: '\$${money.format(e.amount)}',
              onRestore: () => groupSvc.restoreExpense(e.id),
              onPurge: () => _purge(context, () => groupSvc.purgeExpense(e.id)),
            ),
        ],
      ),
      (
        labelKey: 'trash_section_personal',
        banners: [
          for (final p in personal)
            _TrashBanner(
              color: BrutalColors.primaryFixedDim,
              icon: LucideIcons.pencil,
              title: p.title,
              trailing: '\$${money.format(p.amount)}',
              onRestore: () => groupSvc.restorePersonalEntry(p.id),
              onPurge: () =>
                  _purge(context, () => groupSvc.purgePersonalEntry(p.id)),
            ),
        ],
      ),
      (
        labelKey: 'trash_section_friends',
        banners: [
          for (final f in friends)
            _TrashBanner(
              color: BrutalColors.purple,
              icon: LucideIcons.user,
              title: f.name,
              onRestore: () => friendSvc.restoreFriend(f.id),
              onPurge: () => _purge(context, () => friendSvc.purgeFriend(f.id)),
            ),
        ],
      ),
    ];
    final isEmpty = sections.every((s) => s.banners.isEmpty);

    return SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 48),
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: brutalDecoration(
            color: BrutalColors.background,
            radius: BrutalSpec.cardRadius,
            offset: BrutalSpec.shadowOffset,
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.trash2, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'trash_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 22),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(LucideIcons.x, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'trash_empty'.tr(),
                    textAlign: TextAlign.center,
                    style: BrutalText.labelBold(
                      fontSize: 15,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in sections)
                        if (s.banners.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 2),
                            child: Text(
                              '${s.labelKey.tr()} · ${s.banners.length}',
                              style: BrutalText.labelBold(
                                fontSize: 12,
                                color: BrutalColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          for (final b in s.banners)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: b,
                            ),
                          const SizedBox(height: 6),
                        ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _purgeAll(context, ref),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'trash_purge_all'.tr(),
                      textAlign: TextAlign.center,
                      style: BrutalText.labelBold(
                        fontSize: 14,
                        color: BrutalColors.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purge(BuildContext context, Future<void> Function() run) async {
    if (await confirmDialog(
      context,
      title: 'trash_confirm_purge'.tr(),
      confirmLabel: 'trash_purge'.tr(),
      danger: true,
    )) {
      await run();
    }
  }

  /// Permanently delete every item in the bin, after one confirmation.
  Future<void> _purgeAll(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'trash_purge_all_confirm'.tr(),
      confirmLabel: 'trash_purge'.tr(),
      danger: true,
    );
    if (!ok) return;
    final groupSvc = ref.read(groupServiceProvider);
    final friendSvc = ref.read(friendServiceProvider);
    for (final g in ref.read(trashedGroupsProvider).asData?.value ?? const []) {
      await groupSvc.purgeGroup(g.id);
    }
    for (final e
        in ref.read(trashedExpensesProvider).asData?.value ?? const []) {
      await groupSvc.purgeExpense(e.id);
    }
    for (final p
        in ref.read(trashedPersonalEntriesProvider).asData?.value ?? const []) {
      await groupSvc.purgePersonalEntry(p.id);
    }
    for (final f
        in ref.read(trashedFriendsProvider).asData?.value ?? const []) {
      await friendSvc.purgeFriend(f.id);
    }
  }
}

/// A deleted item as a full-width banner: a coloured end-cap, a struck-through
/// title, then restore / delete-forever controls.
class _TrashBanner extends StatelessWidget {
  const _TrashBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.onRestore,
    required this.onPurge,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 3,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Coloured end-cap with the item's icon.
          Container(
            width: 52,
            height: double.infinity,
            color: color,
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: BrutalColors.onBackground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.labelBold(fontSize: 15).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: BrutalColors.secondary,
                    decorationThickness: 2,
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: BrutalText.labelBold(
                      fontSize: 12,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRestore,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(9),
              child: Icon(
                LucideIcons.rotateCcw,
                size: 20,
                color: BrutalColors.success,
              ),
            ),
          ),
          GestureDetector(
            onTap: onPurge,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(6, 9, 12, 9),
              child: Icon(
                LucideIcons.trash2,
                size: 20,
                color: BrutalColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
