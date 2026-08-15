import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/confirm_dialog.dart';

/// After a debt is settled, offer to log the user's own share(s) of that spend
/// into 個人記帳. Each item pairs a display title (the gathering name) with the
/// amount to book and the id of the settlement that cleared it; zero/negative
/// amounts are dropped (you only fronted money, consumed nothing). One confirm
/// covers them all. Each booked entry is linked to its [settlementId] so undoing
/// that repayment retracts the entry (and a re-settle can't double-book).
Future<void> promptLogMyShare(
  BuildContext context,
  WidgetRef ref,
  List<({String title, int amount, String settlementId})> shares,
) async {
  final items = shares.where((s) => s.amount > 0).toList();
  if (items.isEmpty) return;
  final total = items.fold(0, (s, e) => s + e.amount);
  final money = NumberFormat.decimalPattern();
  final ok = await confirmDialog(
    context,
    title: 'log_share_title'.tr(
      namedArgs: {'amount': '\$${money.format(total)}'},
    ),
    message: items.length == 1
        ? items.first.title
        : 'log_share_count'.tr(namedArgs: {'count': '${items.length}'}),
    confirmLabel: 'log_share_confirm'.tr(),
  );
  if (!ok) return;
  final svc = ref.read(groupServiceProvider);
  for (final s in items) {
    await svc.addPersonalEntry(
      title: s.title,
      amount: s.amount,
      sourceSettlementId: s.settlementId,
    );
  }
}
