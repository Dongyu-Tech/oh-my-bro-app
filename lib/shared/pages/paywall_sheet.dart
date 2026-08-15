import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/shared/provider/entitlement_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Upgrade wall shown when a free user hits the gathering limit.
///
/// Returns `true` if the user "upgraded". The purchase is currently a STUB — it
/// just flips the local PRO flag ([ProEntitlementNotifier.setPro]); wiring real
/// Play Billing / RevenueCat is the only change needed to make it real.
Future<bool> showPaywall(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PaywallSheet(),
  );
  return result ?? false;
}

class _PaywallSheet extends ConsumerWidget {
  const _PaywallSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BrutalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: BrutalPill(
              color: BrutalColors.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Text(
                'paywall_badge'.tr(),
                style: BrutalText.labelBold(fontSize: 14, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'paywall_title'.tr(),
            style: BrutalText.headlineLgMobile(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'paywall_subtitle'.tr(namedArgs: {'count': '$kFreeGatheringLimit'}),
            style: BrutalText.body(
              fontSize: 15,
              color: BrutalColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _Benefit(
            icon: LucideIcons.partyPopper,
            text: 'paywall_benefit_unlimited'.tr(),
          ),
          _Benefit(icon: LucideIcons.users, text: 'paywall_benefit_friends'.tr()),
          _Benefit(
            icon: LucideIcons.sparkles,
            text: 'paywall_benefit_support'.tr(),
          ),
          const SizedBox(height: 20),
          PressableBrutal(
            onTap: () async {
              // STUB purchase — replace with Play Billing / RevenueCat.
              await ref.read(proEntitlementProvider.notifier).setPro(true);
              if (context.mounted) Navigator.of(context).pop(true);
            },
            color: BrutalColors.primaryContainer,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'paywall_upgrade'.tr(),
              style: BrutalText.labelBold(fontSize: 17),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'paywall_later'.tr(),
                  style: BrutalText.labelBold(
                    color: BrutalColors.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: BrutalSpec.pillRadius,
              offset: 0,
              borderWidth: BrutalSpec.borderWidthThin,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: BrutalText.body(fontSize: 15))),
        ],
      ),
    );
  }
}
