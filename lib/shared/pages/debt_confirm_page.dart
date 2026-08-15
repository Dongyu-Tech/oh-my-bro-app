import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/debt/debt_actions.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The full screen a debt proposal opens onto — who owes who, how much, for
/// what, with the answers pinned along the bottom.
///
/// A whole page rather than a sheet because this is a decision about money
/// somebody is asserting you owe. It deserves the screen, and the amount
/// deserves to be the largest thing on it.
///
/// It reads the proposal live rather than taking a copy, so if the other side
/// withdraws it while you are looking, the page says so instead of letting you
/// answer something that no longer exists.
class DebtConfirmPage extends ConsumerWidget {
  const DebtConfirmPage({required this.proposalId, super.key});

  final String proposalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
    DebtProposal? proposal;
    for (final d in all) {
      if (d.id == proposalId) proposal = d;
    }

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: proposal == null ? const _Gone() : _Body(proposal: proposal),
        ),
      ),
    );
  }
}

/// The proposal is not on this device (yet, or any more).
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [BrutalBackButton()]),
        ),
        Expanded(
          child: Center(
            child: Text(
              'debt_confirm_gone'.tr(),
              style: BrutalText.labelBold(
                fontSize: 15,
                color: BrutalColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myUserIdProvider);
    final name = proposal.otherName ?? '?';
    final iOwe = proposal.debtorId == me;
    final myTurn = proposal.status == 'pending' && proposal.awaitingId == me;
    final money = NumberFormat.decimalPattern();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              const BrutalBackButton(),
              const SizedBox(width: 12),
              Expanded(
                child: MarkerHighlight(
                  child: Text(
                    'debt_confirm_title'.tr(),
                    style: BrutalText.headlineLgMobile(fontSize: 26),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              children: [
                BrutalAvatar(
                  name: name,
                  photoUrl: proposal.otherAvatarUrl,
                  size: 84,
                  fontSize: 36,
                  offset: BrutalSpec.shadowOffsetMobile,
                  borderWidth: BrutalSpec.borderWidth,
                ),
                const SizedBox(height: 16),
                Text(
                  iOwe
                      ? 'debt_you_owe_them'.tr(namedArgs: {'name': name})
                      : 'debt_they_owe'.tr(namedArgs: {'name': name}),
                  textAlign: TextAlign.center,
                  style: BrutalText.headlineLgMobile(fontSize: 22),
                ),
                const SizedBox(height: 20),
                BrutalCard(
                  color: iOwe
                      ? BrutalColors.surface
                      : BrutalColors.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  child: Column(
                    children: [
                      Text(
                        proposal.amount == null
                            ? 'debt_amount_blank'.tr()
                            : '\$${money.format(proposal.amount)}',
                        style: BrutalText.headlineLgMobile(
                          fontSize: proposal.amount == null ? 22 : 44,
                        ),
                      ),
                      if (proposal.originalAmount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'debt_was_amount'.tr(
                            namedArgs: {
                              'amount':
                                  '\$${money.format(proposal.originalAmount)}',
                            },
                          ),
                          style: BrutalText.body(
                            fontSize: 13,
                            color: BrutalColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        proposal.title,
                        textAlign: TextAlign.center,
                        style: BrutalText.labelBold(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!myTurn)
                  Text(
                    proposal.status == 'pending'
                        ? 'debt_waiting_for'.tr(namedArgs: {'name': name})
                        : 'debt_confirm_settled'.tr(),
                    textAlign: TextAlign.center,
                    style: BrutalText.body(
                      fontSize: 13,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Pinned to the bottom rather than scrolled with the content: the
        // answer is the point of the screen and must never be below the fold.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: myTurn
              ? _MyTurnActions(proposal: proposal)
              : _TheirTurnActions(proposal: proposal),
        ),
      ],
    );
  }
}

class _MyTurnActions extends ConsumerWidget {
  const _MyTurnActions({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> run(Future<bool> Function() action) async {
      if (await action() && context.mounted) Navigator.of(context).maybePop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WideAction(
          label: 'debt_action_accept'.tr(),
          color: BrutalColors.primaryContainer,
          onTap: () => run(() => acceptDebt(context, ref, proposal)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _WideAction(
                label: 'debt_action_counter'.tr(),
                color: BrutalColors.surface,
                onTap: () => run(() => counterDebt(context, ref, proposal)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _WideAction(
                label: 'debt_action_reject'.tr(),
                color: BrutalColors.surface,
                onTap: () => run(() => rejectDebt(context, ref, proposal)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Mine, or already settled. The only thing left is to take it back — and
/// only while it is still unanswered.
class _TheirTurnActions extends ConsumerWidget {
  const _TheirTurnActions({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (proposal.status != 'pending') return const SizedBox.shrink();

    return _WideAction(
      label: 'debt_action_cancel'.tr(),
      color: BrutalColors.surface,
      onTap: () async {
        if (await cancelDebt(context, ref, proposal) && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}

class _WideAction extends StatelessWidget {
  const _WideAction({
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
      width: double.infinity,
      restOffset: BrutalSpec.shadowOffsetMobile,
      pressedOffset: BrutalSpec.shadowOffsetPressed,
      padding: const EdgeInsets.symmetric(vertical: 15),
      alignment: Alignment.center,
      child: Text(label, style: BrutalText.headlineLgMobile(fontSize: 18)),
    );
  }
}
