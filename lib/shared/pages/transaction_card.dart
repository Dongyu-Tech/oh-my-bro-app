import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:heymybro/shared/pages/transaction_detail_sheet.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// One ledger entry rendered by [TransactionCard]. [subtitle] is the secondary
/// line under the item name — the category for a personal 私帳 entry, or the
/// counterparty for a shared 往來帳務 entry. It also becomes the detail sheet's
/// 對象.
class TransactionEntry {
  const TransactionEntry({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final String date;

  /// Signed minor amount — negative for 支出, positive for 收入.
  final int amount;
}

/// The single transaction card shared by the 私帳清單 ([TransactionPage]) and
/// the 往來帳務 ([FriendLedgerPage]) grids — same look AND same behaviour, so a
/// tap anywhere opens the one [showTransactionDetail] sheet.
///
/// Header (type badge + date) → icon + 項目 (name + [TransactionEntry.subtitle])
/// → 金額, stacked so it reads at half width inside a 2-column grid.
class TransactionCard extends StatelessWidget {
  const TransactionCard({super.key, required this.entry, required this.money});

  final TransactionEntry entry;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final positive = entry.amount > 0;
    final amountText =
        '\$${positive ? '+' : '-'}${money.format(entry.amount.abs())}';
    final amountColor = positive
        ? BrutalColors.primaryFixedDim
        : BrutalColors.secondary;

    return PressableBrutal(
      color: BrutalColors.surfaceContainerHighest,
      radius: BrutalSpec.pillRadius,
      restOffset: 4,
      pressedOffset: 1,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: () => showTransactionDetail(
        context,
        TxDetail(
          target: entry.subtitle,
          item: entry.title,
          amount: entry.amount,
          lines: [
            TxLine(time: entry.date, item: entry.title, amount: entry.amount),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: type badge + date.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TypeBadge(positive: positive),
              Text(
                entry.date,
                style: BrutalText.labelBold(
                  color: BrutalColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Icon + 項目 (item name + subtitle)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BrutalColors.onBackground,
                  borderRadius: BorderRadius.circular(BrutalSpec.pillRadius),
                ),
                alignment: Alignment.center,
                child: Icon(
                  positive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                  color: BrutalColors.surface,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'tx_item'.tr(),
                      style: BrutalText.labelBold(
                        color: BrutalColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BrutalText.headlineLgMobile(fontSize: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BrutalText.labelBold(
                        color: BrutalColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 金額 — amount
          Text(
            'tx_amount'.tr(),
            style: BrutalText.labelBold(
              color: BrutalColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          // Scale the big number down rather than overflow a narrow cell.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amountText,
              maxLines: 1,
              style: BrutalText.display(fontSize: 32, color: amountColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 收入 / 支出 pill badge in the card header.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.positive});

  final bool positive;

  @override
  Widget build(BuildContext context) {
    final label = positive ? 'ledger_income'.tr() : 'ledger_expense'.tr();
    final color = positive
        ? BrutalColors.primaryContainer
        : BrutalColors.secondary;
    final onColor = positive ? BrutalColors.onBackground : BrutalColors.onError;

    return Container(
      decoration: brutalDecoration(
        color: color,
        radius: BrutalSpec.pillRadius,
        offset: 0,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: BrutalText.labelBold(color: onColor, fontSize: 12),
      ),
    );
  }
}

/// Shared 2-column grid of [TransactionCard]s (HTML grid-cols-2) — the same
/// layout the 私帳清單 and 往來帳務 lists both use.
class TransactionGrid extends StatelessWidget {
  const TransactionGrid({
    super.key,
    required this.entries,
    required this.money,
  });

  final List<TransactionEntry> entries;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TransactionCard(entry: entries[i], money: money),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < entries.length
                      ? TransactionCard(entry: entries[i + 1], money: money)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
