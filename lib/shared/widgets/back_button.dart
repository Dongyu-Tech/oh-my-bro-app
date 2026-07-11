import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'brutalism.dart';

/// One consistent, labelled back control across every pushed screen: a clear
/// left-arrow icon plus a "返回" label, so it reads as "go back" at a glance.
class BrutalBackButton extends StatelessWidget {
  const BrutalBackButton({super.key, this.onTap});

  /// Defaults to popping the current route.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableBrutal(
      onTap: onTap ?? () => context.pop(),
      color: BrutalColors.surface,
      radius: BrutalSpec.pillRadius,
      padding: const EdgeInsets.fromLTRB(8, 8, 13, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_rounded, size: 20),
          const SizedBox(width: 4),
          Text('back_label'.tr(), style: BrutalText.labelBold(fontSize: 14)),
        ],
      ),
    );
  }
}
