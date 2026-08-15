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
/// Built as a claim slip rather than a form: a yellow header band naming who
/// is asking, a hard rule under it (DESIGN.md — "Header: often separated by a
/// horizontal black line"), then the amount as the largest thing on the
/// screen. Somebody is asserting you owe them money; the number is the
/// decision, so the number gets the space.
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Column(
              children: [
                _ClaimSlip(proposal: proposal, iOwe: iOwe),
                if (!myTurn) ...[
                  const SizedBox(height: 18),
                  Text(
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
                ],
              ],
            ),
          ),
        ),
        // Pinned to the bottom edge rather than scrolled with the content: the
        // answer is the point of the screen and must never be below the fold.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: myTurn
              ? _MyTurnActions(proposal: proposal)
              : _TheirTurnActions(proposal: proposal),
        ),
      ],
    );
  }
}

/// The claim itself: who is asking (yellow band), a hard rule, then the money.
class _ClaimSlip extends StatelessWidget {
  const _ClaimSlip({required this.proposal, required this.iOwe});

  final DebtProposal proposal;
  final bool iOwe;

  @override
  Widget build(BuildContext context) {
    final name = proposal.otherName ?? '?';
    final money = NumberFormat.decimalPattern();
    final blank = proposal.amount == null;

    // Semantic per DESIGN.md: red carries a liability, deep gold carries money
    // coming back to you. The one glance at this screen should already say
    // which way it goes.
    final amountColor = iOwe ? BrutalColors.secondary : BrutalColors.incomeInk;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          // Room for the sticker to sit over the top edge.
          padding: const EdgeInsets.only(top: 40),
          child: Container(
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: 16, // large radius — a major container (DESIGN.md)
              offset: BrutalSpec.shadowOffset,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Claimant(name: name, iOwe: iOwe, proposal: proposal),
                Container(
                  height: BrutalSpec.borderWidth,
                  color: BrutalColors.onBackground,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                  child: Column(
                    children: [
                      Text(
                        blank
                            ? 'debt_amount_blank'.tr()
                            : '\$${money.format(proposal.amount)}',
                        textAlign: TextAlign.center,
                        style: BrutalText.headlineLgMobile(
                          fontSize: blank ? 20 : 52,
                          color: blank
                              ? BrutalColors.onSurfaceVariant
                              : amountColor,
                        ),
                      ),
                      if (proposal.originalAmount != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'debt_was_amount'.tr(
                            namedArgs: {
                              'amount':
                                  '\$${money.format(proposal.originalAmount)}',
                            },
                          ),
                          // Struck through so "they changed it" reads without
                          // needing the label to say so.
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
                      const SizedBox(height: 18),
                      BrutalPill(
                        color: BrutalColors.surfaceContainerHigh,
                        borderWidth: BrutalSpec.borderWidthThin,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
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
              height: 92,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

/// Yellow header band: their face, their name, and what they are claiming.
class _Claimant extends StatelessWidget {
  const _Claimant({
    required this.name,
    required this.iOwe,
    required this.proposal,
  });

  final String name;
  final bool iOwe;
  final DebtProposal proposal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BrutalColors.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          BrutalAvatar(
            name: name,
            photoUrl: proposal.otherAvatarUrl,
            size: 46,
            fontSize: 20,
            color: BrutalColors.surface,
            borderWidth: BrutalSpec.borderWidth,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.headlineLgMobile(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  // The name is right above, so the sentence does not repeat
                  // it — "阿華 / 說你欠他" reads as one line, not two.
                  iOwe ? 'debt_claim_you_owe'.tr() : 'debt_claim_owes_you'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.labelBold(
                    fontSize: 13,
                    color: BrutalColors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          // Leaves room for the sticker overlapping this corner.
          const SizedBox(width: 64),
        ],
      ),
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
