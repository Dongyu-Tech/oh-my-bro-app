import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:heymybro/shared/pages/transaction_card.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Transaction screen — pixel-aligned to
/// `assets/page_reference/new ledger.html` (Rough Comic Neo-Brutalism, light).
///
/// Top-to-bottom: ledger-category tab switcher (對外債務 / 個人私帳) → monthly
/// income/expense summary card with mascot → the "私帳清單" transaction list.
/// Data is hardcoded sample content, consistent with [LedgerPage]; the repo is
/// still a DB-less scaffold.
class TransactionPage extends ConsumerWidget {
  const TransactionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.decimalPattern();

    final entries = <TransactionEntry>[
      TransactionEntry(
        title: 'sample_donate'.tr(),
        subtitle: 'tx_category_personal'.tr(),
        date: '4/2',
        amount: -500,
      ),
      TransactionEntry(
        title: 'sample_fuel'.tr(),
        subtitle: 'tx_category_personal'.tr(),
        date: '4/2',
        amount: -611,
      ),
      TransactionEntry(
        title: 'sample_salary'.tr(),
        subtitle: 'tx_category_personal'.tr(),
        date: '4/1',
        amount: 20000,
      ),
    ];

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: DottedBackdrop(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // Left-aligned so the marker band hugs the text (the
                    // ListView would otherwise stretch it full-width).
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MarkerHighlight(
                        child: Text(
                          'transaction_title'.tr(),
                          style: BrutalText.headlineLgMobile(fontSize: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _LedgerTabSwitcher(),
                    const SizedBox(height: 20),
                    _MonthlySummaryCard(money: money),
                    const SizedBox(height: 20),
                    _TransactionListSection(entries: entries, money: money),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ledger-category tab switcher: 對外債務 / 個人私帳 (personal active)
// ---------------------------------------------------------------------------

class _LedgerTabSwitcher extends StatefulWidget {
  const _LedgerTabSwitcher();

  @override
  State<_LedgerTabSwitcher> createState() => _LedgerTabSwitcherState();
}

class _LedgerTabSwitcherState extends State<_LedgerTabSwitcher> {
  // 0 = 對外債務 (external debt), 1 = 個人私帳 (personal) — personal active.
  int _active = 1;

  @override
  Widget build(BuildContext context) {
    final labels = ['tx_tab_external'.tr(), 'tx_tab_personal'.tr()];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _SwitchPill(
              label: labels[i],
              active: i == _active,
              onTap: () => setState(() => _active = i),
            ),
          ),
        ],
      ],
    );
  }
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      color: active ? BrutalColors.primaryContainer : BrutalColors.surface,
      radius: BrutalSpec.pillRadius,
      restOffset: active ? 4 : 2,
      pressedOffset: active ? 1 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: BrutalText.labelBold(
            color: active
                ? BrutalColors.onPrimaryContainer
                : BrutalColors.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly income / expense summary card (本月收支統計) + mascot balance
// ---------------------------------------------------------------------------

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.money});

  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tx_summary_title'.tr().toUpperCase(),
            style: BrutalText.labelBold(
              color: BrutalColors.onPrimaryContainer,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryChip(
                    icon: LucideIcons.arrowDownLeft,
                    label: 'ledger_income'.tr(),
                    amount: '+\$${money.format(0)}',
                    amountColor: BrutalColors.primaryFixedDim,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SummaryChip(
                    icon: LucideIcons.arrowUpRight,
                    label: 'ledger_expense'.tr(),
                    amount: '-\$${money.format(0)}',
                    amountColor: BrutalColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: BrutalColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: BrutalColors.onBackground,
                    width: BrutalSpec.borderWidth,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.smile,
                  color: BrutalColors.onBackground,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ledger_monthly_balance'.tr(),
                      style: BrutalText.labelBold(
                        color: BrutalColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+\$${money.format(0)}',
                      style: BrutalText.display(fontSize: 32),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
    return BrutalPill(
      color: BrutalColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: BrutalColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: BrutalText.labelBold(
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: BrutalText.headlineLgMobile(
              fontSize: 22,
              color: amountColor,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transaction list (私帳清單) with a delete action in the header
// ---------------------------------------------------------------------------

class _TransactionListSection extends StatelessWidget {
  const _TransactionListSection({required this.entries, required this.money});

  final List<TransactionEntry> entries;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    // No enclosing outline — the section title sits on the dotted backdrop and
    // the bordered transaction cards (shared [TransactionGrid]) provide the
    // visible structure.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'tx_list_title'.tr(),
              style: BrutalText.headlineLgMobile(fontSize: 22),
            ),
            PressableBrutal(
              color: BrutalColors.surfaceContainerHighest,
              radius: BrutalSpec.pillRadius,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              onTap: () {},
              child: const Icon(
                LucideIcons.trash2,
                color: BrutalColors.secondary,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TransactionGrid(entries: entries, money: money),
      ],
    );
  }
}
