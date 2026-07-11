import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/split/settlement.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';
import 'package:heymybro/shared/widgets/confirm_dialog.dart';
import 'group_expense_sheet.dart';
import 'log_share_prompt.dart';

/// A group's split-the-bill home: total spend, my net, the settle-up plan, the
/// expense list, an invite entry, and the "record a spend" action.
class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref
        .watch(groupsProvider)
        .asData
        ?.value
        .firstWhereOrNull((g) => g.id == groupId);
    final members =
        ref.watch(groupMembersProvider(groupId)).asData?.value ?? [];
    final expenses =
        ref.watch(groupExpensesProvider(groupId)).asData?.value ?? [];
    final shares =
        ref.watch(groupSharesProvider(groupId)).asData?.value ?? const [];
    final settlements =
        ref.watch(groupSettlementsProvider(groupId)).asData?.value ?? const [];
    final summary = ref.watch(groupSummaryProvider(groupId)).asData?.value;

    // Group missing (still loading, or was deleted from underneath us).
    if (group == null) {
      return const Scaffold(
        backgroundColor: BrutalColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nameOf = {
      for (final m in members) m.id: m.isMe ? 'group_me'.tr() : m.name,
    };

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            children: [
              _TopBar(group: group, groupId: groupId),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _SummaryCard(
                      total: summary?.total ?? 0,
                      myNet: summary?.myNet ?? 0,
                      color: Color(group.colorValue),
                    ),
                    const SizedBox(height: 16),
                    PressableBrutal(
                      onTap: () => _showInviteSheet(context, group),
                      color: BrutalColors.surface,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.userPlus, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'group_invite'.tr(),
                            style: BrutalText.labelBold(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel('group_settle_title'.tr()),
                    const SizedBox(height: 10),
                    _SettleList(
                      groupId: groupId,
                      transfers: summary?.transfers ?? const [],
                      nameOf: nameOf,
                    ),
                    if (settlements.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionLabel('settled_records'.tr()),
                      const SizedBox(height: 10),
                      for (final s in settlements)
                        _SettlementRow(
                          settlement: s,
                          nameOf: nameOf,
                          onUndo: () async {
                            if (await confirmDialog(
                              context,
                              title: 'settle_undo'.tr(),
                              confirmLabel: 'common_delete'.tr(),
                              danger: true,
                            )) {
                              await ref
                                  .read(groupServiceProvider)
                                  .deleteSettlement(s.id);
                            }
                          },
                        ),
                    ],
                    const SizedBox(height: 22),
                    _SectionLabel('group_expenses'.tr()),
                    const SizedBox(height: 10),
                    if (expenses.isEmpty)
                      _EmptyHint('group_no_expenses'.tr())
                    else
                      for (final e in expenses)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ExpenseCard(
                            expense: e,
                            payerName: nameOf[e.payerMemberId] ?? '?',
                            memberCount: members.length,
                            onEdit: () => showAddExpenseSheet(
                              context,
                              groupId: groupId,
                              members: members,
                              editing: e,
                              editingShares: shares
                                  .where((s) => s.expenseId == e.id)
                                  .toList(),
                            ),
                            onDelete: () async {
                              if (await confirmDialog(
                                context,
                                title: 'confirm_delete_expense'.tr(),
                                message: e.title,
                                confirmLabel: 'common_delete'.tr(),
                                danger: true,
                              )) {
                                await ref
                                    .read(groupServiceProvider)
                                    .deleteExpense(e.id);
                              }
                            },
                          ),
                        ),
                  ],
                ),
              ),
              _RecordBar(
                onTap: members.isEmpty
                    ? null
                    : () => showAddExpenseSheet(
                        context,
                        groupId: groupId,
                        members: members,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, Group group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(group: group),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.group, required this.groupId});

  final Group group;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const BrutalBackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BrutalText.headlineLgMobile(fontSize: 24),
            ),
          ),
          _IconButton(
            icon: LucideIcons.pencil,
            onTap: () => showEditGroupSheet(context, group),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: group.isArchived
                ? LucideIcons.archiveRestore
                : LucideIcons.archive,
            onTap: () => ref
                .read(groupServiceProvider)
                .setArchived(groupId, !group.isArchived),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: LucideIcons.trash2,
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'group_delete'.tr(),
      message: group.name,
      confirmLabel: 'group_delete'.tr(),
      danger: true,
    );
    if (ok && context.mounted) {
      await ref.read(groupServiceProvider).deleteGroup(groupId);
      if (context.mounted) context.pop();
    }
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      onTap: onTap,
      color: BrutalColors.surface,
      radius: BrutalSpec.pillRadius,
      padding: const EdgeInsets.all(9),
      child: Icon(icon, size: 20),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.myNet,
    required this.color,
  });

  final int total;
  final int myNet;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    // App convention: money coming TO you renders red "+", money you owe black "-".
    final (String label, Color amountColor, String text) = switch (myNet) {
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
      _ => ('group_settled'.tr(), BrutalColors.onSurfaceVariant, '\$0'),
    };

    return BrutalCard(
      color: BrutalColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: brutalDecoration(
              color: color,
              radius: BrutalSpec.pillRadius,
              offset: 0,
              borderWidth: BrutalSpec.borderWidthThin,
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.users, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'group_total'.tr(),
                  style: BrutalText.labelBold(
                    fontSize: 13,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '\$${money.format(total)}',
                  style: BrutalText.display(fontSize: 30),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: BrutalText.labelBold(
                  fontSize: 13,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
              Text(
                text,
                style: BrutalText.headlineLgMobile(
                  fontSize: 22,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettleList extends ConsumerWidget {
  const _SettleList({
    required this.groupId,
    required this.transfers,
    required this.nameOf,
  });

  final String groupId;
  final List<Transfer> transfers;
  final Map<String, String> nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transfers.isEmpty) return _EmptyHint('group_all_settled'.tr());
    final money = NumberFormat.decimalPattern();
    return Column(
      children: [
        for (final t in transfers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BrutalCard(
              color: BrutalColors.surface,
              offset: 3,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'group_pays_back'.tr(
                            namedArgs: {
                              'from': nameOf[t.from] ?? '?',
                              'to': nameOf[t.to] ?? '?',
                            },
                          ),
                          style: BrutalText.labelBold(fontSize: 15),
                        ),
                        Text(
                          '\$${money.format(t.amount)}',
                          style: BrutalText.labelBold(
                            fontSize: 15,
                            color: BrutalColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  PressableBrutal(
                    onTap: () => showSettleSheet(
                      context,
                      groupId: groupId,
                      transfer: t,
                      fromName: nameOf[t.from] ?? '?',
                      toName: nameOf[t.to] ?? '?',
                    ),
                    color: BrutalColors.primaryContainer,
                    radius: BrutalSpec.pillRadius,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Text(
                      'group_mark_paid'.tr(),
                      style: BrutalText.labelBold(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One recorded repayment, with an undo control.
class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.settlement,
    required this.nameOf,
    required this.onUndo,
  });

  final Settlement settlement;
  final Map<String, String> nameOf;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: brutalDecoration(
          color: BrutalColors.surface,
          radius: BrutalSpec.pillRadius,
          offset: 0,
          borderWidth: BrutalSpec.borderWidthThin,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${'group_pays_back'.tr(namedArgs: {'from': nameOf[settlement.fromMemberId] ?? '?', 'to': nameOf[settlement.toMemberId] ?? '?'})}  \$${money.format(settlement.amount)}',
                style: BrutalText.labelBold(fontSize: 14),
              ),
            ),
            GestureDetector(
              onTap: onUndo,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  LucideIcons.rotateCcw,
                  size: 18,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet to confirm a repayment — the amount defaults to the full suggested
/// transfer but can be lowered for a partial payment.
Future<void> showSettleSheet(
  BuildContext context, {
  required String groupId,
  required Transfer transfer,
  required String fromName,
  required String toName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettleSheet(
      groupId: groupId,
      transfer: transfer,
      fromName: fromName,
      toName: toName,
    ),
  );
}

class _SettleSheet extends ConsumerStatefulWidget {
  const _SettleSheet({
    required this.groupId,
    required this.transfer,
    required this.fromName,
    required this.toName,
  });

  final String groupId;
  final Transfer transfer;
  final String fromName;
  final String toName;

  @override
  ConsumerState<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends ConsumerState<_SettleSheet> {
  late final _amountCtrl = TextEditingController(
    text: '${widget.transfer.amount}',
  );

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.transfer.amount) {
      showErrorSnakeBar('expense_amount_required'.tr());
      return;
    }
    // Capture my pre-settlement state so clear-detection doesn't race the
    // Drift stream update below.
    final summary = ref
        .read(groupSummaryProvider(widget.groupId))
        .asData
        ?.value;
    final myId = ref
        .read(groupMembersProvider(widget.groupId))
        .asData
        ?.value
        .where((m) => m.isMe)
        .map((m) => m.id)
        .firstOrNull;

    final settlementId = await ref
        .read(groupServiceProvider)
        .settle(
          groupId: widget.groupId,
          fromMemberId: widget.transfer.from,
          toMemberId: widget.transfer.to,
          amount: amount,
        );

    // If this repayment fully cleared my net here, offer to log my share to
    // 個人記帳 (only when I actually consumed something — see the pure fn).
    final toBook = summary == null
        ? null
        : shareToBookAfterSettle(
            myNet: summary.myNet,
            myShare: summary.myShare,
            myMemberId: myId,
            transfer: widget.transfer,
            settledAmount: amount,
          );
    if (mounted && toBook != null) {
      final name =
          ref
              .read(groupsProvider)
              .asData
              ?.value
              .firstWhereOrNull((g) => g.id == widget.groupId)
              ?.name ??
          '';
      await promptLogMyShare(context, ref, [
        (title: name, amount: toBook, settlementId: settlementId),
      ]);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BrutalSheet(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'settle_title'.tr(),
            style: BrutalText.headlineLgMobile(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'group_pays_back'.tr(
              namedArgs: {'from': widget.fromName, 'to': widget.toName},
            ),
            style: BrutalText.labelBold(
              fontSize: 15,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'settle_amount'.tr(),
            style: BrutalText.labelBold(
              fontSize: 13,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: BrutalSpec.pillRadius,
              offset: 3,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              cursorColor: BrutalColors.onBackground,
              style: BrutalText.body(fontSize: 18),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          PressableBrutal(
            onTap: _confirm,
            color: BrutalColors.primaryContainer,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'settle_confirm'.tr(),
              style: BrutalText.labelBold(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.payerName,
    required this.memberCount,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final String payerName;
  final int memberCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: BrutalCard(
        color: BrutalColors.surface,
        offset: 3,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: BrutalText.headlineLgMobile(fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$payerName · ${'group_split_among'.tr(namedArgs: {'count': '$memberCount'})}',
                    style: BrutalText.labelBold(
                      fontSize: 12,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '\$${money.format(expense.amount)}',
              style: BrutalText.headlineLgMobile(fontSize: 18),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordBar extends StatelessWidget {
  const _RecordBar({required this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: PressableBrutal(
        onTap: onTap,
        color: BrutalColors.primaryContainer,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus, size: 20),
            const SizedBox(width: 8),
            Text(
              'group_add_expense'.tr(),
              style: BrutalText.labelBold(fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: BrutalText.headlineLgMobile(fontSize: 18));
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
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

/// Invite sheet — link, circle code, and a QR placeholder. Copy is real
/// (clipboard); share is a stub for the local MVP.
class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.group});

  final Group group;

  /// Deterministic 6-digit code derived from the group id.
  String get _code => (group.id.hashCode.abs() % 900000 + 100000).toString();

  String get _link => 'https://ohmybro.app/join/$_code';

  @override
  Widget build(BuildContext context) {
    return BrutalSheet(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'invite_title'.tr(),
            style: BrutalText.headlineLgMobile(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'invite_subtitle'.tr(),
            style: BrutalText.body(
              fontSize: 14,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          // QR placeholder (visual only for the local MVP).
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: brutalDecoration(
                color: BrutalColors.surface,
                radius: BrutalSpec.cardRadius,
                offset: 4,
              ),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.qrCode, size: 96),
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
          const SizedBox(height: 18),
          _CopyRow(label: 'invite_code_label'.tr(), value: _code),
          const SizedBox(height: 10),
          _CopyRow(label: 'invite_link_label'.tr(), value: _link),
          const SizedBox(height: 18),
          PressableBrutal(
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text:
                    '${'invite_share_text'.tr(namedArgs: {'name': group.name, 'code': _code})}\n$_link',
              ),
            ),
            color: BrutalColors.primaryContainer,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.share2, size: 18),
                const SizedBox(width: 8),
                Text(
                  'invite_share'.tr(),
                  style: BrutalText.labelBold(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 0,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: BrutalText.labelBold(
                    fontSize: 11,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.labelBold(fontSize: 15),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              showMessage('invite_copied'.tr());
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(LucideIcons.copy, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

const _editColors = <Color>[
  BrutalColors.primaryContainer,
  BrutalColors.purple,
  BrutalColors.success,
  BrutalColors.secondary,
  BrutalColors.primaryFixedDim,
];

/// Sheet to rename a gathering and change its cover colour.
Future<void> showEditGroupSheet(BuildContext context, Group group) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditGroupSheet(group: group),
  );
}

class _EditGroupSheet extends ConsumerStatefulWidget {
  const _EditGroupSheet({required this.group});

  final Group group;

  @override
  ConsumerState<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<_EditGroupSheet> {
  late final _nameCtrl = TextEditingController(text: widget.group.name);
  late int _colorIndex = () {
    final i = _editColors.indexWhere(
      (c) => c.toARGB32() == widget.group.colorValue,
    );
    return i >= 0 ? i : 0;
  }();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showErrorSnakeBar('group_name_required'.tr());
      return;
    }
    await ref
        .read(groupServiceProvider)
        .updateGroupInfo(
          widget.group.id,
          name,
          _editColors[_colorIndex].toARGB32(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BrutalSheet(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'group_edit'.tr(),
            style: BrutalText.headlineLgMobile(fontSize: 22),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: BrutalSpec.pillRadius,
              offset: 3,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _nameCtrl,
              cursorColor: BrutalColors.onBackground,
              style: BrutalText.body(fontSize: 16),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                hintText: 'group_name_hint'.tr(),
                hintStyle: BrutalText.body(
                  fontSize: 16,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _editColors.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: brutalDecoration(
                        color: _editColors[i],
                        radius: BrutalSpec.pillRadius,
                        offset: _colorIndex == i ? 3 : 0,
                        borderWidth: _colorIndex == i
                            ? BrutalSpec.borderWidth
                            : BrutalSpec.borderWidthThin,
                      ),
                      child: _colorIndex == i
                          ? const Icon(LucideIcons.check, size: 18)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
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
}
