import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/pages/trash_page.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';
import 'package:heymybro/shared/widgets/confirm_dialog.dart';

/// Ledger landing screen — pixel-aligned to
/// `assets/page_reference/ledger.html` (Rough Comic Neo-Brutalism, light).
class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.decimalPattern();
    final when = DateFormat('MM/dd HH:mm');

    // Real personal entries (fed by the home quick-add / record form).
    final personal =
        ref.watch(personalEntriesProvider).asData?.value ?? const [];
    final entries = [
      for (final e in personal)
        _LedgerEntry(
          id: e.id,
          icon: LucideIcons.receipt,
          title: e.title,
          when: when.format(e.createdAt),
          amount: -e.amount,
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
                    Row(
                      children: [
                        MarkerHighlight(
                          child: Text(
                            'ledger_title'.tr(),
                            style: BrutalText.headlineLgMobile(fontSize: 30),
                          ),
                        ),
                        const Spacer(),
                        TrashButton(onTap: () => showTrashModal(context)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _MonthlyBalanceCard(
                      money: money,
                      expense: ref.watch(monthSpendProvider),
                    ),
                    const SizedBox(height: 20),
                    _RecentRecordsCard(
                      entries: entries,
                      money: money,
                      onTapEntry: (e) => showPersonalEntrySheet(
                        context,
                        ref,
                        e.id,
                        e.title,
                        -e.amount,
                      ),
                    ),
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
  const _MonthlyBalanceCard({required this.money, required this.expense});

  final NumberFormat money;

  /// This month's real personal spend (just-me entries only; gathering/debt
  /// spend lives in 帳本). Income isn't tracked yet.
  final int expense;

  @override
  Widget build(BuildContext context) {
    const income = 0;
    final balance = income - expense;
    final monthAbbr = DateFormat('MMM').format(DateTime.now()).toUpperCase();
    return BrutalCard(
      color: BrutalColors.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'ledger_monthly_balance'.tr()} ($monthAbbr)'.toUpperCase(),
            style: BrutalText.labelBold(
              color: BrutalColors.onPrimaryContainer,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance < 0 ? '-' : ''}\$${money.format(balance.abs())}',
            style: BrutalText.display(fontSize: 44),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BalanceChip(
                    icon: LucideIcons.arrowDown,
                    label: 'ledger_income'.tr(),
                    labelColor: BrutalColors.onSurfaceVariant,
                    amount: '+\$${money.format(income)}',
                    amountColor: BrutalColors.onBackground,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _BalanceChip(
                    icon: LucideIcons.arrowUp,
                    label: 'ledger_expense'.tr(),
                    labelColor: BrutalColors.secondary,
                    amount: '-\$${money.format(expense)}',
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
// Recent records (each row has press effect)
// ---------------------------------------------------------------------------

class _RecentRecordsCard extends StatelessWidget {
  const _RecentRecordsCard({
    required this.entries,
    required this.money,
    required this.onTapEntry,
  });

  final List<_LedgerEntry> entries;
  final NumberFormat money;
  final void Function(_LedgerEntry) onTapEntry;

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
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'group_no_expenses'.tr(),
                style: BrutalText.labelBold(
                  fontSize: 14,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ),
          for (final entry in entries) ...[
            _EntryRow(
              entry: entry,
              money: money,
              onTap: () => onTapEntry(entry),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.money,
    required this.onTap,
  });

  final _LedgerEntry entry;
  final NumberFormat money;
  final VoidCallback onTap;

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
      onTap: onTap,
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
            child: Icon(entry.icon, size: 24, color: BrutalColors.onBackground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: BrutalText.body(weight: FontWeight.w800, fontSize: 16),
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

/// Edit-or-delete sheet for a personal ledger entry.
Future<void> showPersonalEntrySheet(
  BuildContext context,
  WidgetRef ref,
  String id,
  String title,
  int amount,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PersonalEntrySheet(id: id, title: title, amount: amount),
  );
}

class _PersonalEntrySheet extends ConsumerStatefulWidget {
  const _PersonalEntrySheet({
    required this.id,
    required this.title,
    required this.amount,
  });

  final String id;
  final String title;
  final int amount;

  @override
  ConsumerState<_PersonalEntrySheet> createState() =>
      _PersonalEntrySheetState();
}

class _PersonalEntrySheetState extends ConsumerState<_PersonalEntrySheet> {
  late final _titleCtrl = TextEditingController(text: widget.title);
  late final _amountCtrl = TextEditingController(text: '${widget.amount}');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (title.isEmpty) {
      showErrorSnakeBar('expense_title_required'.tr());
      return;
    }
    if (amount <= 0) {
      showErrorSnakeBar('expense_amount_required'.tr());
      return;
    }
    await ref
        .read(groupServiceProvider)
        .updatePersonalEntry(widget.id, title, amount);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (await confirmDialog(
      context,
      title: 'confirm_delete_entry'.tr(),
      confirmLabel: 'common_delete'.tr(),
      danger: true,
    )) {
      await ref.read(groupServiceProvider).deletePersonalEntry(widget.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrutalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'entry_edit_title'.tr(),
                  style: BrutalText.headlineLgMobile(fontSize: 22),
                ),
              ),
              GestureDetector(
                onTap: _delete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    LucideIcons.trash2,
                    size: 24,
                    color: BrutalColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sheetField(_titleCtrl, 'expense_title_hint'.tr()),
          const SizedBox(height: 12),
          _sheetField(_amountCtrl, '0', number: true),
          const SizedBox(height: 18),
          PressableBrutal(
            onTap: _save,
            color: BrutalColors.primaryContainer,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'common_save'.tr(),
              style: BrutalText.labelBold(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField(
    TextEditingController controller,
    String hint, {
    bool number = false,
  }) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        cursorColor: BrutalColors.onBackground,
        style: BrutalText.body(fontSize: 16),
        decoration: InputDecoration(
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
    );
  }
}

class _LedgerEntry {
  const _LedgerEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.when,
    required this.amount,
  });

  /// Personal-entry id (for edit/delete).
  final String id;
  final IconData icon;
  final String title;
  final String when;
  final int amount;
}
