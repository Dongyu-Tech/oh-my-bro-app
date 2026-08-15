import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/debt/debt_actions.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';
import 'package:heymybro/shared/widgets/confirm_dialog.dart';
import 'package:heymybro/shared/widgets/debt_slip.dart';

/// The screen a proposal opens onto — a debt or a repayment, since both are
/// somebody asserting something about money and waiting for you to agree.
///
/// The two share their chrome ([DebtSlipCard]) and differ only where they
/// should: what the body states, and what answers the bottom offers. A debt
/// can be haggled over; a repayment cannot, because either the money arrived
/// or it did not.
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    const BrutalBackButton(),
                    const Spacer(),
                    // Withdrawing lives here, in the same top-right slot every
                    // other detail screen puts "get rid of this" — rather than
                    // as a button competing with the answers at the bottom.
                    // Only the proposer can take one back.
                    if (proposal != null &&
                        proposal.status == 'pending' &&
                        proposal.proposerId == ref.watch(myUserIdProvider))
                      _WithdrawButton(proposal: proposal),
                  ],
                ),
              ),
              Expanded(
                child: proposal == null
                    ? const _Gone()
                    : _Body(proposal: proposal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The proposal is not on this device — withdrawn, or the sync has not caught
/// up with a link that was opened early.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/mascot/stickers/02_thinking.png',
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            'debt_confirm_gone'.tr(),
            style: BrutalText.labelBold(
              fontSize: 15,
              color: BrutalColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myUserIdProvider);
    final repayment = proposal.kind == 'repayment';
    final iOwe = proposal.debtorId == me;
    final myTurn = proposal.status == 'pending' && proposal.awaitingId == me;
    final name = proposal.otherName ?? '?';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DebtScreenTitle(
                  title: repayment
                      ? 'debt_repay_title'.tr()
                      : (iOwe
                            ? 'debt_claim_you_owe'.tr()
                            : 'debt_claim_owes_you'.tr()),
                  subtitle: repayment
                      ? 'debt_repay_subtitle'.tr()
                      : 'debt_confirm_subtitle'.tr(),
                ),
                const SizedBox(height: 18),
                if (repayment)
                  _RepaymentSlip(proposal: proposal, name: name, iPaid: iOwe)
                else
                  _DebtSlip(proposal: proposal, name: name, iOwe: iOwe),
                if (!myTurn) ...[
                  const SizedBox(height: 18),
                  Text(
                    proposal.status == 'pending'
                        ? 'debt_waiting_for'.tr(namedArgs: {'name': name})
                        : 'debt_confirm_settled'.tr(),
                    textAlign: TextAlign.center,
                    style: BrutalText.labelBold(
                      fontSize: 13,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Pinned to the bottom edge rather than scrolled with the content: the
        // answer is the point of the screen and must never be below the fold.
        // Nothing down here when it is not your turn — withdrawing moved to
        // the top-right, where every other screen keeps "get rid of this".
        if (myTurn)
          _Answers(proposal: proposal, iOwe: iOwe, repayment: repayment)
        else
          const SizedBox(height: 16),
      ],
    );
  }
}

/// A debt: the item, then the figure being claimed.
class _DebtSlip extends StatelessWidget {
  const _DebtSlip({
    required this.proposal,
    required this.name,
    required this.iOwe,
  });

  final DebtProposal proposal;
  final String name;
  final bool iOwe;

  @override
  Widget build(BuildContext context) {
    final blank = proposal.amount == null;
    return DebtSlipCard(
      name: name,
      avatarUrl: proposal.otherAvatarUrl,
      // The short form, not the headline's sentence — the page title already
      // says "說你欠他" at 40px, and repeating it under the avatar is the same
      // claim twice on one screen.
      claim: iOwe ? 'debt_badge_you_owe'.tr() : 'debt_badge_owes_you'.tr(),
      sticker: iOwe
          ? 'assets/mascot/stickers/07_weird-bill.png'
          : 'assets/mascot/stickers/01_main-pointing.png',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DebtSlipField(
            label: 'debt_field_item'.tr(),
            value: proposal.title,
            icon: LucideIcons.receipt,
          ),
          const BrutalDivider(
            thickness: BrutalSpec.borderWidthThin,
            margin: EdgeInsets.symmetric(vertical: 16),
          ),
          DebtSlipField(
            label: 'debt_field_amount'.tr(),
            value: blank
                ? 'debt_amount_blank'.tr()
                : debtMoney(proposal.amount!),
            valueSize: blank ? 22 : 76,
            valueColor: blank ? BrutalColors.onSurfaceVariant : null,
            underline: !blank,
            note: proposal.originalAmount == null
                ? null
                : 'debt_was_amount'.tr(
                    namedArgs: {'amount': debtMoney(proposal.originalAmount!)},
                  ),
          ),
        ],
      ),
    );
  }
}

