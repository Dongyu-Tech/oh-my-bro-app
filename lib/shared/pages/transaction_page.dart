import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:heymybro/shared/pages/debt_pending_section.dart';
import 'package:heymybro/shared/pages/group_detail_page.dart';
import 'package:heymybro/shared/pages/trash_page.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// 帳本 tab — money BETWEEN you and other people: "who owes who", derived from
/// every gathering's settle-up plan, plus the debts still awaiting
/// confirmation.
///
/// Beware the file names here: this is 帳本, while `LedgerPage` is the 個人
/// tab (your own spending). They read the other way round.
class TransactionPage extends ConsumerWidget {
  const TransactionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.decimalPattern();
    final debts = ref.watch(myDebtsProvider);
    final owedToMe = debts
        .where((d) => d.owedToMe)
        .fold(0, (s, d) => s + d.amount);
    final iOwe = debts
        .where((d) => !d.owedToMe)
        .fold(0, (s, d) => s + d.amount);

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        bottom: false,
        child: DottedBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  MarkerHighlight(
                    child: Text(
                      'transaction_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 30),
                    ),
                  ),
                  const Spacer(),
                  TrashButton(onTap: () => showTrashModal(context)),
                ],
              ),
              const SizedBox(height: 24),
              _DebtSummaryCard(money: money, owedToMe: owedToMe, iOwe: iOwe),
              const SizedBox(height: 20),
              // Above 誰欠誰 on purpose: these are the only rows on this page
              // that are waiting on somebody to do something.
              const DebtPendingSection(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'tx_debts_title'.tr(),
                  style: BrutalText.headlineLgMobile(fontSize: 22),
                ),
              ),
              const SizedBox(height: 12),
              if (debts.isEmpty)
                _EmptyLine('tx_no_debts'.tr())
              else
                for (final d in debts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DebtCard(debt: d, money: money),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top card: total owed to me vs total I owe.
class _DebtSummaryCard extends StatelessWidget {
  const _DebtSummaryCard({
    required this.money,
    required this.owedToMe,
    required this.iOwe,
  });

  final NumberFormat money;
  final int owedToMe;
  final int iOwe;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SummaryHalf(
                icon: LucideIcons.arrowDownLeft,
                label: 'tx_summary_owed'.tr(),
                amount: '+\$${money.format(owedToMe)}',
                amountColor: BrutalColors.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _SummaryHalf(
                icon: LucideIcons.arrowUpRight,
                label: 'tx_summary_owe'.tr(),
                amount: '-\$${money.format(iOwe)}',
                amountColor: BrutalColors.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHalf extends StatelessWidget {
  const _SummaryHalf({
    required this.icon,
    required this.label,
    required this.amount,
    required this.amountColor,
  });

  final IconData icon;
  final String label;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 0,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: BrutalColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.labelBold(
                    fontSize: 13,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: BrutalText.headlineLgMobile(
              fontSize: 22,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 債務紀錄 card — a debt between me and someone. Quick actions: share, settle.
class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.debt, required this.money});

  final DebtRecord debt;
  final NumberFormat money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owed = debt.owedToMe;
    final amountColor = owed
        ? BrutalColors.secondary
        : BrutalColors.onBackground;
    final relation = (owed ? 'tx_owes_you' : 'tx_you_owe').tr(
      namedArgs: {'name': debt.otherName},
    );

    // Tap the card body to open the underlying gathering (for a direct debt,
    // that's the only place to edit/delete it — it's hidden from the 攤 lists).
    // The action icons below capture their own taps first.
    return GestureDetector(
      onTap: () => context.push('/group/${debt.groupId}'),
      behavior: HitTestBehavior.opaque,
      child: BrutalCard(
        color: BrutalColors.surface,
        offset: 3,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(
                  label: owed
                      ? 'circle_card_owes_you'.tr()
                      : 'group_you_owe'.tr(),
                  color: owed
                      ? BrutalColors.secondary
                      : BrutalColors.surfaceContainerHigh,
                  textColor: owed ? BrutalColors.onError : null,
                ),
                const Spacer(),
                Text(
                  debt.groupName,
                  style: BrutalText.labelBold(
                    fontSize: 12,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    relation,
                    style: BrutalText.headlineLgMobile(fontSize: 19),
                  ),
                ),
                Text(
                  '${owed ? '+' : '-'}\$${money.format(debt.amount)}',
                  style: BrutalText.display(fontSize: 26, color: amountColor),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CardAction(
                    icon: LucideIcons.share2,
                    onTap: () => SharePlus.instance.share(
                      ShareParams(
                        text: '$relation \$${money.format(debt.amount)}',
                      ),
                    ),
                  ),
                  _CardAction(
                    icon: LucideIcons.checkCircle,
                    color: BrutalColors.primary,
                    onTap: () => showSettleSheet(
                      context,
                      groupId: debt.groupId,
                      transfer: debt.transfer,
                      fromName: owed ? debt.otherName : 'group_me'.tr(),
                      toName: owed ? 'group_me'.tr() : debt.otherName,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color, this.textColor});
  final String label;
  final Color color;
  final Color? textColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: color,
        radius: BrutalSpec.pillRadius,
        offset: 0,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      child: Text(
        label,
        style: BrutalText.labelBold(fontSize: 12, color: textColor),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: color ?? BrutalColors.onBackground),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: brutalDecoration(
      color: BrutalColors.surface,
      radius: BrutalSpec.cardRadius,
      offset: 0,
      borderWidth: BrutalSpec.borderWidthThin,
    ),
    alignment: Alignment.center,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: BrutalText.labelBold(
        fontSize: 14,
        color: BrutalColors.onSurfaceVariant,
      ),
    ),
  );
}
