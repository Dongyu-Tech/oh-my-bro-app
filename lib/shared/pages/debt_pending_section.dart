import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/debt/debt_actions.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The 待確認 block in 帳本: debts that have been logged but not yet agreed.
///
/// Nothing here is counted in any balance, and that needs no code to enforce —
/// the arithmetic only ever sees debts that have been projected into a group,
/// and a proposal is projected the moment it is confirmed and not before. The
/// same is true of credit scores, which matters: if unconfirmed debts counted,
/// anyone could log ten of them and wreck someone's score.
class DebtPendingSection extends ConsumerWidget {
  const DebtPendingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deliberately does NOT start the sync. DebtPopupHost owns that, mounted
    // above the router so a proposal arrives whichever tab you are on — 帳本
    // is only one of four, and the popup cannot depend on you standing here.
    final mine = ref.watch(pendingForMeProvider);
    final theirs = ref.watch(pendingForThemProvider);
    final deadEnds = ref.watch(unseenDeadEndsProvider);

    if (mine.isEmpty && theirs.isEmpty && deadEnds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: BrutalCard(
        color: BrutalColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.hourglass, size: 16),
                const SizedBox(width: 6),
                Text(
                  'debt_pending_title'.tr(),
                  style: BrutalText.labelBold(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'debt_pending_note'.tr(),
              style: BrutalText.body(
                fontSize: 12,
                color: BrutalColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final d in mine) _MyTurnCard(proposal: d),
            for (final d in theirs) _TheirTurnCard(proposal: d),
            for (final d in deadEnds) _DeadEndCard(proposal: d),
          ],
        ),
      ),
    );
  }
}

/// "阿華 欠你 $500" / "你欠 阿華 $500", plus what it used to say if countered.
class DebtProposalLine extends ConsumerWidget {
  const DebtProposalLine({required this.proposal, super.key});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myUserIdProvider);
    final name = proposal.otherName ?? '?';
    final iOwe = proposal.debtorId == me;
    final money = NumberFormat.decimalPattern();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrutalAvatar(
          name: name,
          photoUrl: proposal.otherAvatarUrl,
          size: 34,
          fontSize: 15,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                iOwe
                    ? 'debt_you_owe_them'.tr(namedArgs: {'name': name})
                    : 'debt_they_owe'.tr(namedArgs: {'name': name}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BrutalText.labelBold(fontSize: 14),
              ),
              Text(
                proposal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BrutalText.body(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              proposal.amount == null
                  ? 'debt_amount_blank'.tr()
                  : '\$${money.format(proposal.amount)}',
              style: BrutalText.labelBold(
                fontSize: proposal.amount == null ? 11 : 16,
                color: proposal.amount == null
                    ? BrutalColors.onSurfaceVariant
                    : null,
              ),
            ),
            if (proposal.originalAmount != null)
              Text(
                'debt_was_amount'.tr(
                  namedArgs: {
                    'amount': '\$${money.format(proposal.originalAmount)}',
                  },
                ),
                style: BrutalText.body(
                  fontSize: 11,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Wraps one proposal in the shared card chrome.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: brutalDecoration(
          color: color ?? BrutalColors.surfaceContainerLow,
          radius: BrutalSpec.cardRadius,
          offset: 0,
          borderWidth: BrutalSpec.borderWidthThin,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: child,
      ),
    );
  }
}

/// Waiting on me: accept outright, reject with a reason, or counter the
/// amount.
class _MyTurnCard extends ConsumerWidget {
  const _MyTurnCard({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProposalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tapping the summary opens the same full page the arrival popup
          // shows, so there is one place a debt is decided, not two.
          GestureDetector(
            onTap: () => context.push('/debt/${proposal.id}'),
            behavior: HitTestBehavior.opaque,
            child: DebtProposalLine(proposal: proposal),
          ),
          const SizedBox(height: 10),
          DebtActionRow(proposal: proposal),
        ],
      ),
    );
  }
}

/// The accept / reject / change buttons, in their compact in-card form. The
/// full-screen confirm page has its own larger layout but calls the very same
/// action functions, so the two can never disagree about what a button does.
class DebtActionRow extends ConsumerWidget {
  const DebtActionRow({required this.proposal, super.key});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _SmallButton(
            label: 'debt_action_accept'.tr(),
            color: BrutalColors.primaryContainer,
            onTap: () => acceptDebt(context, ref, proposal),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallButton(
            label: 'debt_action_reject'.tr(),
            color: BrutalColors.surface,
            onTap: () => rejectDebt(context, ref, proposal),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallButton(
            label: 'debt_action_counter'.tr(),
            color: BrutalColors.surface,
            onTap: () => counterDebt(context, ref, proposal),
          ),
        ),
      ],
    );
  }
}

/// Sent by me, waiting on them. Nothing to answer, but I can take it back.
class _TheirTurnCard extends ConsumerWidget {
  const _TheirTurnCard({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProposalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DebtProposalLine(proposal: proposal),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'debt_waiting_for'.tr(
                    namedArgs: {'name': proposal.otherName ?? '?'},
                  ),
                  style: BrutalText.body(
                    fontSize: 12,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
              ),
              _SmallButton(
                label: 'debt_action_cancel'.tr(),
                color: BrutalColors.surface,
                onTap: () => cancelDebt(context, ref, proposal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rejected, withdrawn or voided, and not yet acknowledged.
class _DeadEndCard extends ConsumerWidget {
  const _DeadEndCard({required this.proposal});

  final DebtProposal proposal;

  String get _label => switch (proposal.status) {
    'rejected' =>
      (proposal.rejectReason?.trim().isNotEmpty ?? false)
          ? 'debt_state_rejected'.tr(
              namedArgs: {'reason': proposal.rejectReason!.trim()},
            )
          : 'debt_state_rejected_bare'.tr(),
    'cancelled' => 'debt_state_cancelled'.tr(),
    _ => 'debt_state_void'.tr(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProposalCard(
      color: BrutalColors.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DebtProposalLine(proposal: proposal),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _label,
                  style: BrutalText.labelBold(
                    fontSize: 12,
                    color: BrutalColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: 'debt_action_dismiss'.tr(),
                color: BrutalColors.surface,
                onTap: () =>
                    ref.read(debtServiceProvider).markDismissed(proposal.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      onTap: onTap,
      color: color,
      radius: BrutalSpec.pillRadius,
      borderWidth: BrutalSpec.borderWidthThin,
      restOffset: 2,
      pressedOffset: 0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BrutalText.labelBold(fontSize: 13),
      ),
    );
  }
}
