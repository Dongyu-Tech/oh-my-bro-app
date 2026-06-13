import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/pages/friend_ledger_page.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// "夥伴 / Circle" tab — find a friend by ID to settle shared debts.
///
/// Static UI scaffold: the field is editable but the search action is not yet
/// wired to a backend (the button just surfaces a "coming soon" message).
class CirclePage extends StatelessWidget {
  const CirclePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkerHighlight(
                  child: Text(
                    'circle_title'.tr(),
                    style: BrutalText.headlineLgMobile(fontSize: 30),
                  ),
                ),
                const SizedBox(height: 28),
                const Row(
                  children: [
                    Expanded(child: _CircleSearchField()),
                    SizedBox(width: 12),
                    _CircleSearchButton(),
                  ],
                ),
                const SizedBox(height: 24),
                // Sample result — a friend who owes you money (red amount).
                const _FriendDebtCard(
                  name: '阿傑',
                  friendId: 'ajie_888',
                  amount: 800,
                  theyOweYou: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared height so the search field and the search button line up exactly.
const double _kSearchBarHeight = 56;

/// Bordered brutal box holding a magnifier + the "friend ID" text field.
class _CircleSearchField extends StatelessWidget {
  const _CircleSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kSearchBarHeight,
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 22,
            color: BrutalColors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              cursorColor: BrutalColors.onBackground,
              style: BrutalText.body(fontSize: 16),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'circle_search_hint'.tr(),
                hintStyle: BrutalText.body(
                  fontSize: 16,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow press-animated button. Sized to its label (one line) so it stays
/// tidy in both 中文 ("搜尋") and English ("Search").
class _CircleSearchButton extends StatelessWidget {
  const _CircleSearchButton();

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      onTap: comingSoon,
      color: BrutalColors.primaryContainer,
      radius: BrutalSpec.pillRadius,
      height: _kSearchBarHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        'circle_search_button'.tr(),
        maxLines: 1,
        style: BrutalText.labelBold(fontSize: 16),
      ),
    );
  }
}

/// Friend result card — redesigned per DESIGN.md (Rough Comic Neo-Brutalism),
/// rendered in the app's light palette. Shows who they are, an ELITE corner
/// badge, the outstanding amount, and a "View Ledger" action. The notify
/// button from the reference is intentionally omitted, and the avatar is a
/// loading skeleton.
///
/// [theyOweYou] drives both the wording and the amount colour:
///   • true  → they owe you  → red  ("+")
///   • false → you owe them  → black ("-")
class _FriendDebtCard extends StatelessWidget {
  const _FriendDebtCard({
    required this.name,
    required this.friendId,
    required this.amount,
    required this.theyOweYou,
  });

  final String name;
  final String friendId;
  final int amount;
  final bool theyOweYou;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    final amountColor =
        theyOweYou ? BrutalColors.secondary : BrutalColors.onBackground;
    final sign = theyOweYou ? '+' : '-';
    final label =
        (theyOweYou ? 'circle_card_owes_you' : 'circle_card_you_owe').tr();

    return BrutalCard(
      color: BrutalColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: skeleton avatar + name/id, ELITE badge in the top-right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrutalSkeleton(
                width: 56,
                height: 56,
                shape: BoxShape.circle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: BrutalText.headlineLgMobile(fontSize: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $friendId',
                      style: BrutalText.labelBold(
                        color: BrutalColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _EliteTag(),
            ],
          ),
          const SizedBox(height: 16),
          // Amount panel (white inner card).
          Container(
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: BrutalSpec.cardRadius,
              offset: 3,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: BrutalText.labelBold(
                    color: BrutalColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$sign\$${money.format(amount)}',
                  style: BrutalText.display(color: amountColor, fontSize: 34),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // View Ledger — full width (notify button omitted by request).
          PressableBrutal(
            onTap: () => context.push(
              '/circle/ledger',
              extra: FriendLedgerArgs(name: name, friendId: friendId),
            ),
            color: BrutalColors.primaryContainer,
            radius: BrutalSpec.pillRadius,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long,
                  size: 20,
                  color: BrutalColors.onBackground,
                ),
                const SizedBox(width: 8),
                Text(
                  'circle_view_ledger'.tr(),
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

/// Top-right comic "sticker" badge (dark stamp, yellow text).
class _EliteTag extends StatelessWidget {
  const _EliteTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.onBackground,
        radius: BrutalSpec.pillRadius,
        offset: 2,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        'circle_tag'.tr(),
        style: BrutalText.labelBold(
          color: BrutalColors.primaryContainer,
          fontSize: 12,
        ),
      ),
    );
  }
}
