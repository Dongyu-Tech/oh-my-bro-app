import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

/// The claim-slip chrome both confirmation screens are built from: a yellow
/// band naming who is asking, a hard rule under it (DESIGN.md — "Header: often
/// separated by a horizontal black line"), then the facts.
///
/// Extracted so a debt and a repayment cannot drift apart visually. They are
/// the same object at different moments — somebody asserting something about
/// money and waiting for you to agree — and the only thing that should differ
/// between the two screens is what goes in the body.
class DebtSlipCard extends StatelessWidget {
  const DebtSlipCard({
    required this.name,
    required this.claim,
    required this.body,
    this.avatarUrl,
    this.badge,
    this.badgeColor = BrutalColors.secondary,
    this.sticker,
    super.key,
  });

  final String name;
  final String? avatarUrl;

  /// The one-line claim under the name — "說你欠他", "說他還你錢了".
  final String claim;

  /// Optional pill beside the claim.
  final String? badge;
  final Color badgeColor;

  /// 粗哥, leaning over the top-right corner.
  final String? sticker;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: sticker == null ? 0 : 30),
          child: Container(
            decoration: brutalDecoration(
              color: BrutalColors.surface,
              radius: 20,
              offset: BrutalSpec.shadowOffset,
            ),
            // Clipped to the INSIDE of the border. Clipping on the Container
            // clips to the outer rounded rect instead, which lets the yellow
            // band's square corners paint straight over the top of the border.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(brutalInnerRadius(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Head(
                    name: name,
                    avatarUrl: avatarUrl,
                    claim: claim,
                    badge: badge,
                    badgeColor: badgeColor,
                    leaveRoomForSticker: sticker != null,
                  ),
                  const BrutalDivider(margin: EdgeInsets.zero),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: body,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (sticker != null)
          Positioned(
            top: 0,
            right: 0,
            child: Image.asset(sticker!, height: 104, fit: BoxFit.contain),
          ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({
    required this.name,
    required this.claim,
    required this.avatarUrl,
    required this.badge,
    required this.badgeColor,
    required this.leaveRoomForSticker,
  });

  final String name;
  final String claim;
  final String? avatarUrl;
  final String? badge;
  final Color badgeColor;
  final bool leaveRoomForSticker;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BrutalColors.primaryContainer,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          BrutalAvatar(
            name: name,
            photoUrl: avatarUrl,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        // The name is right above, so the claim does not
                        // repeat it — two lines that read as one sentence.
                        claim,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BrutalText.labelBold(
                          fontSize: 13,
                          color: BrutalColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      // Flexible too, not just the claim: with 粗哥 taking a
                      // fixed bite out of this row, a badge that refuses to
                      // shrink overflows before the text beside it does.
                      Flexible(
                        child: BrutalPill(
                          color: badgeColor,
                          radius: 6,
                          borderWidth: BrutalSpec.borderWidthThin,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            badge!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BrutalText.labelBold(
                              fontSize: 11,
                              color: BrutalColors.onError,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (leaveRoomForSticker) const SizedBox(width: 76),
        ],
      ),
    );
  }
}

/// A labelled fact inside a slip: the small caption, then the value at
/// whatever weight its importance deserves.
class DebtSlipField extends StatelessWidget {
  const DebtSlipField({
    required this.label,
    required this.value,
    this.icon,
    this.valueSize = 34,
    this.valueColor,
    this.note,
    this.underline = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final double valueSize;
  final Color? valueColor;

  /// Small print under the value — "was $500", "leaves $200".
  final String? note;

  /// Marker stroke under the value, for the one figure that matters most.
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final valueText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        style: BrutalText.headlineLgMobile(
          fontSize: valueSize,
          color: valueColor,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: BrutalText.labelBold(fontSize: 14)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 28),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: underline
                  ? MarkerHighlight(
                      // A low band reads as a marker stroke UNDER the digits
                      // rather than a highlight across them.
                      heightFactor: 0.18,
                      padding: const EdgeInsets.only(right: 12, bottom: 2),
                      child: valueText,
                    )
                  : valueText,
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              note!,
              style: BrutalText.body(
                fontSize: 13,
                color: BrutalColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The bottom of a confirmation screen: a sentence-long primary answer, an
/// optional note about what confirming does, and quieter ways out beneath.
///
/// A debt gets three answers, a repayment two. Sharing the bar means the
/// difference is only ever in what is passed, never in how it looks.
class DebtActionBar extends StatelessWidget {
  const DebtActionBar({
    required this.primaryLabel,
    required this.onPrimary,
    this.note,
    this.secondaries = const [],
    super.key,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? note;
  final List<DebtTextAction> secondaries;

  @override
  Widget build(BuildContext context) {
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
                if (note != null) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: BrutalDivider(
                          thickness: BrutalSpec.borderWidthThin,
                          margin: EdgeInsets.only(right: 10),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BrutalText.labelBold(fontSize: 13),
                        ),
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
                ],
                PressableBrutal(
                  onTap: onPrimary,
                  color: BrutalColors.primaryContainer,
                  radius: BrutalSpec.pillRadius,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    primaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: BrutalText.headlineLgMobile(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (secondaries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < secondaries.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: BrutalSpec.borderWidthThin,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: BrutalColors.outline,
                    ),
                  // Flexible so a longer localisation shrinks instead of
                  // shoving the row off the edge of a narrow screen.
                  Flexible(child: secondaries[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A quiet, borderless action — used for the ways out, so they read as
/// available without competing with the answer above them.
class DebtTextAction extends StatelessWidget {
  const DebtTextAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.ink,
    super.key,
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

/// The headline + one-line explanation every confirmation screen opens with.
class DebtScreenTitle extends StatelessWidget {
  const DebtScreenTitle({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: BrutalText.headlineLgMobile(fontSize: 40)),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: BrutalText.body(
            fontSize: 15,
            color: BrutalColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Formats money the way every debt screen does.
String debtMoney(int amount) =>
    '\$${NumberFormat.decimalPattern().format(amount)}';
