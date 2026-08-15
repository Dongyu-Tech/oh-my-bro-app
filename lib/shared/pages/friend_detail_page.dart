import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/dialogs/basic_dialog.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';
import 'package:heymybro/shared/widgets/confirm_dialog.dart';
import 'circle_page.dart' show creditColor;
import 'log_share_prompt.dart';

/// A friend's comic credit report — 粗哥's ruling, the score, and the numbers
/// behind it (outstanding debt, times repaid, gatherings joined).
class FriendDetailPage extends ConsumerWidget {
  const FriendDetailPage({super.key, required this.friendId});

  final String friendId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friend = ref
        .watch(friendsProvider)
        .asData
        ?.value
        .firstWhereOrNull((f) => f.id == friendId);
    final credit = ref.watch(friendCreditProvider(friendId));
    final directNet = ref.watch(friendDirectNetProvider(friendId));
    final money = NumberFormat.decimalPattern();

    if (friend == null) {
      return const Scaffold(
        backgroundColor: BrutalColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    const BrutalBackButton(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        friend.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BrutalText.headlineLgMobile(fontSize: 24),
                      ),
                    ),
                    PressableBrutal(
                      onTap: () => _rename(context, ref, friend.name),
                      color: BrutalColors.surface,
                      radius: BrutalSpec.pillRadius,
                      padding: const EdgeInsets.all(9),
                      child: const Icon(LucideIcons.pencil, size: 20),
                    ),
                    const SizedBox(width: 8),
                    PressableBrutal(
                      onTap: () async {
                        if (await confirmDialog(
                          context,
                          title: 'confirm_delete_friend'.tr(),
                          message: 'confirm_delete_friend_msg'.tr(),
                          confirmLabel: 'common_delete'.tr(),
                          danger: true,
                        )) {
                          await ref
                              .read(friendServiceProvider)
                              .deleteFriend(friendId);
                          if (context.mounted) context.pop();
                        }
                      },
                      color: BrutalColors.surface,
                      radius: BrutalSpec.pillRadius,
                      padding: const EdgeInsets.all(9),
                      child: const Icon(LucideIcons.trash2, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // The comic credit-report card.
                    Container(
                      decoration: brutalDecoration(
                        color: BrutalColors.surfaceContainerHigh,
                        radius: BrutalSpec.cardRadius,
                        offset: BrutalSpec.shadowOffsetMobile,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: brutalDecoration(
                              color: BrutalColors.onBackground,
                              radius: BrutalSpec.pillRadius,
                              offset: 0,
                              borderWidth: BrutalSpec.borderWidthThin,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: Text(
                              'friend_report_title'.tr(),
                              style: BrutalText.labelBold(
                                fontSize: 13,
                                color: BrutalColors.primaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${credit.score}',
                            style: BrutalText.display(
                              fontSize: 72,
                              color: creditColor(credit.score),
                            ),
                          ),
                          Text(
                            'credit_score'.tr(),
                            style: BrutalText.labelBold(
                              fontSize: 13,
                              color: BrutalColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '「${credit.verdictKey.tr()}」',
                            textAlign: TextAlign.center,
                            style: BrutalText.headlineLgMobile(
                              fontSize: 24,
                              color: creditColor(credit.score),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (directNet != 0)
                      _NetSettleCard(
                        friendId: friendId,
                        friendName: friend.name,
                        net: directNet,
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            label: 'credit_outstanding'.tr(),
                            value: '\$${money.format(credit.outstanding)}',
                            color: credit.outstanding > 0
                                ? BrutalColors.secondary
                                : BrutalColors.onBackground,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Stat(
                            label: 'credit_repaid_label'.tr(),
                            value: 'credit_repaid'.tr(
                              namedArgs: {'count': '${credit.repaidCount}'},
                            ),
                            color: BrutalColors.onBackground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Stat(
                      label: 'home_active'.tr(),
                      value: 'credit_gatherings'.tr(
                        namedArgs: {'count': '${credit.gatherings}'},
                      ),
                      color: BrutalColors.onBackground,
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

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final input = await showTextInputDialog(
      context,
      title: 'friend_rename'.tr(),
      initialValue: current,
      confirmLabel: 'common_save'.tr(),
    );
    final name = input?.trim() ?? '';
    if (name.isNotEmpty) {
      await ref.read(friendServiceProvider).renameFriend(friendId, name);
    }
  }
}

/// "跟你的總帳" — the netted balance across all direct debts with this friend,
/// plus a one-tap 結清 that clears every one of them at once.
class _NetSettleCard extends ConsumerWidget {
  const _NetSettleCard({
    required this.friendId,
    required this.friendName,
    required this.net,
  });

  final String friendId;
  final String friendName;

  /// Signed net: `< 0` friend owes you, `> 0` you owe friend.
  final int net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.decimalPattern();
    final owesYou = net < 0;
    final amount = net.abs();
    final line = (owesYou ? 'friend_net_owes_you' : 'friend_net_you_owe').tr(
      namedArgs: {'name': friendName},
    );
    final amountColor = owesYou
        ? BrutalColors.secondary
        : BrutalColors.onBackground;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.cardRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'friend_ledger_title'.tr(),
            style: BrutalText.labelBold(
              fontSize: 12,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  line,
                  style: BrutalText.headlineLgMobile(fontSize: 18),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${owesYou ? '+' : '-'}\$${money.format(amount)}',
                style: BrutalText.display(fontSize: 26, color: amountColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PressableBrutal(
            onTap: () => _settleAll(context, ref),
            color: BrutalColors.primaryContainer,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.checkCircle, size: 18),
                const SizedBox(width: 8),
                Text(
                  'friend_settle_all'.tr(),
                  style: BrutalText.labelBold(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _settleAll(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'friend_settle_all_confirm'.tr(namedArgs: {'name': friendName}),
      confirmLabel: 'friend_settle_all'.tr(),
    );
    if (!ok) return;
    final actions = ref.read(friendSettleActionsProvider(friendId));
    // Read the app-wide lists (warm on this page via globalNetProvider) so "my
    // share" is correct even though this page never watches each group's
    // groupSummaryProvider — reading that here would be cold (AsyncLoading).
    final groups = ref.read(groupsProvider).asData?.value ?? const [];
    final members = ref.read(allMembersProvider).asData?.value ?? const [];
    final expenses = ref.read(allExpensesProvider).asData?.value ?? const [];
    final shares = ref.read(allSharesProvider).asData?.value ?? const [];
    final svc = ref.read(groupServiceProvider);
    final toLog = <({String title, int amount, String settlementId})>[];
    for (final a in actions) {
      final settlementId = await svc.settle(
        groupId: a.groupId,
        fromMemberId: a.fromMemberId,
        toMemberId: a.toMemberId,
        amount: a.amount,
      );
      toLog.add((
        title: groups.firstWhereOrNull((g) => g.id == a.groupId)?.name ?? '',
        amount: myShareOfGroup(
          groupId: a.groupId,
          members: members,
          expenses: expenses,
          shares: shares,
        ),
        settlementId: settlementId,
      ));
    }
    showMessage('friend_settle_all_done'.tr());
    if (context.mounted) await promptLogMyShare(context, ref, toLog);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.cardRadius,
        offset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: BrutalText.labelBold(
              fontSize: 12,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: BrutalText.headlineLgMobile(fontSize: 22, color: color),
          ),
        ],
      ),
    );
  }
}
