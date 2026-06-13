import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:heymybro/shared/widgets/app_keyboard_focus_guard.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';
import 'package:heymybro/shared/pages/ledger_page.dart';
import 'package:heymybro/shared/pages/transaction_page.dart';
import 'package:heymybro/shared/pages/new_transaction_page.dart';
import 'package:heymybro/shared/pages/circle_page.dart';
import 'package:heymybro/shared/pages/account_page.dart';

/// Root shell hosting the 4 bottom-nav tabs with an IndexedStack so tab state
/// is preserved when switching.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // The "+" (index 2) is a regular swipeable/tappable tab hosting the 記帳 flow.
  final _pageController = PageController();
  int _index = 0;

  // How much more deliberate a horizontal drag must be (vs. the OS touch slop)
  // before the PageView claims it as a tab swipe. Higher = harder to trigger a
  // swipe by accident while scrolling vertically. Inner scrollables keep the
  // normal slop, so this only biases the vertical-vs-horizontal arena.
  static const double _swipeSlopFactor = 2.6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Animate to tab [i] in response to a nav-bar tap. [onPageChanged] is the
  /// single source of truth for [_index], so swipes and taps stay in sync.
  void _goToTab(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const LedgerPage(),
      const TransactionPage(),
      // After 「記帳！」the flow asks the shell to swipe back to the ledger tab.
      NewTransactionPage(onRecorded: () => _goToTab(0)),
      const CirclePage(),
      const AccountPage(),
    ];

    // Raise the touch slop seen by the PageView's own horizontal recognizer so
    // it only wins the gesture arena on a clearly horizontal swipe; each page
    // restores the normal slop below so vertical scrolling is unaffected.
    final mq = MediaQuery.of(context);
    final baseSlop = mq.gestureSettings.touchSlop ?? kTouchSlop;

    return Scaffold(
      backgroundColor: BrutalColors.background,
      // Let the keyboard overlay the UI rather than reflow it: without this the
      // shell lifts the bottom nav above the keyboard (a visible "jump"), and
      // each tab's own Scaffold would then double-count the inset. The tab pages
      // set the same flag, so nothing resizes — the keyboard just sits on top.
      resizeToAvoidBottomInset: false,
      // PageView gives horizontal swipe between tabs; the bottom nav animates
      // the same controller so buttons still work.
      body: MediaQuery(
        data: mq.copyWith(
          gestureSettings: DeviceGestureSettings(
            touchSlop: baseSlop * _swipeSlopFactor,
          ),
        ),
        child: PageView(
          controller: _pageController,
          // Swiping tabs isn't a route change, so the route observer never sees
          // it — drop focus here so the keyboard retracts when the page changes.
          onPageChanged: (i) {
            dismissPrimaryFocus();
            setState(() => _index = i);
          },
          children: [
            // Keep each tab's State mounted across swipes — replicates the old
            // IndexedStack so a half-typed 記帳 entry survives a swipe-away.
            //
            // The inner MediaQuery does two root-level jobs for EVERY tab:
            //  1. restores the normal touch slop (the outer MediaQuery raised it
            //     for the swipe gesture);
            //  2. strips the keyboard's bottom view inset, so no tab's Scaffold
            //     ever resizes/reflows when the keyboard opens — it just
            //     overlays. This single spot kills the "white gap above the
            //     keyboard" for every current and future tab, so individual
            //     pages don't each need `resizeToAvoidBottomInset: false`.
            for (final page in pages)
              _KeepAliveTab(
                child: MediaQuery(
                  data: mq.copyWith(
                    viewInsets: mq.viewInsets.copyWith(bottom: 0),
                  ),
                  child: page,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _BrutalBottomNav(
        controller: _pageController,
        index: _index,
        onChanged: _goToTab,
      ),
    );
  }
}

/// Wraps a tab so its [State] survives being scrolled off-screen in the
/// [PageView] (the lazy viewport would otherwise dispose far-off pages).
class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return widget.child;
  }
}

class _BrutalBottomNav extends StatelessWidget {
  const _BrutalBottomNav({
    required this.controller,
    required this.index,
    required this.onChanged,
  });

  /// The PageView's controller — its (fractional) page drives the indicator,
  /// so the yellow pill tracks the finger during a swipe and the animated tab
  /// jump after a tap (no teleport).
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;

  /// Current page as a continuous value, falling back to [index] before the
  /// PageView has been laid out.
  double _page() {
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.page ?? index.toDouble();
    }
    return index.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem(icon: Icons.account_balance_wallet, label: 'nav_ledger'.tr()),
      _NavItem(icon: LucideIcons.receipt, label: 'nav_transaction'.tr()),
      _NavItem(icon: Icons.add_box, label: 'nav_add'.tr()),
      _NavItem(icon: Icons.group, label: 'nav_circle'.tr()),
      _NavItem(icon: Icons.account_circle, label: 'nav_account'.tr()),
    ];
    final count = items.length;

    return Container(
      decoration: const BoxDecoration(
        color: BrutalColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(BrutalSpec.cardRadius),
          topRight: Radius.circular(BrutalSpec.cardRadius),
        ),
        border: Border(
          top: BorderSide(
            color: BrutalColors.onBackground,
            width: BrutalSpec.borderWidth,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: BrutalColors.onBackground,
            offset: Offset(0, -4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        // Rebuild every frame the controller moves so the indicator follows
        // the swipe/animation continuously.
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final page = _page().clamp(0.0, (count - 1).toDouble());
            // The tab the pill is currently closest to drives the ink colour.
            final active = page.round();
            // Map page 0..count-1 onto Alignment.x -1..1 (each slot is 1/count
            // wide, so the pill lands centred on its slot).
            final alignX = count > 1 ? (page / (count - 1)) * 2 - 1 : 0.0;

            return SizedBox(
              height: 54,
              child: Stack(
                children: [
                  // Sliding yellow indicator, drawn behind the icons.
                  Align(
                    alignment: Alignment(alignX, 0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / count,
                      heightFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Container(
                          decoration: brutalDecoration(
                            color: BrutalColors.primaryContainer,
                            radius: BrutalSpec.pillRadius,
                            offset: 2,
                            borderWidth: BrutalSpec.borderWidthThin,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tappable icon + label cells on top of the indicator.
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            selected: i == active,
                            onTap: () => onChanged(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? BrutalColors.onPrimaryContainer
        : BrutalColors.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: BrutalText.labelBold(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
