import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/pages/debt_pending_section.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Sits above the router and owns two things a screen cannot.
///
/// First, the debt sync: the realtime subscription and the catch-up fetch live
/// here because a proposal has to arrive whichever of the four tabs you happen
/// to be on, and cold start / resume are app-level events, not page ones.
///
/// Second, the popup itself — one proposal at a time, never while you are
/// typing.
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
    // rather than "never".
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(debtServiceProvider).refresh());
    }
  }

  /// True while a text field holds focus. Stealing the keyboard mid-sentence
  /// to ask about someone else's debt is a genuinely infuriating thing for an
  /// app to do, so the popup waits for the field to be let go.
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
    if (!mounted) {
      _showing = false;
      return;
    }
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _DebtPopupSheet(proposal: proposal),
      );
    } finally {
      _showing = false;
      // Marked however it closed — answered, dismissed, or swiped away. It
      // stays in 待確認 either way; what it must not do is pop again on every
      // launch until answered.
      await ref.read(debtServiceProvider).markPopped(proposal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reading the service is what starts the subscription and the first fetch.
    ref.watch(debtServiceProvider);

    // Watched rather than listened to, so a proposal already queued on the
    // very first build is caught too — a listener only fires on a change, and
    // cold start with something already waiting is the common case.
    // Presenting is deferred a frame because showing a route mid-build is not
    // allowed; _maybeShow's guards make the repeat calls harmless.
    if (ref.watch(nextPopupProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }

    return widget.child;
  }
}

class _DebtPopupSheet extends ConsumerWidget {
  const _DebtPopupSheet({required this.proposal});

  final DebtProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BrutalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'debt_popup_title'.tr(
              namedArgs: {'name': proposal.otherName ?? '?'},
            ),
            style: BrutalText.headlineLgMobile(fontSize: 22),
          ),
          const SizedBox(height: 16),
          DebtProposalLine(proposal: proposal),
          const SizedBox(height: 18),
          // The same buttons the ledger card uses, so the two can never drift
          // apart in behaviour.
          DebtActionRow(
            proposal: proposal,
            onDone: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(
              'debt_popup_later'.tr(),
              style: BrutalText.labelBold(
                fontSize: 14,
                color: BrutalColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
