import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:heymybro/shared/pages/transaction_card.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Arguments for [FriendLedgerPage], passed via `go_router`'s `state.extra`
/// (see the typed-payload pattern in `core/routing/router.dart`).
class FriendLedgerArgs {
  const FriendLedgerArgs({required this.name, required this.friendId});

  final String name;
  final String friendId;
}

/// Friend ledger detail — reached from the "查看帳本" action on a [CirclePage]
/// friend card. Shows a comic "AI credit report" verdict and the
/// shared-transaction history (往來帳務) between you and the friend.
///
/// Static UI scaffold: the transaction rows are hardcoded sample data,
/// consistent with the rest of the app. The records use the shared
/// [TransactionGrid] / [TransactionCard], so they look and behave exactly like
/// the 私帳清單 on [TransactionPage] (tapping a card opens the same detail sheet).
class FriendLedgerPage extends StatelessWidget {
  const FriendLedgerPage({super.key, required this.args});

  final FriendLedgerArgs args;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();

    // Sample shared-ledger entries; the counterparty (this friend) is the
    // subtitle / 對象 on each card.
    final entries = <TransactionEntry>[
      TransactionEntry(
        title: 'sample_lunch'.tr(),
        subtitle: args.name,
        date: '4/3',
        amount: -350,
      ),
      TransactionEntry(
        title: 'sample_fuel'.tr(),
        subtitle: args.name,
        date: '4/2',
        amount: 600,
      ),
      TransactionEntry(
        title: 'sample_coffee'.tr(),
        subtitle: args.name,
        date: '4/1',
        amount: -120,
      ),
    ];

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const _BackButton(),
              const SizedBox(height: 16),
              // Left-aligned so the marker band hugs the name.
              Align(
                alignment: Alignment.centerLeft,
                child: MarkerHighlight(
                  child: Text(
                    args.name,
                    style: BrutalText.headlineLgMobile(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _CreditReportCard(),
              const SizedBox(height: 24),
              Text(
                'friend_ledger_transactions'.tr(),
                style: BrutalText.headlineLgMobile(fontSize: 22),
              ),
              const BrutalDivider(),
              TransactionGrid(entries: entries, money: money),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brutal back affordance — pops the pushed route back to the Circle tab.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PressableBrutal(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        onTap: () => context.pop(),
        child: const Icon(
          Icons.arrow_back,
          color: BrutalColors.onBackground,
          size: 24,
        ),
      ),
    );
  }
}

/// Comic "AI credit report" card: stamp + title label, big verdict below.
class _CreditReportCard extends StatelessWidget {
  const _CreditReportCard();

  @override
  Widget build(BuildContext context) {
    // White "report" card — black hard shadow; 粗哥 reacts on the right.
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.cardRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 粗哥 mascot sticker reacting to the verdict (left).
          Image.asset(
            'assets/mascot/stickers/05_overspent.png',
            width: 84,
            height: 84,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title — bigger than a label, but smaller than the verdict.
                Text(
                  'friend_credit_report_title'.tr(),
                  style: BrutalText.headlineLgMobile(
                    color: BrutalColors.onSurfaceVariant,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '「${'friend_credit_report_verdict'.tr()}」',
                  style: BrutalText.display(fontSize: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
