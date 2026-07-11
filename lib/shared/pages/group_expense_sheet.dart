import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/split/settlement.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Opens the expense sheet for [groupId]. Pass [editing] (+ its [editingShares])
/// to edit an existing expense instead of adding a new one.
Future<void> showAddExpenseSheet(
  BuildContext context, {
  required String groupId,
  required List<Member> members,
  Expense? editing,
  List<ExpenseShare>? editingShares,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddExpenseSheet(
      groupId: groupId,
      members: members,
      editing: editing,
      editingShares: editingShares ?? const [],
    ),
  );
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet({
    required this.groupId,
    required this.members,
    this.editing,
    this.editingShares = const [],
  });

  final String groupId;
  final List<Member> members;
  final Expense? editing;
  final List<ExpenseShare> editingShares;

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  /// Per-member custom-amount inputs, keyed by member id (custom mode only).
  late final Map<String, TextEditingController> _customControllers = {
    for (final m in widget.members) m.id: TextEditingController(),
  };

  late String _payerId = widget.members
      .firstWhere((m) => m.isMe, orElse: () => widget.members.first)
      .id;
  bool _custom = false;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) return;
    // Prefill from the expense being edited.
    _titleController.text = e.title;
    _amountController.text = '${e.amount}';
    _payerId = e.payerMemberId;
    final byMember = {
      for (final s in widget.editingShares) s.memberId: s.amount,
    };
    for (final m in widget.members) {
      _customControllers[m.id]!.text = '${byMember[m.id] ?? 0}';
    }
    // Equal if the shares match an even split; otherwise show custom.
    final equal = splitEqually(e.amount, widget.members.length);
    final matchesEqual = widget.members.asMap().entries.every(
      (entry) => (byMember[entry.value.id] ?? 0) == equal[entry.key],
    );
    _custom = !matchesEqual;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;

  /// Equal-split preview: the per-member slices for the current amount.
  List<int> get _equalSlices => splitEqually(_amount, widget.members.length);

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showErrorSnakeBar('expense_title_required'.tr());
      return;
    }
    if (_amount <= 0) {
      showErrorSnakeBar('expense_amount_required'.tr());
      return;
    }

    final Map<String, int> shares;
    if (_custom) {
      shares = {
        for (final m in widget.members)
          m.id: int.tryParse(_customControllers[m.id]!.text.trim()) ?? 0,
      };
      final sum = shares.values.fold(0, (a, b) => a + b);
      if (sum != _amount) {
        showErrorSnakeBar('expense_custom_mismatch'.tr());
        return;
      }
    } else {
      final slices = _equalSlices;
      shares = {
        for (var i = 0; i < widget.members.length; i++)
          widget.members[i].id: slices[i],
      };
    }

    setState(() => _saving = true);
    final service = ref.read(groupServiceProvider);
    if (_isEdit) {
      await service.updateExpense(
        expenseId: widget.editing!.id,
        title: title,
        amount: _amount,
        payerId: _payerId,
        shares: shares,
      );
    } else {
      await service.addExpense(
        groupId: widget.groupId,
        title: title,
        amount: _amount,
        payerId: _payerId,
        shares: shares,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BrutalSheet(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: BrutalColors.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Text(
              (_isEdit ? 'expense_edit_title' : 'group_add_expense').tr(),
              style: BrutalText.headlineLgMobile(fontSize: 22),
            ),
            const SizedBox(height: 16),
            _Label('expense_title_label'.tr()),
            _Field(
              controller: _titleController,
              hint: 'expense_title_hint'.tr(),
            ),
            const SizedBox(height: 14),
            _Label('expense_amount_label'.tr()),
            _Field(
              controller: _amountController,
              hint: '0',
              number: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _Label('expense_payer_label'.tr()),
            _MemberChips(
              members: widget.members,
              selectedId: _payerId,
              onSelect: (id) => setState(() => _payerId = id),
            ),
            const SizedBox(height: 14),
            _Label('expense_split_label'.tr()),
            _SplitToggle(
              custom: _custom,
              onChanged: (v) => setState(() => _custom = v),
            ),
            const SizedBox(height: 10),
            if (_custom)
              _CustomSplitFields(
                members: widget.members,
                controllers: _customControllers,
                onChanged: () => setState(() {}),
                amount: _amount,
              )
            else
              _EqualPreview(members: widget.members, slices: _equalSlices),
            const SizedBox(height: 18),
            PressableBrutal(
              onTap: _saving ? null : _save,
              color: BrutalColors.primaryContainer,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'expense_save'.tr(),
                style: BrutalText.labelBold(fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: BrutalText.labelBold(
        fontSize: 14,
        color: BrutalColors.onSurfaceVariant,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.number = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: BrutalColors.onBackground,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
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

class _MemberChips extends StatelessWidget {
  const _MemberChips({
    required this.members,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Member> members;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in members)
          GestureDetector(
            onTap: () => onSelect(m.id),
            child: BrutalPill(
              color: m.id == selectedId
                  ? BrutalColors.primaryContainer
                  : BrutalColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                m.isMe ? 'group_me'.tr() : m.name,
                style: BrutalText.labelBold(fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplitToggle extends StatelessWidget {
  const _SplitToggle({required this.custom, required this.onChanged});

  final bool custom;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleHalf(
            label: 'expense_split_equal'.tr(),
            active: !custom,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToggleHalf(
            label: 'expense_split_custom'.tr(),
            active: custom,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _ToggleHalf extends StatelessWidget {
  const _ToggleHalf({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: brutalDecoration(
          color: active ? BrutalColors.primaryContainer : BrutalColors.surface,
          radius: BrutalSpec.pillRadius,
          offset: active ? 3 : 0,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(label, style: BrutalText.labelBold(fontSize: 15)),
      ),
    );
  }
}

class _EqualPreview extends StatelessWidget {
  const _EqualPreview({required this.members, required this.slices});

  final List<Member> members;
  final List<int> slices;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    return Column(
      children: [
        for (var i = 0; i < members.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  members[i].isMe ? 'group_me'.tr() : members[i].name,
                  style: BrutalText.body(fontSize: 15),
                ),
                Text(
                  '\$${money.format(i < slices.length ? slices[i] : 0)}',
                  style: BrutalText.labelBold(fontSize: 15),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CustomSplitFields extends StatelessWidget {
  const _CustomSplitFields({
    required this.members,
    required this.controllers,
    required this.onChanged,
    required this.amount,
  });

  final List<Member> members;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final sum = controllers.values.fold(
      0,
      (a, c) => a + (int.tryParse(c.text.trim()) ?? 0),
    );
    final ok = sum == amount;
    final money = NumberFormat.decimalPattern();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in members)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    m.isMe ? 'group_me'.tr() : m.name,
                    style: BrutalText.body(fontSize: 15),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: _Field(
                    controller: controllers[m.id]!,
                    hint: '0',
                    number: true,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 2),
        Text(
          '${money.format(sum)} / ${money.format(amount)}',
          textAlign: TextAlign.right,
          style: BrutalText.labelBold(
            fontSize: 14,
            color: ok ? BrutalColors.onSurfaceVariant : BrutalColors.secondary,
          ),
        ),
      ],
    );
  }
}
