import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/dialogs/basic_dialog.dart';
import 'package:heymybro/shared/models/bro_code.dart';
import 'package:heymybro/shared/models/friendship_model.dart';
import 'package:heymybro/shared/pages/paywall_sheet.dart';
import 'package:heymybro/shared/pages/share_id_sheet.dart';
import 'package:heymybro/shared/provider/auth_provider.dart';
import 'package:heymybro/shared/provider/entitlement_provider.dart';
import 'package:heymybro/shared/provider/friendship_provider.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/provider/settings_provider.dart';
import 'package:heymybro/shared/provider/user_provider.dart';
import 'package:heymybro/shared/widgets/brutal_qr.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// "帳號 / Account" tab — profile header, shareable ID, account stats and the
/// settings menu.
///
/// Mostly a static scaffold matching the visible sample data (profile + stats
/// are hardcoded placeholders like the other nav screens). The only live wiring
/// is the Dark Mode row, which toggles [settingsProvider]'s theme mode, and
/// Logout, which calls the (no-op by default) [authServiceProvider]. Every other
/// row surfaces a "coming soon" message.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark =
        ref.watch(settingsProvider.select((s) => s.themeMode)) ==
        ThemeMode.dark;

    // Live signed-in Google user; fall back to the synchronous current user
    // before the auth stream emits its first value.
    final user =
        ref.watch(currentUserProvider).asData?.value ??
        ref.watch(authServiceProvider).currentUser;
    // public.users is the app's own record and wins where it has something;
    // the auth provider's Google fields are the fallback for a build with no
    // backend, and for the moment before the profile fetch lands.
    final profile = ref.watch(myProfileProvider).asData?.value;

    final email = user?.email ?? '';
    final name = switch ((profile?.bestName, user?.displayName?.trim())) {
      (final p?, _) when p.isNotEmpty => p,
      (_, final g?) when g.isNotEmpty => g,
      _ => email.contains('@') ? email.split('@').first : 'Bro',
    };
    final handle = switch (profile?.handle?.trim()) {
      final h? when h.isNotEmpty => '@$h',
      _ => email.contains('@') ? '@${email.split('@').first}' : '',
    };
    final photoUrl = profile?.effectiveAvatarUrl ?? user?.photoUrl;

    final daysLogged = ref.watch(daysLoggedProvider);
    // monthSpendProvider is spend magnitude (money out). With no income yet, the
    // month balance is its negation — keeps 本月總額 consistent with 個人 頁's 本月結餘.
    final monthNet = -ref.watch(monthSpendProvider);
    final isPro = ref.watch(proEntitlementProvider);

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left-aligned so the marker band hugs the text (the stretched
                // column would otherwise span it full-width).
                Align(
                  alignment: Alignment.centerLeft,
                  child: MarkerHighlight(
                    child: Text(
                      'account_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ProfileHeader(
                  name: name,
                  handle: handle,
                  email: email,
                  photoUrl: photoUrl,
                ),
                const SizedBox(height: 20),
                _ShareIdCard(
                  token: ref.watch(myShareTokenProvider).asData?.value,
                  label: handle,
                ),
                const SizedBox(height: 20),
                _StatsCard(daysLogged: daysLogged, monthNet: monthNet),
                const SizedBox(height: 20),

                _AccountMenuRow(
                  icon: LucideIcons.sparkles,
                  label: (isPro ? 'account_pro_member' : 'account_go_pro').tr(),
                  trailing: isPro ? const _TrailingPill(text: 'PRO') : null,
                  onTap: isPro
                      ? () => showMessage('account_pro_thanks'.tr())
                      : () => showPaywall(context),
                ),
                const SizedBox(height: 12),
                _AccountMenuRow(
                  icon: LucideIcons.coins,
                  label: 'account_currency'.tr(),
                  trailing: const _TrailingPill(text: 'TWD'),
                  onTap: comingSoon,
                ),
                const SizedBox(height: 12),
                _AccountMenuRow(
                  icon: LucideIcons.layoutGrid,
                  label: 'account_categories'.tr(),
                  onTap: comingSoon,
                ),
                const SizedBox(height: 12),
                _AccountMenuRow(
                  icon: LucideIcons.download,
                  label: 'account_export'.tr(),
                  onTap: comingSoon,
                ),
                const SizedBox(height: 12),
                // Live setting: flips the app between light and dark themes.
                _AccountMenuRow(
                  icon: isDark ? LucideIcons.moon : LucideIcons.sun,
                  label: (isDark ? 'account_mode_dark' : 'account_mode_light')
                      .tr(),
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .saveThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
                ),
                const SizedBox(height: 12),
                _AccountMenuRow(
                  icon: LucideIcons.bell,
                  label: 'account_notifications'.tr(),
                  onTap: comingSoon,
                ),
                const SizedBox(height: 12),
                _AccountMenuRow(
                  icon: LucideIcons.shield,
                  label: 'account_privacy'.tr(),
                  onTap: comingSoon,
                ),
                const SizedBox(height: 12),
                _AccountMenuRow(
                  icon: LucideIcons.logOut,
                  label: 'account_logout'.tr(),
                  danger: true,
                  onTap: () => _logout(ref, context),
                ),

                const SizedBox(height: 28),
                const _AccountFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(WidgetRef ref, BuildContext context) async {
    await showConfirmLeaveDialog(
      context,
      icon: const Icon(LucideIcons.logOut, color: BrutalColors.secondary),
      title: 'logout_confirm_title'.tr(),
      text: 'logout_confirm_text'.tr(),
      confirmText: 'logout_confirm_action'.tr(),
      confirmType: ConfirmType.delete,
      onConfirm: () => _signOut(ref),
    );
  }

  /// Signs out; the router's auth guard redirects to /onboarding once the
  /// session clears, so no explicit navigation is needed here.
  Future<void> _signOut(WidgetRef ref) async {
    switch (await ref.read(authServiceProvider).signOut()) {
      case Ok():
        break;
      case Error(error: final e):
        showErrorSnakeBar(e.toString());
    }
  }
}

/// Centered avatar + name/handle/email, on a white card with a small edit badge
/// stuck to the avatar corner (comic-sticker style). The whole card opens the
/// profile editor — the badge was already drawn as if it did.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.handle,
    required this.email,
    this.photoUrl,
  });

  final String name;
  final String handle;
  final String email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile/edit'),
      behavior: HitTestBehavior.opaque,
      child: _card(context),
    );
  }

  Widget _card(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Avatar with a corner edit badge.
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The Google picture when there is one; otherwise the same
                // first-letter monogram every other avatar in the app falls
                // back to, rather than a generic people icon.
                BrutalAvatar(
                  name: name,
                  photoUrl: photoUrl,
                  size: 96,
                  radius: 48, // fully rounded → circle
                  color: BrutalColors.primaryContainer,
                  borderWidth: BrutalSpec.borderWidth,
                  fontSize: 44,
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: BrutalColors.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BrutalColors.onBackground,
                        width: BrutalSpec.borderWidthThin,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.pencil,
                      size: 14,
                      color: BrutalColors.onBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(name, style: BrutalText.headlineLgMobile(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            handle,
            style: BrutalText.labelBold(
              color: BrutalColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: BrutalText.labelBold(
              color: BrutalColors.onSurfaceVariant,
              fontSize: 14,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow card holding a scannable QR of the user's share ID (their email) and
/// a "scan to share" caption. Tapping opens [showShareIdSheet] — the same code,
/// big and bright enough for someone else's camera.
class _ShareIdCard extends StatelessWidget {
  const _ShareIdCard({required this.token, required this.label});

  /// The short-lived code the QR encodes. Null in the gap before it is minted
  /// (and on a build with no backend), where the old glyph placeholder stands
  /// in rather than a QR of nothing.
  ///
  /// Neither the email nor the account id is the payload any more: scanning
  /// skips the accept step, so whatever is in this code is a pass into your
  /// friend list. It has to be something that expires.
  final FriendToken? token;

  /// The `@handle` printed under the code — identity for a human, where the
  /// code itself is only meaningful to a scanner.
  final String label;

  @override
  Widget build(BuildContext context) {
    final share = token;
    final hasShareId = share != null;
    final payload = hasShareId ? BroCode(token: share.token).encode() : '';

    return PressableBrutal(
      onTap: hasShareId
          ? () => showShareIdSheet(
              context,
              payload: payload,
              label: label,
              expiresAt: share.expiresAt,
            )
          : comingSoon,
      color: BrutalColors.primaryContainer,
      radius: BrutalSpec.cardRadius,
      restOffset: BrutalSpec.shadowOffsetMobile,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          if (hasShareId)
            BrutalQrCode(data: payload, size: 132)
          else
            Container(
              width: 132,
              height: 132,
              decoration: brutalDecoration(
                color: BrutalColors.surface,
                radius: BrutalSpec.pillRadius,
                offset: 0,
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.qrCode,
                size: 96,
                color: BrutalColors.onBackground,
              ),
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'account_share_id'.tr(),
                style: BrutalText.labelBold(fontSize: 15),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.scanLine,
                size: 18,
                color: BrutalColors.onBackground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "帳戶統計" card with two stat rows (days logged + this-month total).
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.daysLogged, required this.monthNet});

  final int daysLogged;
  final int monthNet;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    final sign = monthNet > 0 ? '+' : (monthNet < 0 ? '-' : '');
    final monthText = '$sign\$${money.format(monthNet.abs())}';
    final monthColor = monthNet > 0
        ? BrutalColors.incomeInk
        : (monthNet < 0 ? BrutalColors.secondary : BrutalColors.onBackground);
    return BrutalCard(
      color: BrutalColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'account_stats_title'.tr(),
            style: BrutalText.labelBold(
              color: BrutalColors.onSurfaceVariant,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          _StatRow(label: 'account_days_logged'.tr(), value: '$daysLogged'),
          const Divider(
            height: 24,
            thickness: BrutalSpec.borderWidthThin,
            color: BrutalColors.onBackground,
          ),
          _StatRow(
            label: 'account_month_total'.tr(),
            value: monthText,
            valueColor: monthColor,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: BrutalText.body(fontSize: 16)),
        Text(
          value,
          style: BrutalText.headlineLgMobile(
            fontSize: 22,
            color: valueColor ?? BrutalColors.onBackground,
          ),
        ),
      ],
    );
  }
}

/// One settings row: bordered icon tile, label, optional trailing widget, and a
/// chevron. [danger] paints it in the red "destructive" palette (logout).
class _AccountMenuRow extends StatelessWidget {
  const _AccountMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = danger
        ? BrutalColors.secondary
        : BrutalColors.onBackground;

    return PressableBrutal(
      onTap: onTap,
      color: BrutalColors.surface,
      radius: BrutalSpec.pillRadius,
      restOffset: BrutalSpec.shadowOffsetMobile,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: brutalDecoration(
              color: danger
                  ? BrutalColors.dangerBanner
                  : BrutalColors.surfaceContainer,
              radius: BrutalSpec.pillRadius,
              offset: 0,
              borderWidth: BrutalSpec.borderWidthThin,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: danger ? BrutalColors.onError : BrutalColors.onBackground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BrutalText.labelBold(color: foreground, fontSize: 16),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronRight, size: 22, color: foreground),
        ],
      ),
    );
  }
}

/// Small bordered value tag shown on the right of a menu row (e.g. "TWD").
class _TrailingPill extends StatelessWidget {
  const _TrailingPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return BrutalPill(
      color: BrutalColors.surfaceContainer,
      borderWidth: BrutalSpec.borderWidthThin,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(text, style: BrutalText.labelBold(fontSize: 13)),
    );
  }
}

/// Decorative brand footer (sample branding, not user data).
class _AccountFooter extends StatelessWidget {
  const _AccountFooter();

  @override
  Widget build(BuildContext context) {
    final style = BrutalText.labelBold(
      color: BrutalColors.onSurfaceVariant,
      fontSize: 11,
      weight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    return Column(
      children: [
        Text('ROUGH BOOKIE v2.4.0-BETA', style: style),
        const SizedBox(height: 2),
        Text('MADE WITH PUNCH & PASSION', style: style),
      ],
    );
  }
}
