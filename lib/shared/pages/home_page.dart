import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/debt/debt_amount.dart';
import 'package:heymybro/shared/pages/join_room_sheet.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The 首頁 (Home) tab — the centre "throne" of the nav. A 揪團-first dashboard:
/// 粗哥 greets you, a quick box logs a personal spend, two big actions start or
/// join a gathering, and active gatherings show your net at a glance.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _quickCtrl = TextEditingController();

  @override
  void dispose() {
    _quickCtrl.dispose();
    super.dispose();
  }

  /// Parse "午餐 120" → title "午餐", amount 120 (trailing number = amount).
  Future<void> _quickAdd() async {
    final raw = _quickCtrl.text.trim();
    final match = RegExp(r'(\d+)\s*$').firstMatch(raw);
    final amount = match == null ? 0 : int.parse(match.group(1)!);
    if (amount <= 0) {
      showErrorSnakeBar('home_quick_need_amount'.tr());
      return;
    }
    var title = raw.substring(0, match!.start).trim();
    if (title.isEmpty) title = 'home_record'.tr();

    await ref
        .read(groupServiceProvider)
        .addPersonalEntry(title: title, amount: amount);
    if (!mounted) return;
    _quickCtrl.clear();
    FocusScope.of(context).unfocus();
    showMessage('record_saved'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final active = ref
        .watch(gatheringsProvider)
        .where((g) => !g.isArchived)
        .toList();

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        bottom: false,
        child: DottedBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            children: [
              const _HomeHeader(),
              const SizedBox(height: 18),
              // Quick personal-spend box (middle): type "午餐 120" → logged.
              _QuickAddBox(controller: _quickCtrl, onSubmit: _quickAdd),
              const SizedBox(height: 14),
              // Debt composer: [人] 欠 [人] · 項目 · 金額 — zero split maths.
              const _DebtComposer(),
              const SizedBox(height: 20),
              // Two big 揪團 actions.
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      color: BrutalColors.primaryContainer,
                      icon: LucideIcons.partyPopper,
                      title: 'circle_start_gather'.tr(),
                      sub: 'home_gather_sub'.tr(),
                      onTap: () => context.push('/group/new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      color: BrutalColors.surface,
                      icon: LucideIcons.logIn,
                      title: 'circle_join_code'.tr(),
                      sub: 'home_join_sub'.tr(),
                      onTap: () => showJoinRoomSheet(
                        context,
                        onJoined: (groupId) =>
                            context.push('/group/$groupId/room'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionRow(
                label: 'home_active'.tr(),
                onSeeAll: () => context.push('/gatherings'),
              ),
              const SizedBox(height: 12),
              if (active.isEmpty)
                _EmptyHint('home_empty'.tr())
              else
                for (final g in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _ActiveGatheringCard(group: g),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 首頁 signboard. Wears the same marker-highlighted headline every other
/// tab wears, so 首頁 reads as a titled page rather than a splash screen; 粗哥
/// moves to the right at sticker size and the greeting becomes something he
/// says, not a caption sitting under his feet.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarkerHighlight(
                child: Text(
                  'home_title'.tr(),
                  style: BrutalText.headlineLgMobile(fontSize: 30),
                ),
              ),
              const SizedBox(height: 12),
              // Full width of the column, not shrink-wrapped to the text, so
              // the tail lands next to 粗哥 instead of trailing off mid-air.
              SizedBox(
                width: double.infinity,
                child: BrutalSpeechBubble(
                  child: Text(
                    'home_greeting'.tr(),
                    style: BrutalText.body(
                      fontSize: 15,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Tilted like a sticker slapped on the page rather than a centred
        // portrait — the bubble's tail points into his chest.
        Transform.rotate(
          angle: -0.05,
          child: Image.asset(
            'assets/mascot/stickers/01_main-pointing.png',
            height: 116,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _QuickAddBox extends StatelessWidget {
  const _QuickAddBox({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.cardRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: BrutalColors.onBackground,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: BrutalText.body(fontSize: 16),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: InputBorder.none,
                hintText: 'home_quick_hint'.tr(),
                hintStyle: BrutalText.body(
                  fontSize: 15,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          PressableBrutal(
            onTap: onSubmit,
            color: BrutalColors.primaryContainer,
            radius: BrutalSpec.pillRadius,
            width: 46,
            height: 46,
            restOffset: 3,
            pressedOffset: 1,
            alignment: Alignment.center,
            child: const Icon(LucideIcons.plus, size: 22),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.label, required this.onSeeAll});
  final String label;
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSeeAll,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            label,
            style: BrutalText.labelBold(
              fontSize: 14,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: BrutalColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      onTap: onTap,
      color: color,
      radius: BrutalSpec.cardRadius,
      restOffset: 5,
      pressedOffset: 2,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 10),
          Text(title, style: BrutalText.headlineLgMobile(fontSize: 19)),
          const SizedBox(height: 3),
          Text(
            sub,
            style: BrutalText.labelBold(
              fontSize: 12,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One active gathering: cover tile, name, members + room code, my net.
class _ActiveGatheringCard extends ConsumerWidget {
  const _ActiveGatheringCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(groupMembersProvider(group.id)).asData?.value ?? const [];
    final myNet =
        ref.watch(groupSummaryProvider(group.id)).asData?.value.myNet ?? 0;
    final money = NumberFormat.decimalPattern();

    final (String label, Color color, String text) = switch (myNet) {
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
      _ => ('group_settled'.tr(), BrutalColors.onSurfaceVariant, ''),
    };

    return GestureDetector(
      onTap: () => context.push('/group/${group.id}'),
      behavior: HitTestBehavior.opaque,
      child: BrutalCard(
        color: BrutalColors.surface,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: brutalDecoration(
                color: Color(group.colorValue),
                radius: BrutalSpec.pillRadius,
                offset: 0,
                borderWidth: BrutalSpec.borderWidthThin,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrutalText.headlineLgMobile(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'group_members_count'.tr(namedArgs: {'count': '${members.length}'})}・${'room_code_label'.tr()} ${roomCodeFor(group.id)}',
                    style: BrutalText.labelBold(
                      fontSize: 12,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: BrutalText.labelBold(
                    fontSize: 11,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: BrutalText.headlineLgMobile(
                      fontSize: 18,
                      color: color,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

/// A person on one side of a debt: your own account or a saved friend.
///
/// [userId] is the account behind them, which the proposal is addressed to.
/// It is non-null for everyone the picker will hand back — friends without an
/// account cannot be selected, because no device of theirs could ever receive
/// the confirmation request.
typedef _Party = ({String name, String? friendId, String? userId, bool isMe});

/// "[人] 欠 [人] · 項目 · 金額" — records a direct debt with zero split maths.
class _DebtComposer extends ConsumerStatefulWidget {
  const _DebtComposer();

  @override
  ConsumerState<_DebtComposer> createState() => _DebtComposerState();
}

class _DebtComposerState extends ConsumerState<_DebtComposer> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  _Party? _debtor;
  _Party? _creditor;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  _Party get _me => (
    name: 'group_me'.tr(),
    friendId: null,
    userId: ref.read(myUserIdProvider),
    isMe: true,
  );

  bool _same(_Party a, _Party b) =>
      (a.isMe && b.isMe) || (a.friendId != null && a.friendId == b.friendId);

  Future<void> _pick(bool debtorSide) async {
    final friends = ref.read(friendsProvider).asData?.value ?? const <Friend>[];
    final current = debtorSide ? _debtor : _creditor;
    final picked = await _showPersonPickerSheet(
      context,
      friends: friends,
      selectedFriendId: current?.friendId,
    );
    if (picked == null || !mounted) return;

    // Exactly one side is always me. A debt between two *other* people isn't
    // mine to record (friend_provider drops those from 帳本), and 我欠我 is
    // nonsense — so picking a friend for one slot pins the other slot to me.
    // That invariant is also why the picker never offers "我" as an option.
    setState(() {
      final party = (
        name: picked.name,
        friendId: picked.id,
        userId: picked.userId,
        isMe: false,
      );
      if (debtorSide) {
        _debtor = party;
        _creditor = _me;
      } else {
        _creditor = party;
        _debtor = _me;
      }
    });
  }

  Future<void> _record() async {
    if (_saving) return;
    final debtor = _debtor;
    final creditor = _creditor;
    if (debtor == null || creditor == null) {
      showErrorSnakeBar('debt_need_people'.tr());
      return;
    }
    if (_same(debtor, creditor)) {
      showErrorSnakeBar('debt_same_person'.tr());
      return;
    }
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showErrorSnakeBar('expense_title_required'.tr());
      return;
    }

    // Blank is allowed and means "let them fill it in"; junk and non-positive
    // values are not.
    final int? amount;
    try {
      amount = parseOptionalAmount(_amountCtrl.text);
    } on FormatException {
      showErrorSnakeBar('expense_amount_required'.tr());
      return;
    }

    // The debt is now a proposal the other side has to answer, so it needs an
    // account to address, not just a name in my friend book.
    final other = debtor.isMe ? creditor : debtor;
    final otherUserId = other.userId;
    final myUserId = ref.read(myUserIdProvider);
    if (otherUserId == null) {
      showErrorSnakeBar('debt_friend_no_account'.tr());
      return;
    }
    if (myUserId == null) {
      showErrorSnakeBar('debt_err_generic'.tr());
      return;
    }

    setState(() => _saving = true);
    final result = await ref
        .read(debtServiceProvider)
        .propose(
          counterpartyUserId: otherUserId,
          debtorUserId: debtor.isMe ? myUserId : otherUserId,
          title: title,
          amount: amount,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Ok(value: final outcome) when outcome.isSuccess:
        setState(() {
          _debtor = null;
          _creditor = null;
          _titleCtrl.clear();
          _amountCtrl.clear();
        });
        FocusScope.of(context).unfocus();
        showMessage('debt_sent'.tr());
      case Ok(value: DebtOutcome.notFriends):
        showErrorSnakeBar(
          'debt_err_not_friends'.tr(),
          cause: DebtOutcome.notFriends,
        );
      case Ok(value: DebtOutcome.badInput):
        showErrorSnakeBar('debt_err_amount'.tr(), cause: DebtOutcome.badInput);
      // One sentence for the rest, but the console gets the real reason —
      // otherwise every distinct failure looks identical while debugging.
      case Ok(value: final outcome):
        showErrorSnakeBar('debt_err_generic'.tr(), cause: 'outcome=$outcome');
      case Error(error: final e):
        showErrorSnakeBar('debt_err_generic'.tr(), cause: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep friendsProvider warm so the picker always has the list ready, even
    // if this is the first screen (before 夥伴 has ever been opened).
    ref.watch(friendsProvider);
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.cardRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'debt_composer_title'.tr(),
            style: BrutalText.labelBold(
              fontSize: 13,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Slot(party: _debtor, onTap: () => _pick(true)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'ledger_owes'.tr(),
                  style: BrutalText.headlineLgMobile(fontSize: 18),
                ),
              ),
              Expanded(
                child: _Slot(party: _creditor, onTap: () => _pick(false)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _MiniField(
                  controller: _titleCtrl,
                  hint: 'debt_item_hint'.tr(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _MiniField(
                  controller: _amountCtrl,
                  // Blank is a real choice here, not an empty form.
                  hint: 'debt_amount_hint'.tr(),
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              PressableBrutal(
                onTap: _saving ? null : _record,
                color: BrutalColors.primaryContainer,
                radius: BrutalSpec.pillRadius,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  'debt_record'.tr(),
                  style: BrutalText.labelBold(fontSize: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A person slot in the composer — the picked party or a "選人" prompt.
class _Slot extends StatelessWidget {
  const _Slot({required this.party, required this.onTap});
  final _Party? party;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final picked = party != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: brutalDecoration(
          color: picked ? BrutalColors.primaryContainer : BrutalColors.surface,
          radius: BrutalSpec.pillRadius,
          offset: 0,
          borderWidth: BrutalSpec.borderWidthThin,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        alignment: Alignment.center,
        child: Text(
          picked ? party!.name : 'debt_pick'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BrutalText.labelBold(
            fontSize: 15,
            color: picked ? null : BrutalColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Person picker for the debt composer: your bros as avatar + name.
///
/// "我" is deliberately not an option — [_DebtComposerState._pick] always pins
/// the opposite slot to you, so offering yourself here could only produce
/// 我欠我 or 別人欠別人, neither of which the composer records.
Future<Friend?> _showPersonPickerSheet(
  BuildContext context, {
  required List<Friend> friends,
  required String? selectedFriendId,
}) {
  return showModalBottomSheet<Friend>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => BrutalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'debt_pick_person'.tr(),
            style: BrutalText.headlineLgMobile(fontSize: 22),
          ),
          const SizedBox(height: 16),
          if (friends.isEmpty)
            _EmptyHint('debt_pick_empty'.tr())
          else
            ConstrainedBox(
              // Cap the grid so a long bro list scrolls instead of shoving the
              // sheet past the top of the screen.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 14,
                  children: [
                    for (final f in friends)
                      _PersonTile(
                        friend: f,
                        selected: f.id == selectedFriendId,
                        // Friends saved before bros had to be accounts have no
                        // userId, so no device of theirs could ever receive
                        // the confirmation. Picking one would strand the debt
                        // in 確認中 forever, so it is refused up front.
                        onTap: f.userId == null
                            ? () => showErrorSnakeBar(
                                'debt_friend_no_account'.tr(),
                              )
                            : () => Navigator.of(sheetContext).pop(f),
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

/// One pickable bro: initial-in-a-box avatar over their name.
class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.friend,
    required this.selected,
    required this.onTap,
  });

  final Friend friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Accountless bros stay visible but read as unavailable — hiding them
    // would just look like the friend had vanished.
    final unavailable = friend.userId == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: unavailable ? 0.4 : 1,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection is carried by the avatar's own chrome: yellow fill, a
              // full-weight border and a lifted shadow.
              BrutalAvatar(
                name: friend.name,
                photoUrl: friend.avatarUrl,
                size: 56,
                fontSize: 24,
                color: selected
                    ? BrutalColors.primaryContainer
                    : BrutalColors.surfaceContainerHigh,
                offset: selected ? 3 : 0,
                borderWidth: selected
                    ? BrutalSpec.borderWidth
                    : BrutalSpec.borderWidthThin,
              ),
              const SizedBox(height: 7),
              Text(
                friend.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: BrutalText.labelBold(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.hint,
    this.number = false,
  });
  final TextEditingController controller;
  final String hint;
  final bool number;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surfaceContainerLow,
        radius: BrutalSpec.pillRadius,
        offset: 0,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        cursorColor: BrutalColors.onBackground,
        style: BrutalText.body(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: BrutalText.body(
            fontSize: 15,
            color: BrutalColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
