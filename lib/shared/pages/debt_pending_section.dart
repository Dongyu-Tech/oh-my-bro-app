import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';
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
          DebtProposalLine(proposal: proposal),
          const SizedBox(height: 10),
          DebtActionRow(proposal: proposal),
        ],
      ),
    );
  }
}

/// The accept / reject / change buttons. Shared with the popup so the two can
/// never drift apart.
class DebtActionRow extends ConsumerWidget {
  const DebtActionRow({required this.proposal, this.onDone, super.key});

  final DebtProposal proposal;

  /// Called after a successful answer — the popup uses it to close itself.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _SmallButton(
            label: 'debt_action_accept'.tr(),
            color: BrutalColors.primaryContainer,
            onTap: () async {
              // A blank amount cannot be accepted — it has to be filled in
              // first, which is what "change" does.
              if (proposal.amount == null) {
                await _openCounterSheet(context, ref, proposal, onDone);
                return;
              }
              final result = await ref
                  .read(debtServiceProvider)
                  .accept(proposal.id);
              if (!context.mounted) return;
              if (_report(result)) onDone?.call();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallButton(
            label: 'debt_action_reject'.tr(),
            color: BrutalColors.surface,
            onTap: () => _openRejectSheet(context, ref, proposal, onDone),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallButton(
            label: 'debt_action_counter'.tr(),
            color: BrutalColors.surface,
            onTap: () => _openCounterSheet(context, ref, proposal, onDone),
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
                onTap: () async {
                  final result = await ref
                      .read(debtServiceProvider)
                      .cancel(proposal.id);
                  if (!context.mounted) return;
                  _report(result);
                },
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

Future<void> _openRejectSheet(
  BuildContext context,
  WidgetRef ref,
  DebtProposal proposal,
  VoidCallback? onDone,
) async {
  final reason = await _promptSheet(
    context,
    title: 'debt_reject_title'.tr(),
    hint: 'debt_reject_hint'.tr(),
    number: false,
  );
  // null means they backed out; empty is a deliberate "no reason given".
  if (reason == null || !context.mounted) return;

  final result = await ref
      .read(debtServiceProvider)
      .reject(proposal.id, reason);
  if (!context.mounted) return;
  if (_report(result)) onDone?.call();
}

Future<void> _openCounterSheet(
  BuildContext context,
  WidgetRef ref,
  DebtProposal proposal,
  VoidCallback? onDone,
) async {
  final raw = await _promptSheet(
    context,
    title: 'debt_counter_title'.tr(),
    hint: 'debt_counter_hint'.tr(),
    number: true,
    initial: proposal.amount?.toString(),
  );
  if (raw == null || !context.mounted) return;

  final amount = int.tryParse(raw.trim()) ?? 0;
  if (amount <= 0) {
    showErrorSnakeBar('debt_err_amount'.tr());
    return;
  }

  final result = await ref
      .read(debtServiceProvider)
      .counter(proposal.id, amount);
  if (!context.mounted) return;
  if (_report(result)) onDone?.call();
}

/// One-field bottom sheet. Returns the text, or null if dismissed.
Future<String?> _promptSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required bool number,
  String? initial,
}) {
  final controller = TextEditingController(text: initial);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: BrutalSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: BrutalText.headlineLgMobile(fontSize: 22)),
            const SizedBox(height: 14),
            Container(
              decoration: brutalDecoration(
                color: BrutalColors.surface,
                radius: BrutalSpec.pillRadius,
                offset: 2,
                borderWidth: BrutalSpec.borderWidthThin,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: number
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: number
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                cursorColor: BrutalColors.onBackground,
                style: BrutalText.body(fontSize: 16),
                onSubmitted: (v) => Navigator.of(sheetContext).pop(v),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: BrutalText.body(
                    fontSize: 16,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PressableBrutal(
              onTap: () => Navigator.of(sheetContext).pop(controller.text),
              color: BrutalColors.primaryContainer,
              radius: BrutalSpec.pillRadius,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: Text(
                'debt_send'.tr(),
                style: BrutalText.headlineLgMobile(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Turn an outcome into a message, and report whether the user's intent
/// actually landed.
///
/// `stale` is treated as success on purpose: the server returns it when the
/// proposal has already left `pending` — a double tap, a resend after a
/// dropped connection, or the other side getting there first. In every one of
/// those the end state they wanted already holds, so a red error would be a
/// lie about a success.
bool _report(Result<DebtOutcome> result) {
  switch (result) {
    case Ok(value: DebtOutcome.stale):
      showMessage('debt_err_stale'.tr());
      return true;
    case Ok(value: final outcome) when outcome.isSuccess:
      return true;
    case Ok(value: DebtOutcome.notYours):
      showErrorSnakeBar('debt_err_not_yours'.tr());
    case Ok(value: DebtOutcome.badInput):
    case Ok(value: DebtOutcome.noAmount):
      showErrorSnakeBar('debt_err_amount'.tr());
    case Ok():
    case Error():
      showErrorSnakeBar('debt_err_generic'.tr());
  }
  return false;
}
