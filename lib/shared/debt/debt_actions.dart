import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The four things you can do to a proposal, in one place so the ledger card
/// and the full-screen confirm page can never drift apart in behaviour.
///
/// Each returns true when the user's intent landed, which callers use to know
/// whether to close whatever they were showing.

/// Accept it. A proposal whose amount was left blank cannot be accepted — the
/// number has to go in first — so this quietly becomes [counterDebt] instead
/// of failing at the user for a rule the UI can simply honour.
Future<bool> acceptDebt(
  BuildContext context,
  WidgetRef ref,
  DebtProposal proposal,
) async {
  if (proposal.amount == null) return counterDebt(context, ref, proposal);

  final result = await ref.read(debtServiceProvider).accept(proposal.id);
  if (!context.mounted) return false;
  return reportDebtOutcome(result);
}

/// Reject it with an optional reason the other side will see.
Future<bool> rejectDebt(
  BuildContext context,
  WidgetRef ref,
  DebtProposal proposal,
) async {
  final reason = await promptDebtField(
    context,
    title: 'debt_reject_title'.tr(),
    hint: 'debt_reject_hint'.tr(),
    number: false,
  );
  // null is "backed out"; empty is a deliberate "no reason given".
  if (reason == null || !context.mounted) return false;

  final result = await ref
      .read(debtServiceProvider)
      .reject(proposal.id, reason);
  if (!context.mounted) return false;
  return reportDebtOutcome(result);
}

/// Change the amount and hand the turn back.
Future<bool> counterDebt(
  BuildContext context,
  WidgetRef ref,
  DebtProposal proposal,
) async {
  final raw = await promptDebtField(
    context,
    title: 'debt_counter_title'.tr(),
    hint: 'debt_counter_hint'.tr(),
    number: true,
    initial: proposal.amount?.toString(),
  );
  if (raw == null || !context.mounted) return false;

  final amount = int.tryParse(raw.trim()) ?? 0;
  if (amount <= 0) {
    showErrorSnakeBar('debt_err_amount'.tr());
    return false;
  }

  final result = await ref
      .read(debtServiceProvider)
      .counter(proposal.id, amount);
  if (!context.mounted) return false;
  return reportDebtOutcome(result);
}

/// Take back a proposal of my own that has not been answered yet.
Future<bool> cancelDebt(
  BuildContext context,
  WidgetRef ref,
  DebtProposal proposal,
) async {
  final result = await ref.read(debtServiceProvider).cancel(proposal.id);
  if (!context.mounted) return false;
  return reportDebtOutcome(result);
}

/// Turn an outcome into a message, and report whether the intent landed.
///
/// `stale` counts as success on purpose. The server returns it when the
/// proposal has already left `pending` — a double tap, a resend after a
/// dropped connection, or the other side getting there first. In every one of
/// those the end state the user wanted already holds, so a red error would be
/// a lie about a success.
bool reportDebtOutcome(Result<DebtOutcome> result) {
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

/// One-field bottom sheet. Returns the text, or null if dismissed.
Future<String?> promptDebtField(
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