/// A repayment: how much was paid, and what that leaves.
///
/// The extra line is the point of this screen. "阿華 還你 300" alone is not
/// enough to agree to — whether that clears the debt or leaves 200 behind is
/// exactly what the person confirming needs to know.
class _RepaymentSlip extends StatelessWidget {
  const _RepaymentSlip({
    required this.proposal,
    required this.name,
    required this.iPaid,
  });

  final DebtProposal proposal;
  final String name;
  final bool iPaid;

  @override
  Widget build(BuildContext context) {
    final paid = proposal.amount ?? 0;
    // The debt's remaining balance, as it stood when this was proposed.
    final before = proposal.outstanding;
    final after = before == null ? null : before - paid;

    return DebtSlipCard(
      name: name,
      avatarUrl: proposal.otherAvatarUrl,
      claim: iPaid ? 'debt_repay_claim_mine'.tr() : 'debt_repay_claim'.tr(),
      badge: 'debt_repay_badge'.tr(),
      badgeColor: BrutalColors.primaryFixedDim,
      sticker: 'assets/mascot/stickers/03_success.png',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DebtSlipField(
            label: 'debt_field_item'.tr(),
            value: proposal.title,
            icon: LucideIcons.receipt,
          ),
          const BrutalDivider(
            thickness: BrutalSpec.borderWidthThin,
            margin: EdgeInsets.symmetric(vertical: 16),
          ),
          DebtSlipField(
            label: 'debt_field_repaid'.tr(),
            value: debtMoney(paid),
            valueSize: 76,
            valueColor: BrutalColors.incomeInk,
            underline: true,
            note: after == null
                ? null
                : (after <= 0
                      ? 'debt_repay_clears'.tr()
                      : 'debt_repay_leaves'.tr(
                          namedArgs: {'amount': debtMoney(after)},
                        )),
          ),
        ],
      ),
    );
  }
}

/// A debt offers three answers, a repayment two: there is nothing to haggle
/// over about whether money arrived.
class _Answers extends ConsumerWidget {
  const _Answers({
    required this.proposal,
    required this.iOwe,
    required this.repayment,
  });

  final DebtProposal proposal;
  final bool iOwe;
  final bool repayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Grabbed BEFORE the await. Answering flips whose turn it is, which swaps
    // this widget out, so `context` can be unmounted by the time the action
    // returns — and a `context.mounted` guard would then silently skip the
    // close.
    final navigator = Navigator.of(context);
    Future<void> run(Future<bool> Function() action) async {
      if (await action()) await navigator.maybePop();
    }

    final amount = proposal.amount;
    final name = proposal.otherName ?? '?';

    final String label;
    if (repayment) {
      label = 'debt_repay_accept'.tr(
        namedArgs: {'amount': debtMoney(amount ?? 0)},
      );
    } else if (amount == null) {
      label = 'debt_accept_blank'.tr();
    } else {
      final args = {'name': name, 'amount': debtMoney(amount)};
      label = iOwe
          ? 'debt_accept_owing'.tr(namedArgs: args)
          : 'debt_accept_owed'.tr(namedArgs: args);
    }

    return DebtActionBar(
      primaryLabel: label,
      note: 'debt_notify_note'.tr(),
      onPrimary: () => run(() => acceptDebt(context, ref, proposal)),
      secondaries: [
        if (!repayment)
          DebtTextAction(
            label: 'debt_action_counter'.tr(),
            icon: LucideIcons.pencil,
            onTap: () => run(() => counterDebt(context, ref, proposal)),
          ),
        DebtTextAction(
          label: 'debt_action_reject'.tr(),
          icon: LucideIcons.x,
          // Red marks the destructive one (DESIGN.md) so it cannot be
          // mistaken for the neutral option beside it.
          ink: BrutalColors.secondary,
          onTap: () => run(() => rejectDebt(context, ref, proposal)),
        ),
      ],
    );
  }
}

class _WithdrawButton extends ConsumerWidget {
  const _WithdrawButton({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same reason as _Answers: withdrawing rebuilds this away.
    final navigator = Navigator.of(context);

    return PressableBrutal(
      onTap: () async {
        // Confirmed first: this is the one control here that destroys
        // something, and it now sits where a mis-tap is easy.
        final ok = await confirmDialog(
          context,
          title: 'debt_cancel_title'.tr(),
          message: 'debt_cancel_message'.tr(),
          confirmLabel: 'debt_action_cancel'.tr(),
          danger: true,
        );
        if (!ok || !context.mounted) return;
        if (await cancelDebt(context, ref, proposal)) {
          await navigator.maybePop();
        }
      },
      color: BrutalColors.surface,
      radius: BrutalSpec.pillRadius,
      padding: const EdgeInsets.all(9),
      child: const Icon(
        LucideIcons.trash2,
        size: 20,
        color: BrutalColors.secondary,
      ),
    );
  }
}
