import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// A debt still being agreed, drawn as one more row of 誰欠誰.
///
/// Deliberately the same card as a settled debt rather than a separate block
/// above the list: it *is* a debt between the two of you, and splitting them
/// into two lists made the page read as two answers to the same question. What
/// distinguishes it is the footer — where a real debt offers 分享 and 結清,
/// this says either who is being waited on, or that the wait is on you.
///
/// Nothing here is in any balance: only debts that have landed in a group are,
/// and a proposal lands the moment it is confirmed and not before.
class DebtProposalCard extends ConsumerWidget {
  const DebtProposalCard({required this.proposal, super.key});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myUserIdProvider);
    final name = proposal.otherName ?? '?';
    final owed = proposal.debtorId != me;
    final pending = proposal.status == 'pending';
    final myTurn = pending && proposal.awaitingId == me;
    final money = NumberFormat.decimalPattern();

    return GestureDetector(
      // The whole card opens the same page the arrival alert does, so a debt
      // is decided in one place however you reached it.
      onTap: () => context.push('/debt/${proposal.id}'),
      behavior: HitTestBehavior.opaque,
      child: BrutalCard(
        color: pending
            ? BrutalColors.surface
            : BrutalColors.surfaceContainerHigh,
        offset: 3,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Who it is with, up in the corner with their face on it. The
            // state chip sits right after the name so "阿華 · 欠你錢" reads as
            // one phrase instead of two things at opposite ends of the card.
            DebtPartyLine(
              name: name,
              avatarUrl: proposal.otherAvatarUrl,
              badge: pending
                  ? (owed ? 'circle_card_owes_you' : 'group_you_owe').tr()
                  : _terminalLabel(proposal.status),
              badgeColor: pending
                  ? BrutalColors.surfaceContainerHigh
                  : BrutalColors.secondary,
              badgeInk: pending ? null : BrutalColors.onError,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    proposal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrutalText.headlineLgMobile(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  proposal.amount == null
                      ? 'debt_amount_blank'.tr()
                      : '${owed ? '+' : '-'}\$${money.format(proposal.amount)}',
                  style: proposal.amount == null
                      ? BrutalText.labelBold(
                          fontSize: 12,
                          color: BrutalColors.onSurfaceVariant,
                        )
                      : BrutalText.display(
                          fontSize: 26,
                          // Muted, not red: an unagreed figure has no business
                          // shouting like one that counts.
                          color: BrutalColors.onSurfaceVariant,
                        ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!pending)
                    _Footer(
                      icon: LucideIcons.circleX,
                      label: _terminalDetail(proposal),
                      ink: BrutalColors.secondary,
                      onTap: () => ref
                          .read(debtServiceProvider)
                          .markDismissed(proposal.id),
                    )
                  else if (myTurn)
                    // The one card in the list that wants something from you.
                    _Footer(
                      icon: LucideIcons.arrowRight,
                      label: 'debt_action_goto'.tr(),
                      button: true,
                      onTap: () => context.push('/debt/${proposal.id}'),
                    )
                  else
                    _Footer(
                      icon: LucideIcons.hourglass,
                      label: 'debt_status_waiting'.tr(),
                      ink: BrutalColors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _terminalLabel(String status) => switch (status) {
    'rejected' => 'debt_state_rejected_bare'.tr(),
    'cancelled' => 'debt_state_cancelled'.tr(),
    _ => 'debt_state_void'.tr(),
  };

  static String _terminalDetail(DebtProposal proposal) {
    final reason = proposal.rejectReason?.trim();
    if (proposal.status == 'rejected' && (reason?.isNotEmpty ?? false)) {
      return 'debt_state_rejected'.tr(namedArgs: {'reason': reason!});
    }
    return 'debt_action_dismiss'.tr();
  }
}

/// The top-right corner of a debt card: who it is with, and what kind it is.
///
/// Shared by both card types so a debt looks the same whether it has been
/// agreed yet or not — the only thing that should differ between them is the
/// footer, and how loudly the amount is drawn.
class DebtPartyLine extends StatelessWidget {
  const DebtPartyLine({
    required this.name,
    required this.badge,
    required this.badgeColor,
    this.avatarUrl,
    this.badgeInk,
    super.key,
  });

  final String name;
  final String? avatarUrl;
  final String badge;
  final Color badgeColor;
  final Color? badgeInk;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        BrutalAvatar(
          name: name,
          photoUrl: avatarUrl,
          size: 26,
          fontSize: 12,
          borderWidth: BrutalSpec.borderWidthThin,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BrutalText.labelBold(fontSize: 14),
          ),
        ),
        const SizedBox(width: 7),
        BrutalPill(
          color: badgeColor,
          radius: BrutalSpec.pillRadius,
          borderWidth: BrutalSpec.borderWidthThin,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            badge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BrutalText.labelBold(fontSize: 11, color: badgeInk),
          ),
        ),
      ],
    );
  }
}

/// The footer line. A button when there is something to do, plain text when
/// there is only something to know — the difference has to be visible without
/// tapping to find out.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.icon,
    required this.label,
    this.onTap,
    this.ink,
    this.button = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? ink;
  final bool button;

  @override
  Widget build(BuildContext context) {
    final foreground = ink ?? BrutalColors.onBackground;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BrutalText.labelBold(fontSize: 13, color: foreground),
          ),
        ),
      ],
    );

    if (!button) {
      return Flexible(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: row,
          ),
        ),
      );
    }

    return PressableBrutal(
      onTap: onTap,
      color: BrutalColors.primaryContainer,
      radius: BrutalSpec.pillRadius,
      borderWidth: BrutalSpec.borderWidthThin,
      restOffset: 2,
      pressedOffset: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: row,
    );
  }
}
