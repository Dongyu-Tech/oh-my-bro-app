import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/split/settlement.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The unified "+" tab: one page to record a spend. Pick "跟誰分" — just me, a
/// circle (a 1-on-1 is simply a 2-person circle), or spin up a new one. Picking
/// a circle reveals payer + equal/custom split. Personal entries have no store
/// yet (that's the ledger's job), so they show a "coming soon" note.
class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  /// Lazily-created per-member custom-amount inputs (kept across rebuilds).
  final _customCtrls = <String, TextEditingController>{};

  /// Selected circle id; null means "just me" (personal).
  String? _teamId;
  String? _payerId;
  bool _custom = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  TextEditingController _ctrlFor(String memberId) =>
      _customCtrls.putIfAbsent(memberId, TextEditingController.new);

  void _selectTeam(String? id) {
    setState(() {
      _teamId = id;
      _payerId = null; // re-defaults to "me" once members load
      _custom = false;
    });
  }

  Future<void> _save(List<Member> members) async {
    if (_saving) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showErrorSnakeBar('expense_title_required'.tr());
      return;
    }
    if (_amount <= 0) {
      showErrorSnakeBar('expense_amount_required'.tr());
      return;
    }

    // Personal entry: save it (same store the home quick-add feeds).
    if (_teamId == null) {
      await ref
          .read(groupServiceProvider)
          .addPersonalEntry(title: title, amount: _amount);
      if (!mounted) return;
      _resetForm();
      showMessage('record_saved'.tr());
      return;
    }

    final payerId = _payerId ?? members.firstWhere((m) => m.isMe).id;
    final Map<String, int> shares;
    if (_custom) {
      shares = {
        for (final m in members)
          m.id: int.tryParse(_ctrlFor(m.id).text.trim()) ?? 0,
      };
      if (shares.values.fold(0, (a, b) => a + b) != _amount) {
        showErrorSnakeBar('expense_custom_mismatch'.tr());
        return;
      }
    } else {
      final slices = splitEqually(_amount, members.length);
      shares = {
        for (var i = 0; i < members.length; i++) members[i].id: slices[i],
      };
    }

    setState(() => _saving = true);
    final teamId = _teamId!;
    await ref
        .read(groupServiceProvider)
        .addExpense(
          groupId: teamId,
          title: title,
          amount: _amount,
          payerId: payerId,
          shares: shares,
        );
    if (!mounted) return;
    _resetForm();
    showMessage('record_saved'.tr());
    // Jump into the circle so the fresh entry + settle-up are visible.
    context.push('/group/$teamId');
  }

  void _resetForm() {
    setState(() {
      _saving = false;
      _titleCtrl.clear();
      _amountCtrl.clear();
      for (final c in _customCtrls.values) {
        c.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teams = (ref.watch(groupsProvider).asData?.value ?? const [])
        .where((g) => !g.isArchived)
        .toList();
    final members = _teamId == null
        ? const <Member>[]
        : (ref.watch(groupMembersProvider(_teamId!)).asData?.value ??
              const <Member>[]);
    _payerId ??= members.where((m) => m.isMe).map((m) => m.id).firstOrNull;

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        bottom: false,
        child: DottedBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Pushed from the home dashboard, so it needs a way back.
              Row(
                children: [
                  const BrutalBackButton(),
                  const SizedBox(width: 12),
                  MarkerHighlight(
                    child: Text(
                      'new_tx_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: Center(
                  child: Image.asset(
                    'assets/mascot/stickers/07_weird-bill.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Label('expense_title_label'.tr()),
              _Field(
                controller: _titleCtrl,
                hint: 'expense_title_hint'.tr(),
                trailing: PressableBrutal(
                  color: BrutalColors.primaryContainer,
                  radius: 22,
                  width: 40,
                  height: 40,
                  restOffset: 3,
                  pressedOffset: 1,
                  alignment: Alignment.center,
                  onTap: comingSoon,
                  child: const Icon(LucideIcons.mic, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              _Label('expense_amount_label'.tr()),
              _Field(
                controller: _amountCtrl,
                hint: '0',
                number: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              _Label('record_with_who'.tr()),
              _WhoSelector(
                teams: teams,
                selectedId: _teamId,
                onSelectMe: () => _selectTeam(null),
                onSelectTeam: _selectTeam,
                onNewTeam: () => context.push('/group/new'),
              ),
              if (_teamId != null) ...[
                const SizedBox(height: 18),
                if (members.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _Label('expense_payer_label'.tr()),
                  _MemberChips(
                    members: members,
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
                    _CustomSplit(
                      members: members,
                      ctrlFor: _ctrlFor,
                      amount: _amount,
                      onChanged: () => setState(() {}),
                    )
                  else
                    _EqualPreview(
                      members: members,
                      slices: splitEqually(_amount, members.length),
                    ),
                ],
              ],
              const SizedBox(height: 22),
              _WideButton(
                label: 'new_tx_record'.tr(),
                icon: LucideIcons.utensils,
                onTap: _saving ? null : () => _save(members),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "跟誰分" chips: 我自己 / each active circle / ＋開新團.
class _WhoSelector extends StatelessWidget {
  const _WhoSelector({
    required this.teams,
    required this.selectedId,
    required this.onSelectMe,
    required this.onSelectTeam,
    required this.onNewTeam,
  });

  final List<Group> teams;
  final String? selectedId;
  final VoidCallback onSelectMe;
  final ValueChanged<String> onSelectTeam;
  final VoidCallback onNewTeam;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          label: 'record_me'.tr(),
          icon: LucideIcons.user,
          selected: selectedId == null,
          onTap: onSelectMe,
        ),
        for (final t in teams)
          _Chip(
            label: t.name,
            icon: LucideIcons.users,
            selected: selectedId == t.id,
            onTap: () => onSelectTeam(t.id),
          ),
        _Chip(
          label: 'add_pick_new'.tr(),
          icon: LucideIcons.plus,
          selected: false,
          dashed: true,
          onTap: onNewTeam,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.dashed = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: brutalDecoration(
          color: selected
              ? BrutalColors.primaryContainer
              : BrutalColors.surface,
          radius: BrutalSpec.pillRadius,
          offset: selected ? 3 : 0,
          borderWidth: BrutalSpec.borderWidthThin,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: BrutalText.labelBold(fontSize: 14)),
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
    padding: const EdgeInsets.only(bottom: 8),
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
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 3,
      ),
      padding: EdgeInsets.fromLTRB(14, 0, trailing == null ? 14 : 8, 0),
      child: Row(
        children: [
          Expanded(
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
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
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
  final String? selectedId;
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

class _CustomSplit extends StatelessWidget {
  const _CustomSplit({
    required this.members,
    required this.ctrlFor,
    required this.amount,
    required this.onChanged,
  });

  final List<Member> members;
  final TextEditingController Function(String) ctrlFor;
  final int amount;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    final sum = members.fold(
      0,
      (a, m) => a + (int.tryParse(ctrlFor(m.id).text.trim()) ?? 0),
    );
    final ok = sum == amount;
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
                    controller: ctrlFor(m.id),
                    hint: '0',
                    number: true,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ),
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

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: PressableBrutal(
        color: BrutalColors.primaryContainer,
        radius: BrutalSpec.pillRadius,
        width: double.infinity,
        restOffset: BrutalSpec.shadowOffset,
        pressedOffset: BrutalSpec.shadowOffsetPressed,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: BrutalColors.onPrimaryContainer),
            const SizedBox(width: 10),
            Text(
              label,
              style: BrutalText.headlineLgMobile(
                fontSize: 20,
                color: BrutalColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
