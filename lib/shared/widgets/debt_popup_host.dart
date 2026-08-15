import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/routing/router.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';

/// Sits above the router and owns two things no screen can.
///
/// First, the debt sync: the realtime subscription and the catch-up fetch live
/// here because a proposal has to arrive whichever of the four tabs you happen
/// to be on, and cold start / resume are app-level events, not page ones.
///
/// Second, opening the confirm page — one proposal at a time, never while you
/// are typing.
class DebtPopupHost extends ConsumerStatefulWidget {
  const DebtPopupHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DebtPopupHost> createState() => _DebtPopupHostState();
}

class _DebtPopupHostState extends ConsumerState<DebtPopupHost>
    with WidgetsBindingObserver {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The second delivery layer. Realtime is what makes this instant; coming
    // back from the background is what makes a dropped socket mean "late"
    // rather than "never" — and it is what puts the newest proposal on screen
    // the moment the app is reopened.
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(debtServiceProvider).refresh());
    }
  }

  /// True while a text field holds focus. Stealing the keyboard mid-sentence
  /// to ask about someone else's debt is a genuinely infuriating thing for an
  /// app to do, so the page waits for the field to be let go.
  bool get _typing {
    final focus = FocusManager.instance.primaryFocus;
    return focus != null && focus is! FocusScopeNode;
  }

  void _onFocusChanged() {
    if (!_typing) _maybeShow();
  }

  void _maybeShow() {
    if (_showing || _typing || !mounted) return;
    final proposal = ref.read(nextPopupProvider);
    if (proposal == null) return;

    _showing = true;
    unawaited(_present(proposal));
  }

  Future<void> _present(DebtProposal proposal) async {
    try {
      // Pushed through GoRouter rather than a local Navigator: this widget
      // wraps the router's output, so it sits ABOVE the navigator and cannot
      // reach it with Navigator.of.
      await ref.read(routerProvider).push<void>('/debt/${proposal.id}');
    } finally {
      _showing = false;
      // Marked however it closed — answered, backed out of, swiped away. It
      // stays in 待確認 either way; what it must not do is reopen itself on
      // every launch until answered.
      await ref.read(debtServiceProvider).markPopped(proposal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reading the service is what starts the subscription and the first fetch.
    ref.watch(debtServiceProvider);

    // Watched rather than listened to, so a proposal already queued on the
    // very first build is caught too — a listener only fires on a change, and
    // opening the app to something already waiting is the common case.
    // Presenting is deferred a frame because pushing a route mid-build is not
    // allowed; _maybeShow's guards make the repeat calls harmless.
    if (ref.watch(nextPopupProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }

    return widget.child;
  }
}
