import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_provider.dart';
import 'settings_provider.dart';

/// How many concurrent (active, non-archived) gatherings a FREE user may run.
/// Past this they're prompted to upgrade to PRO. This is the monetization knob —
/// change the number here.
const kFreeGatheringLimit = 2;

const _kProKey = 'pro_entitlement';

/// Whether the user has PRO.
///
/// Persisted locally for now (SharedPreferences) as a stand-in for a real
/// purchase. When Play Billing / RevenueCat is wired, replace [setPro]'s body
/// with a purchase/restore call and drive [state] from the entitlement — every
/// gate below (`proEntitlementProvider`) keeps working unchanged.
class ProEntitlementNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_kProKey) ?? false;
  }

  Future<void> setPro(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kProKey, value);
    state = value;
  }
}

final proEntitlementProvider = NotifierProvider<ProEntitlementNotifier, bool>(
  ProEntitlementNotifier.new,
);

/// Active (non-archived) real gatherings — what the free limit counts. Direct
/// debts (the composer's synthetic 2-person groups) are already excluded by
/// [gatheringsProvider], so they never count against the limit.
final activeGatheringCountProvider = Provider<int>((ref) {
  return ref.watch(gatheringsProvider).where((g) => !g.isArchived).length;
});

/// True when a free user is at/over the gathering limit and must upgrade to
/// start another. PRO users are never blocked.
final atGatheringLimitProvider = Provider<bool>((ref) {
  if (ref.watch(proEntitlementProvider)) return false;
  return ref.watch(activeGatheringCountProvider) >= kFreeGatheringLimit;
});
