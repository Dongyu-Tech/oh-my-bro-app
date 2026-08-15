import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/debt/debt_actions.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The screen a debt proposal opens onto — who is claiming what, and the
/// answers along the bottom edge.
///
/// Built as a claim slip rather than a form: the claim is a marker-highlighted
/// caption at the top left with the claimant named under it, and the amount
/// sits in the optical centre of the screen. Somebody is asserting you owe
/// them money; the number is the decision, so the number gets the middle.
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [BrutalBackButton()]),
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
    final iOwe = proposal.debtorId == me;
    final myTurn = proposal.status == 'pending' && proposal.awaitingId == me;

    return Column(
      children: [
        // Expanded, not scrolled: the slip fills the space between the back
        // button and the answers, which is what puts the amount on the screen's
        // centre line rather than wherever the content happens to end.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: _ClaimSlip(proposal: proposal, iOwe: iOwe),
          ),
        ),
        if (!myTurn)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Text(
              proposal.status == 'pending'
                  ? 'debt_waiting_for'.tr(
                      namedArgs: {'name': proposal.otherName ?? '?'},
                    )
                  : 'debt_confirm_settled'.tr(),
              textAlign: TextAlign.center,
              style: BrutalText.labelBold(
                fontSize: 13,
                color: BrutalColors.onSurfaceVariant,
              ),
            ),
          ),
        // Pinned to the bottom edge rather than scrolled with the content: the
        // answer is the point of the screen and must never be below the fold.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: myTurn
              ? _MyTurnActions(proposal: proposal)
              : _TheirTurnActions(proposal: proposal),
        ),
      ],
    );
  }
}

/// The slip: claim top-left, money in the middle, 粗哥 leaning over the corner.
class _ClaimSlip extends StatelessWidget {
  const _ClaimSlip({required this.proposal, required this.iOwe});

  final DebtProposal proposal;
  final bool iOwe;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // expand so the card fills the height it was given — the amount can only
      // land on the centre line if the card knows how tall it is.
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Padding(
          // Room for the sticker to lean over the top edge.
          padding: const EdgeInsets.only(top: 34),
          child: Container(
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: 16, // large radius — a major container (DESIGN.md)
              offset: BrutalSpec.shadowOffset,
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Claimant(proposal: proposal, iOwe: iOwe),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: _Amount(proposal: proposal, iOwe: iOwe),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 4,
          child: Transform.rotate(
            angle: 0.12,
            child: Image.asset(
              iOwe
                  ? 'assets/mascot/stickers/07_weird-bill.png'
                  : 'assets/mascot/stickers/04_money-manage.png',
              height: 88,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

/// The claim, then who is making it — left-aligned, marker-highlighted, the
/// same comic-caption treatment every other screen title in the app gets.
class _Claimant extends StatelessWidget {
  const _Claimant({required this.proposal, required this.iOwe});

  final DebtProposal proposal;
  final bool iOwe;

  @override
  Widget build(BuildContext context) {
    final name = proposal.otherName ?? '?';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: MarkerHighlight(
            child: Text(
              iOwe ? 'debt_claim_you_owe'.tr() : 'debt_claim_owes_you'.tr(),
              style: BrutalText.headlineLgMobile(fontSize: 22),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            BrutalAvatar(
              name: name,
              photoUrl: proposal.otherAvatarUrl,
              size: 40,
              fontSize: 18,
              color: BrutalColors.surfaceContainerHigh,
              borderWidth: BrutalSpec.borderWidthThin,
            ),
            const SizedBox(width: 10),
            Flexible(
              // Corner brackets mark this as the speaker of the line above,
              // rather than a second heading competing with it.
              child: Text(
                '「$name」',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BrutalText.headlineLgMobile(fontSize: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The number, its sign, and what it was for.
class _Amount extends StatelessWidget {
  const _Amount({required this.proposal, required this.iOwe});

  final DebtProposal proposal;
  final bool iOwe;

  /// Money leaving you is signed and red; money coming back is green.
  ///
  /// The sign matters beyond decoration: it is the part that survives a
  /// greyscale screenshot or a red-green colour blindness, so the direction is
  /// never carried by the colour alone.
  String _money(int value) {
    final formatted = NumberFormat.decimalPattern().format(value);
    return iOwe ? '-\$$formatted' : '\$$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final amount = proposal.amount;
    final original = proposal.originalAmount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amount == null ? 'debt_amount_blank'.tr() : _money(amount),
          textAlign: TextAlign.center,
          style: BrutalText.headlineLgMobile(
            fontSize: amount == null ? 20 : 52,
            color: amount == null
                ? BrutalColors.onSurfaceVariant
                : (iOwe ? BrutalColors.secondary : BrutalColors.incomeGreen),
          ),
        ),
        if (original != null) ...[
          const SizedBox(height: 6),
          Text(
            'debt_was_amount'.tr(namedArgs: {'amount': _money(original)}),
            // Struck through, so "they changed it" reads without a label
            // spending a whole sentence saying so.
            style:
                BrutalText.body(
                  fontSize: 13,
                  color: BrutalColors.onSurfaceVariant,
                ).copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationColor: BrutalColors.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 20),
        BrutalPill(
          color: BrutalColors.surfaceContainerHigh,
          borderWidth: BrutalSpec.borderWidthThin,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.receipt, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  proposal.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: BrutalText.labelBold(fontSize: 15),
                ),
              ),
            ],
          ),
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
        _Action(
          label: 'debt_action_accept'.tr(),
          icon: LucideIcons.check,
          color: BrutalColors.primaryContainer,
          big: true,
          onTap: () => run(() => acceptDebt(context, ref, proposal)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Action(
                label: 'debt_action_counter'.tr(),
                icon: LucideIcons.pencil,
                color: BrutalColors.surface,
                onTap: () => run(() => counterDebt(context, ref, proposal)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Action(
                label: 'debt_action_reject'.tr(),
                icon: LucideIcons.x,
                color: BrutalColors.surface,
                // Red marks the destructive one (DESIGN.md), so it cannot be
                // mistaken for the neutral "change the number" beside it.
                ink: BrutalColors.secondary,
                onTap: () => run(() => rejectDebt(context, ref, proposal)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Mine, or already settled. The only thing left is to take it back — and only
/// while it is still unanswered.
class _TheirTurnActions extends ConsumerWidget {
  const _TheirTurnActions({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (proposal.status != 'pending') return const SizedBox.shrink();

    return _Action(
      label: 'debt_action_cancel'.tr(),
      icon: LucideIcons.undo2,
      color: BrutalColors.surface,
      ink: BrutalColors.secondary,
      onTap: () async {
        if (await cancelDebt(context, ref, proposal) && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.ink,
    this.big = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Text/icon colour — carries the semantic, since the border is always ink.
  final Color? ink;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final foreground = ink ?? BrutalColors.onBackground;
    return PressableBrutal(
      onTap: onTap,
      color: color,
      radius: BrutalSpec.pillRadius,
      width: double.infinity,
      restOffset: BrutalSpec.shadowOffsetMobile,
      pressedOffset: BrutalSpec.shadowOffsetPressed,
      padding: EdgeInsets.symmetric(vertical: big ? 17 : 14),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: big ? 22 : 18, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BrutalText.headlineLgMobile(
                fontSize: big ? 20 : 16,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
