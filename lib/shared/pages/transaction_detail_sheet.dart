import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// One line in a transaction's 細項 (breakdown) table: 時間 / 項目 / 金額.
class TxLine {
  const TxLine({required this.time, required this.item, required this.amount});

  final String time;
  final String item;

  /// Signed minor amount — negative for 支出, positive for 收入.
  final int amount;
}

/// Payload for [showTransactionDetail] — the data the detail panel renders.
///
/// Currently built from the hardcoded sample [TransactionEntry] rows shared by
/// the 私帳清單 and 往來帳務 lists; when the ledger becomes DB-backed, map a Drift
/// row into this same shape so the panel stays presentation-only.
class TxDetail {
  const TxDetail({
    required this.target,
    required this.item,
    required this.amount,
    required this.lines,
  });

  /// 對象 — counterparty for external debt, or the category for 私帳.
  final String target;

  /// 項目 — the transaction name; also drives the marker-highlight title.
  final String item;

  /// 總額 — signed total (mirrors [TxLine.amount] sign convention).
  final int amount;

  /// 細項 rows summed into [amount].
  final List<TxLine> lines;
}

/// Slides the [TxDetail] panel in from the right edge — a brutal side-sheet
/// over the whole app (it covers the bottom nav, matching the reference).
///
/// Layout mirrors the design reference; colours come entirely from
/// [BrutalColors] rather than the reference's palette. Every action except
/// close is a [comingSoon] stub while the repo is still a DB-less scaffold.
Future<void> showTransactionDetail(BuildContext context, TxDetail detail) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'tx_detail_close'.tr(),
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, _, __) => _TransactionDetailPanel(detail: detail),
    transitionBuilder: (context, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Right-anchored panel (~60% width) with a left-edge "<" close handle sitting
/// in the dimmed gutter. The handle and the barrier both pop the sheet.
class _TransactionDetailPanel extends StatelessWidget {
  const _TransactionDetailPanel({required this.detail});

  final TxDetail detail;

  @override
  Widget build(BuildContext context) {
    final panelWidth = MediaQuery.of(context).size.width * 0.6;

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CloseHandle(onTap: () => Navigator.of(context).pop()),
          // Flexible so a narrow screen shrinks the panel instead of letting
          // handle + panel overflow the row.
          Flexible(
            child: SizedBox(
              width: panelWidth,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: const BoxDecoration(
                    color: BrutalColors.background,
                    border: Border(
                      left: BorderSide(
                        color: BrutalColors.onBackground,
                        width: BrutalSpec.borderWidth,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    left: false,
                    child: Column(
                      children: [
                        const _PanelHeader(),
                        Expanded(
                          child: DottedBackdrop(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                32,
                              ),
                              children: [
                                _TitleHighlight(detail: detail),
                                const SizedBox(height: 20),
                                _SummaryCard(detail: detail),
                                const SizedBox(height: 20),
                                _BreakdownTable(detail: detail),
                                const SizedBox(height: 28),
                                const _SealedCelebration(),
                                const SizedBox(height: 24),
                                const _ActionButtons(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "<" tab clinging to the panel's left edge, in the dimmed gutter — tap to
/// close. Mirrors the reference's pull handle.
class _CloseHandle extends StatelessWidget {
  const _CloseHandle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      color: BrutalColors.surfaceContainerHighest,
      radius: BrutalSpec.pillRadius,
      width: 38,
      height: 64,
      restOffset: BrutalSpec.shadowOffsetMobile,
      pressedOffset: 1,
      alignment: Alignment.center,
      onTap: onTap,
      child: const Icon(
        LucideIcons.chevronLeft,
        color: BrutalColors.onBackground,
        size: 22,
      ),
    );
  }
}

/// Dark ink brand bar: 粗哥 avatar + brand name.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BrutalColors.onBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BrutalColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: BrutalColors.surface,
                width: BrutalSpec.borderWidthThin,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/mascot/stickers/11_wink-seal.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ledger_brand'.tr(),
              style: BrutalText.headlineLgMobile(
                color: BrutalColors.surface,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「{項目} 細項」 in the main-screen marker-highlight style.
class _TitleHighlight extends StatelessWidget {
  const _TitleHighlight({required this.detail});

  final TxDetail detail;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: MarkerHighlight(
        child: Text(
          '${detail.item} ${'tx_detail_suffix'.tr()}',
          style: BrutalText.headlineLgMobile(fontSize: 26),
        ),
      ),
    );
  }
}

/// Receipt-style summary card: 對象 / 項目 / 總額 rows with thin dividers.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail});

  final TxDetail detail;

  @override
  Widget build(BuildContext context) {
    final positive = detail.amount > 0;
    final money = NumberFormat.decimalPattern();
    final amountText =
        '\$${positive ? '+' : '-'}${money.format(detail.amount.abs())}';
    final amountColor = positive
        ? BrutalColors.incomeInk
        : BrutalColors.secondary;

    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.cardRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          _SummaryRow(label: 'tx_detail_target'.tr(), value: detail.target),
          const _RowDivider(),
          _SummaryRow(label: 'tx_item'.tr(), value: detail.item),
          const _RowDivider(),
          _SummaryRow(
            label: 'tx_detail_total'.tr(),
            value: amountText,
            valueStyle: BrutalText.display(fontSize: 30, color: amountColor),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$label:',
            style: BrutalText.headlineLgMobile(
              fontSize: 18,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle ?? BrutalText.headlineLgMobile(fontSize: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin hairline between summary rows (lighter than [BrutalDivider]).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, color: BrutalColors.surfaceContainerHighest);
  }
}

/// 細項 table: 時間 | 項目 | 金額 header → rows → 總計.
class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({required this.detail});

  final TxDetail detail;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    final total = detail.lines.fold<int>(0, (sum, l) => sum + l.amount);
    final totalPositive = total > 0;
    final totalText =
        '\$${totalPositive ? '+' : '-'}${money.format(total.abs())}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Column headers.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(flex: 4, child: _HeaderLabel('tx_detail_col_time'.tr())),
              Expanded(flex: 3, child: _HeaderLabel('tx_item'.tr())),
              Expanded(
                flex: 3,
                child: _HeaderLabel('tx_amount'.tr(), align: TextAlign.right),
              ),
            ],
          ),
        ),
        const BrutalDivider(margin: EdgeInsets.symmetric(vertical: 10)),
        for (final line in detail.lines)
          _BreakdownRow(line: line, money: money),
        const BrutalDivider(margin: EdgeInsets.symmetric(vertical: 10)),
        // 總計 row.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'tx_detail_grand_total'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.headlineLgMobile(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                totalText,
                style: BrutalText.display(
                  fontSize: 26,
                  color: totalPositive
                      ? BrutalColors.incomeInk
                      : BrutalColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text, {this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: BrutalText.labelBold(
        color: BrutalColors.onSurfaceVariant,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.line, required this.money});

  final TxLine line;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final positive = line.amount > 0;
    final amountText =
        '\$${positive ? '+' : '-'}${money.format(line.amount.abs())}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              line.time,
              style: BrutalText.labelBold(
                color: BrutalColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              line.item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BrutalText.headlineLgMobile(fontSize: 18),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              amountText,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: BrutalText.headlineLgMobile(
                fontSize: 18,
                color: positive
                    ? BrutalColors.incomeInk
                    : BrutalColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 封帳成功 celebration: success sticker + rotated stamp.
class _SealedCelebration extends StatelessWidget {
  const _SealedCelebration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/mascot/stickers/03_success.png',
            height: 180,
            fit: BoxFit.contain,
          ),
          // Rotated brutal "封帳成功！" stamp, top area.
          Positioned(
            top: 4,
            child: Transform.rotate(
              angle: -8 * math.pi / 180,
              child: Container(
                decoration: brutalDecoration(
                  color: BrutalColors.dangerBanner,
                  radius: BrutalSpec.pillRadius,
                  offset: BrutalSpec.shadowOffsetMobile,
                  borderWidth: BrutalSpec.borderWidthThin,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'tx_detail_sealed'.tr(),
                  style: BrutalText.headlineLgMobile(
                    color: BrutalColors.onError,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stacked actions: 結清 (primary) → 編輯 / 分享 → 丟進回收桶 (danger).
/// All stubbed to [comingSoon] until the ledger is DB-backed.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WideAction(
          label: 'tx_detail_settle'.tr(),
          icon: LucideIcons.checkCircle,
          color: BrutalColors.success,
          textColor: BrutalColors.onBackground,
          onTap: comingSoon,
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _WideAction(
                  label: 'tx_detail_edit'.tr(),
                  icon: LucideIcons.pencil,
                  color: BrutalColors.surface,
                  textColor: BrutalColors.onBackground,
                  onTap: comingSoon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WideAction(
                  label: 'tx_detail_share'.tr(),
                  icon: LucideIcons.share2,
                  color: BrutalColors.surface,
                  textColor: BrutalColors.onBackground,
                  onTap: comingSoon,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WideAction(
          label: 'tx_detail_delete'.tr(),
          icon: LucideIcons.trash2,
          color: BrutalColors.secondary,
          textColor: BrutalColors.onError,
          onTap: comingSoon,
        ),
      ],
    );
  }
}

class _WideAction extends StatelessWidget {
  const _WideAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      color: color,
      radius: BrutalSpec.pillRadius,
      width: double.infinity,
      restOffset: BrutalSpec.shadowOffsetMobile,
      pressedOffset: BrutalSpec.shadowOffsetPressed,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      alignment: Alignment.center,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BrutalText.headlineLgMobile(
                fontSize: 18,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
