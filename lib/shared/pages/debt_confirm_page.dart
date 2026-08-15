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
/// Laid out as a claim slip: a headline stating the direction, then a card
/// whose yellow band names the claimant and whose body carries the two facts
/// that matter, 項目 and 金額, with the amount by far the largest thing on the
/// screen. Somebody is asserting money changed hands; the number is the
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  iOwe ? 'debt_claim_you_owe'.tr() : 'debt_claim_owes_you'.tr(),
                  style: BrutalText.headlineLgMobile(fontSize: 40),
                ),
                const SizedBox(height: 6),
                Text(
                  'debt_confirm_subtitle'.tr(),
                  style: BrutalText.body(
                    fontSize: 15,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
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
        if (myTurn)
          _MyTurnActions(proposal: proposal, iOwe: iOwe)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: _TheirTurnActions(proposal: proposal),
          ),
      ],
    );
  }
}

/// The claim: a yellow band naming who is asking, then the two facts.
class _ClaimSlip extends StatelessWidget {
  const _ClaimSlip({required this.proposal, required this.iOwe});

  final DebtProposal proposal;
  final bool iOwe;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    final blank = proposal.amount == null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          // Room for 粗哥 to lean over the top edge.
          padding: const EdgeInsets.only(top: 30),
          child: Container(
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: 20,
              offset: BrutalSpec.shadowOffset,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Claimant(proposal: proposal, iOwe: iOwe),
                const BrutalDivider(margin: EdgeInsets.zero),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FieldLabel('debt_field_item'.tr()),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('🧾', style: TextStyle(fontSize: 30)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              proposal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BrutalText.headlineLgMobile(fontSize: 34),
                            ),
                          ),
                        ],
                      ),
                      const BrutalDivider(
                        thickness: BrutalSpec.borderWidthThin,
                        margin: EdgeInsets.symmetric(vertical: 16),
                      ),
                      _FieldLabel('debt_field_amount'.tr()),
                      const SizedBox(height: 6),
                      if (blank)
                        Text(
                          'debt_amount_blank'.tr(),
                          style: BrutalText.headlineLgMobile(
                            fontSize: 22,
                            color: BrutalColors.onSurfaceVariant,
                          ),
                        )
                      else
                        MarkerHighlight(
                          // A low band reads as a marker stroke UNDER the
                          // digits rather than a highlight across them.
                          heightFactor: 0.18,
                          padding: const EdgeInsets.only(right: 12, bottom: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '\$${money.format(proposal.amount)}',
                              maxLines: 1,
                              style: BrutalText.headlineLgMobile(fontSize: 76),
                            ),
                          ),
                        ),
                      if (proposal.originalAmount != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'debt_was_amount'.tr(
                            namedArgs: {
                              'amount':
                                  '\$${money.format(proposal.originalAmount)}',
                            },
                          ),
                          // Struck through so "they changed it" reads without
                          // spending a sentence saying so.
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Image.asset(
            iOwe
                ? 'assets/mascot/stickers/07_weird-bill.png'
                : 'assets/mascot/stickers/01_main-pointing.png',
            height: 104,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

/// Yellow header band: their face, their name, and a badge for the direction.
class _Claimant extends StatelessWidget {
  const _Claimant({required this.proposal, required this.iOwe});

  final DebtProposal proposal;
  final bool iOwe;

  @override
  Widget build(BuildContext context) {
    final name = proposal.otherName ?? '?';

    return Container(
      color: BrutalColors.primaryContainer,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          BrutalAvatar(
            name: name,
            photoUrl: proposal.otherAvatarUrl,
            size: 58,
            fontSize: 26,
            color: BrutalColors.onBackground,
            radius: 14,
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
                  style: BrutalText.headlineLgMobile(fontSize: 22),
                ),
                const SizedBox(height: 6),
                BrutalPill(
                  color: BrutalColors.secondary,
                  borderWidth: BrutalSpec.borderWidthThin,
                  radius: 6,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    iOwe
                        ? 'debt_badge_you_owe'.tr()
                        : 'debt_badge_owes_you'.tr(),
                    style: BrutalText.labelBold(
                      fontSize: 13,
                      color: BrutalColors.onError,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Keeps the name clear of 粗哥, who overlaps this corner.
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: BrutalText.labelBold(fontSize: 14)),
  );
}

/// Waiting on me. The confirmation is a full sentence naming the person and
/// the sum, so nobody taps it without having read what they are agreeing to;
/// the two ways out sit below it as plain text, deliberately quieter.
class _MyTurnActions extends ConsumerWidget {
  const _MyTurnActions({required this.proposal, required this.iOwe});

  final DebtProposal proposal;
  final bool iOwe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.decimalPattern();
    final amount = proposal.amount;
    final name = proposal.otherName ?? '?';

    final String label;
    if (amount == null) {
      label = 'debt_accept_blank'.tr();
    } else {
      final args = {'name': name, 'amount': '\$${money.format(amount)}'};
      label = iOwe
          ? 'debt_accept_owing'.tr(namedArgs: args)
          : 'debt_accept_owed'.tr(namedArgs: args);
    }

    Future<void> run(Future<bool> Function() action) async {
      if (await action() && context.mounted) Navigator.of(context).maybePop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: BrutalCard(
            color: BrutalColors.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: BrutalDivider(
                        thickness: BrutalSpec.borderWidthThin,
                        margin: EdgeInsets.only(right: 10),
                      ),
                    ),
                    const Text('📢', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                      'debt_notify_note'.tr(),
                      style: BrutalText.labelBold(fontSize: 13),
                    ),
                    const Expanded(
                      child: BrutalDivider(
                        thickness: BrutalSpec.borderWidthThin,
                        margin: EdgeInsets.only(left: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PressableBrutal(
                  onTap: () => run(() => acceptDebt(context, ref, proposal)),
                  color: BrutalColors.primaryContainer,
                  radius: BrutalSpec.pillRadius,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.check, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BrutalText.headlineLgMobile(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flexible so a longer localisation ("Change amount") shrinks
              // instead of shoving the pair off the edge of a narrow screen.
              Flexible(
                child: _TextAction(
                  label: 'debt_action_counter'.tr(),
                  icon: LucideIcons.pencil,
                  onTap: () => run(() => counterDebt(context, ref, proposal)),
                ),
              ),
              Container(
                width: BrutalSpec.borderWidthThin,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: BrutalColors.outline,
              ),
              Flexible(
                child: _TextAction(
                  label: 'debt_action_reject'.tr(),
                  icon: LucideIcons.x,
                  // Red marks the destructive one (DESIGN.md) so it cannot be
                  // mistaken for the neutral "change the number" beside it.
                  ink: BrutalColors.secondary,
                  onTap: () => run(() => rejectDebt(context, ref, proposal)),
                ),
              ),
            ],
          ),
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

    return PressableBrutal(
      onTap: () async {
        if (await cancelDebt(context, ref, proposal) && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      color: BrutalColors.surface,
      radius: BrutalSpec.pillRadius,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.undo2,
            size: 20,
            color: BrutalColors.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            'debt_action_cancel'.tr(),
            style: BrutalText.headlineLgMobile(
              fontSize: 18,
              color: BrutalColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet, borderless action — used for the two ways out, so they read as
/// available without competing with the confirmation above them.
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.ink,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final foreground = ink ?? BrutalColors.onBackground;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BrutalText.headlineLgMobile(
                  fontSize: 17,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
