import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

/// Placeholder used by the bottom-nav tabs that aren't built yet.
class PlaceholderTabPage extends StatelessWidget {
  const PlaceholderTabPage({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: DottedBackdrop(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: BrutalCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 48, color: BrutalColors.onBackground),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: BrutalText.headlineLgMobile(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'coming_soon'.tr(),
                            style: BrutalText.labelBold(
                              color: BrutalColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
