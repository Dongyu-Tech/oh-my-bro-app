import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

/// Ledger landing screen — pixel-aligned to
/// `assets/page_reference/ledger.html` (Rough Comic Neo-Brutalism, light).
class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.decimalPattern();

    final entries = <_LedgerEntry>[
      _LedgerEntry(
        icon: Icons.lunch_dining,
        title: 'sample_lunch'.tr(),
        when: '${'ledger_today'.tr()} 12:30',
        amount: -120,
      ),
      _LedgerEntry(
        icon: Icons.local_cafe,
        title: 'sample_coffee'.tr(),
        when: '${'ledger_today'.tr()} 08:15',
        amount: -85,
      ),
      _LedgerEntry(
        icon: Icons.payments,
        title: 'sample_salary'.tr(),
        when: 'ledger_yesterday'.tr(),
        amount: 20000,
      ),
      _LedgerEntry(
        icon: Icons.directions_bus,
        title: 'sample_transit'.tr(),
        when: 'ledger_yesterday'.tr(),
        amount: -30,
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
                          'ledger_title'.tr(),
                          style: BrutalText.headlineLgMobile(fontSize: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _MonthlyBalanceCard(money: money),
                    const SizedBox(height: 20),
                    const _QuickAddCard(),
                    const SizedBox(height: 20),
                    _BudgetBanner(money: money),
                    const SizedBox(height: 20),
                    _RecentRecordsCard(entries: entries, money: money),
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
// Monthly balance card (no press — neo-brutal-no-hover)
// ---------------------------------------------------------------------------

class _MonthlyBalanceCard extends StatelessWidget {
  const _MonthlyBalanceCard({required this.money});

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
            '${'ledger_monthly_balance'.tr()} (OCT)'.toUpperCase(),
            style: BrutalText.labelBold(
              color: BrutalColors.onPrimaryContainer,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${money.format(14250)}',
            style: BrutalText.display(fontSize: 44),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BalanceChip(
                    icon: Icons.arrow_downward_rounded,
                    label: 'ledger_income'.tr(),
                    labelColor: BrutalColors.onSurfaceVariant,
                    amount: '+\$${money.format(20000)}',
                    amountColor: BrutalColors.onBackground,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _BalanceChip(
                    icon: Icons.arrow_upward_rounded,
                    label: 'ledger_expense'.tr(),
                    labelColor: BrutalColors.secondary,
                    amount: '-\$${money.format(5750)}',
                    amountColor: BrutalColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.amount,
    required this.amountColor,
  });

  final IconData icon;
  final String label;
  final Color labelColor;
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
              Icon(icon, size: 16, color: labelColor),
              const SizedBox(width: 4),
              Text(label, style: BrutalText.labelBold(color: labelColor)),
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
// Quick add card (has press effect on the inner buttons)
// ---------------------------------------------------------------------------

class _QuickAddCard extends StatefulWidget {
  const _QuickAddCard();

  @override
  State<_QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<_QuickAddCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.surfaceContainerHighest,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note,
                size: 26,
                color: BrutalColors.onBackground,
              ),
              const SizedBox(width: 6),
              Text(
                'ledger_quick_add'.tr(),
                style: BrutalText.headlineLgMobile(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _DropdownButton(label: '...', onTap: () {})),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ledger_owes'.tr(),
                  style: BrutalText.headlineLgMobile(fontSize: 20),
                ),
              ),
              Expanded(child: _DropdownButton(label: '...', onTap: () {})),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: brutalDecoration(
                      color: BrutalColors.surface,
                      radius: BrutalSpec.pillRadius,
                      offset: 0,
                      borderWidth: BrutalSpec.borderWidth,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _controller,
                      style: BrutalText.body(),
                      decoration: InputDecoration(
                        hintText: 'ledger_quick_hint'.tr(),
                        hintStyle: BrutalText.body(
                          color: BrutalColors.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PressableBrutal(
                  color: BrutalColors.primaryContainer,
                  radius: BrutalSpec.pillRadius,
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  onTap: () {},
                  child: const Icon(
                    Icons.add,
                    color: BrutalColors.onBackground,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownButton extends StatelessWidget {
  const _DropdownButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      color: BrutalColors.primaryContainer,
      radius: BrutalSpec.pillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(label, style: BrutalText.labelBold()),
            ),
          ),
          const Icon(
            Icons.expand_more,
            color: BrutalColors.onBackground,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Budget banner (vivid red, no press)
// ---------------------------------------------------------------------------

class _BudgetBanner extends StatelessWidget {
  const _BudgetBanner({required this.money});

  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.dangerBanner,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
              Icons.local_fire_department,
              color: BrutalColors.dangerBanner,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ledger_budget_kept'.tr(),
                  style: BrutalText.headlineLgMobile(
                    fontSize: 20,
                    color: BrutalColors.onError,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'ledger_budget_remaining'.tr()} \$${money.format(4250)}',
                  style: BrutalText.labelBold(
                    color: BrutalColors.onError.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent records (each row has press effect)
// ---------------------------------------------------------------------------

class _RecentRecordsCard extends StatelessWidget {
  const _RecentRecordsCard({required this.entries, required this.money});

  final List<_LedgerEntry> entries;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.surface,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ledger_recent'.tr(),
                style: BrutalText.headlineLgMobile(fontSize: 22),
              ),
              Text(
                'ledger_view_all'.tr(),
                style: BrutalText.labelBold(color: BrutalColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in entries) ...[
            _EntryRow(entry: entry, money: money),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.money});

  final _LedgerEntry entry;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final positive = entry.amount > 0;
    final amountText =
        '${positive ? '+' : '-'}${money.format(entry.amount.abs())}';
    final amountColor = positive
        ? BrutalColors.incomeInk
        : BrutalColors.secondary;

    return PressableBrutal(
      color: BrutalColors.surfaceContainerHighest,
      radius: BrutalSpec.pillRadius,
      restOffset: 4,
      pressedOffset: 1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: BrutalSpec.pillRadius,
              offset: 0,
              borderWidth: BrutalSpec.borderWidthThin,
            ),
            alignment: Alignment.center,
            child: Icon(
              entry.icon,
              size: 24,
              color: BrutalColors.onBackground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: BrutalText.body(
                    weight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.when,
                  style: BrutalText.labelBold(
                    color: BrutalColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amountText,
            style: BrutalText.headlineLgMobile(
              fontSize: 20,
              color: amountColor,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntry {
  const _LedgerEntry({
    required this.icon,
    required this.title,
    required this.when,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String when;
  final int amount;
}
