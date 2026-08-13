import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/models/app_user_model.dart';
import 'package:heymybro/shared/models/bro_code.dart';
import 'package:heymybro/shared/models/friendship_model.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/provider/friendship_provider.dart';
import 'package:heymybro/shared/provider/user_provider.dart';
import 'package:heymybro/shared/repositories/friendship_repository.dart';
import 'package:heymybro/shared/repositories/user_repository.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Shared height for the search pill and the 掃描 button. Both used to size
/// themselves from their own padding, which left the button a few pixels
/// shorter than the field; pinning one height is what keeps them aligned.
const double _kControlHeight = 50;

/// The square search button nested inside the search pill. Sized to clear the
/// pill's 4px border on both sides with room for its own 2px hard shadow.
const double _kInlineButtonSize = 34;

/// "夥伴" tab — your bros. Add a friend, see 粗哥's comic credit score for each
/// (how reliable they are at paying you back), and tap through to their report.
class CirclePage extends ConsumerStatefulWidget {
  const CirclePage({super.key});

  @override
  ConsumerState<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends ConsumerState<CirclePage> {
  final _addCtrl = TextEditingController();

  /// The account the last search resolved, waiting to be added.
  AppUserModel? _found;
  bool _searching = false;
  bool _notFound = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _clearResult() {
    _found = null;
    _notFound = false;
  }

  /// Look the typed handle up in `public.users`. Bros are accounts now, so this
  /// is the only way to gain one by hand — a name that matches nobody is a
  /// "not found", never a new row.
  Future<void> _search() async {
    final query = _addCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _clearResult();
    });

    final result = await ref.read(userRepositoryProvider).findByHandle(query);
    if (!mounted) return;
    setState(() => _searching = false);

    switch (result) {
      case Ok(value: final user?):
        // Adding yourself would put you in your own bro list and let you owe
        // yourself money.
        if (user.id == ref.read(myProfileProvider).asData?.value?.id) {
          showErrorSnakeBar('search_is_me'.tr());
          return;
        }
        setState(() => _found = user);
      case Ok():
        setState(() => _notFound = true);
      case Error(error: BackendNotWiredException()):
        showErrorSnakeBar('search_no_backend'.tr());
      case Error(error: final e):
        showErrorSnakeBar(e.toString());
    }
  }

  /// Search-added bros go through consent: this only *asks*. The friendship is
  /// not real until they answer, which is why the button says 邀請 and the
  /// result turns into 已送出邀請 rather than appearing in the list.
  Future<void> _request(AppUserModel user) async {
    final name = user.bestName.isEmpty ? (user.handle ?? '') : user.bestName;
    final result = await ref
        .read(friendshipRepositoryProvider)
        .request(user.id);
    if (!mounted) return;

    switch (result) {
      case Ok(value: final outcome):
        ref.invalidate(friendshipsProvider);
        setState(() {
          _addCtrl.clear();
          _clearResult();
        });
        FocusScope.of(context).unfocus();
        switch (outcome) {
          case RequestOutcome.pending:
          case RequestOutcome.unknown:
            showMessage('friend_request_sent'.tr());
          // They had already asked us, so asking back settled it on the spot.
          case RequestOutcome.accepted:
            showMessage('scan_friend_added'.tr(namedArgs: {'name': name}));
          case RequestOutcome.already:
            showMessage('friend_already'.tr());
          case RequestOutcome.self:
            showErrorSnakeBar('search_is_me'.tr());
          case RequestOutcome.notFound:
            showErrorSnakeBar('search_not_found'.tr());
        }
      case Error(error: BackendNotWiredException()):
        showErrorSnakeBar('search_no_backend'.tr());
      case Error(error: final e):
        showErrorSnakeBar(e.toString());
    }
  }

  /// Scanning skips the accept step — holding up a code that dies in minutes
  /// *is* the consent. The code carries that short-lived token and nothing
  /// else, so a forwarded screenshot is worthless once it expires.
  Future<void> _scan() async {
    FocusScope.of(context).unfocus();
    final code = await context.push<BroCode>('/scan');
    if (code == null || !mounted) return;

    final result = await ref
        .read(friendshipRepositoryProvider)
        .redeemToken(code.token);
    if (!mounted) return;

    switch (result) {
      case Ok(value: final userId) when userId != null:
        ref.invalidate(friendshipsProvider);
        showMessage('scan_added_direct'.tr());
      case Ok():
        showErrorSnakeBar('scan_code_expired'.tr());
      case Error(error: BackendNotWiredException()):
        showErrorSnakeBar('search_no_backend'.tr());
      case Error(error: final e):
        showErrorSnakeBar(e.toString());
    }
  }

  /// Pull-to-refresh: re-pulls every friendship, which is what surfaces a new
  /// invite and — because the mirror prunes — a bro who removed you.
  Future<void> _refresh() async {
    ref.invalidate(friendshipsProvider);
    try {
      // Awaited so the spinner lasts as long as the fetch actually does.
      await ref.read(friendshipsProvider.future);
    } catch (_) {
      // Two errors land here: the real fetch failure, and Riverpod's own
      // "disposed during loading" StateError, which is what `.future` reports
      // for a throwing provider in this version. Neither is worth putting on
      // screen verbatim.
      if (!mounted) return;
      showErrorSnakeBar('friend_refresh_failed'.tr());
    }
  }

  Future<void> _respond(FriendshipModel request, {required bool accept}) async {
    final result = await ref
        .read(friendshipRepositoryProvider)
        .respond(request.otherId, accept: accept);
    if (!mounted) return;

    switch (result) {
      case Ok():
        ref.invalidate(friendshipsProvider);
        showMessage(
          accept
              ? 'scan_friend_added'.tr(namedArgs: {'name': request.bestName})
              : 'friend_request_rejected'.tr(),
        );
      case Error(error: final e):
        showErrorSnakeBar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).asData?.value ?? const [];

    // Watching this is also what pulls friendships on app entry — the 夥伴 tab
    // is built with the rest of the shell, so the fetch starts at launch.
    final incoming = ref.watch(incomingRequestsProvider);
    final outgoing = ref.watch(outgoingRequestsProvider);

    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkerHighlight(
                      child: Text(
                        'friends_title'.tr(),
                        style: BrutalText.headlineLgMobile(fontSize: 30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Look a bro up by name, or scan their code.
                    SizedBox(
                      height: _kControlHeight,
                      child: Row(
                        // A Row centres its children, so the fixed-height box
                        // alone would leave the pill at its own intrinsic
                        // height (42) next to a 50-high button — the exact
                        // mismatch this row used to have. Stretch is what
                        // actually makes them equal.
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: brutalDecoration(
                                color: BrutalColors.surface,
                                radius: BrutalSpec.pillRadius,
                                offset: 3,
                              ),
                              // Tighter on the right: the search button sits
                              // inside the pill and brings its own shadow.
                              padding: const EdgeInsets.only(
                                left: 14,
                                right: 5,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '@',
                                    style: BrutalText.headlineLgMobile(
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: TextField(
                                      controller: _addCtrl,
                                      cursorColor: BrutalColors.onBackground,
                                      onSubmitted: (_) => _search(),
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textInputAction: TextInputAction.search,
                                      // A stale result card next to an edited
                                      // query reads as if it matched the new one.
                                      onChanged: (_) {
                                        if (_found != null || _notFound) {
                                          setState(_clearResult);
                                        }
                                      },
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z0-9_]'),
                                        ),
                                      ],
                                      style: BrutalText.body(fontSize: 16),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        // The pill's fixed height owns the
                                        // vertical rhythm now, so the field
                                        // adds none of its own.
                                        contentPadding: EdgeInsets.zero,
                                        border: InputBorder.none,
                                        hintText: 'friend_search_hint'.tr(),
                                        hintStyle: BrutalText.body(
                                          fontSize: 16,
                                          color: BrutalColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PressableBrutal(
                                    onTap: _searching ? null : _search,
                                    width: _kInlineButtonSize,
                                    height: _kInlineButtonSize,
                                    color: _searching
                                        ? BrutalColors.surfaceContainerHigh
                                        : BrutalColors.primaryContainer,
                                    radius: BrutalSpec.pillRadius,
                                    borderWidth: BrutalSpec.borderWidthThin,
                                    restOffset: 2,
                                    pressedOffset: 0,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      LucideIcons.search,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          PressableBrutal(
                            onTap: _scan,
                            height: _kControlHeight,
                            color: BrutalColors.primaryContainer,
                            radius: BrutalSpec.pillRadius,
                            // Match the search pill's shadow depth so the two
                            // sit on the same plane.
                            restOffset: 3,
                            pressedOffset: 1,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.scanLine, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'friend_scan'.tr(),
                                  style: BrutalText.labelBold(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_found != null) ...[
                      const SizedBox(height: 12),
                      _SearchResultCard(
                        user: _found!,
                        existing: ref.watch(relatedUserIdsProvider)[_found!.id],
                        onInvite: () => _request(_found!),
                      ),
                    ] else if (_notFound) ...[
                      const SizedBox(height: 12),
                      Text(
                        'search_not_found'.tr(),
                        style: BrutalText.labelBold(
                          fontSize: 14,
                          color: BrutalColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Everything below the search row scrolls, so pulling down
              // refreshes it — and so a stack of invites can't overflow the
              // fixed header the way it would if they lived up there.
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: BrutalColors.onBackground,
                  backgroundColor: BrutalColors.primaryContainer,
                  child: ListView(
                    // Without this a short list (or none at all) cannot be
                    // dragged, and there would be no way to trigger a refresh
                    // exactly when you most want one.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      // Requests needing an answer come first: they are the
                      // only thing on this tab that asks something of you.
                      for (final request in incoming)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _IncomingRequestCard(
                            request: request,
                            onAccept: () => _respond(request, accept: true),
                            onReject: () => _respond(request, accept: false),
                          ),
                        ),
                      if (outgoing.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 12),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.clock,
                                size: 14,
                                color: BrutalColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'friend_pending_count'.tr(
                                  namedArgs: {'count': '${outgoing.length}'},
                                ),
                                style: BrutalText.labelBold(
                                  fontSize: 12,
                                  color: BrutalColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (friends.isEmpty)
                        SizedBox(
                          height: 260,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.users,
                                  size: 64,
                                  color: BrutalColors.onBackground,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'friend_empty'.tr(),
                                  textAlign: TextAlign.center,
                                  style: BrutalText.labelBold(
                                    fontSize: 15,
                                    color: BrutalColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        for (final f in friends)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FriendCard(friend: f),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The account a handle search resolved, with the button that saves them.
/// Shown between the search row and the bro list until it is added or the
/// query changes.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.user,
    required this.onInvite,
    this.existing,
  });

  final AppUserModel user;
  final VoidCallback onInvite;

  /// Any relationship we already have with them. Offering 邀請 to someone who
  /// is already a bro — or who is already waiting on us — is a dead button.
  final FriendshipModel? existing;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.surfaceContainerLow,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          BrutalAvatar(
            name: user.bestName,
            photoUrl: user.effectiveAvatarUrl,
            size: 44,
            fontSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.bestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.headlineLgMobile(fontSize: 17),
                ),
                Text(
                  '@${user.handle ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.labelBold(
                    fontSize: 12,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (existing != null)
            Text(
              (existing!.isAccepted
                      ? 'friend_already'
                      : 'friend_request_pending')
                  .tr(),
              style: BrutalText.labelBold(
                fontSize: 13,
                color: BrutalColors.onSurfaceVariant,
              ),
            )
          else
            PressableBrutal(
              onTap: onInvite,
              color: BrutalColors.primaryContainer,
              radius: BrutalSpec.pillRadius,
              restOffset: 3,
              pressedOffset: 1,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.userPlus, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'friend_invite'.tr(),
                    style: BrutalText.labelBold(fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Someone who asked to be your bro and is waiting on an answer. Sits above
/// the bro list because it is the only thing on this tab that needs a decision.
class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final FriendshipModel request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: BrutalColors.primaryContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          BrutalAvatar(
            name: request.bestName,
            photoUrl: request.avatarUrl,
            size: 44,
            fontSize: 20,
            color: BrutalColors.surface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.bestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.headlineLgMobile(fontSize: 17),
                ),
                Text(
                  'friend_wants_to_add'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrutalText.labelBold(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PressableBrutal(
            onTap: onReject,
            color: BrutalColors.surface,
            radius: BrutalSpec.pillRadius,
            borderWidth: BrutalSpec.borderWidthThin,
            restOffset: 2,
            pressedOffset: 0,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: const Icon(LucideIcons.x, size: 18),
          ),
          const SizedBox(width: 8),
          PressableBrutal(
            onTap: onAccept,
            color: BrutalColors.surface,
            radius: BrutalSpec.pillRadius,
            restOffset: 2,
            pressedOffset: 0,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: const Icon(LucideIcons.check, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Verdict colour for a score: gold → yellow → muted → red.
Color creditColor(int score) => switch (score) {
  >= 85 => BrutalColors.incomeInk,
  >= 60 => BrutalColors.primaryFixedDim,
  >= 35 => BrutalColors.onSurfaceVariant,
  _ => BrutalColors.secondary,
};

class _FriendCard extends ConsumerWidget {
  const _FriendCard({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credit = ref.watch(friendCreditProvider(friend.id));
    final money = NumberFormat.decimalPattern();

    return GestureDetector(
      onTap: () => context.push('/friend/${friend.id}'),
      behavior: HitTestBehavior.opaque,
      child: BrutalCard(
        color: BrutalColors.surface,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // avatarUrl is cached on the row when the bro was added, so the
            // list draws their picture with no network round trip — and rows
            // added before bros were accounts simply fall back to the initial.
            BrutalAvatar(
              name: friend.name,
              photoUrl: friend.avatarUrl,
              size: 50,
              fontSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrutalText.headlineLgMobile(fontSize: 19),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    credit.outstanding > 0
                        ? '${'credit_outstanding'.tr()} \$${money.format(credit.outstanding)}'
                        : credit.verdictKey.tr(),
                    style: BrutalText.labelBold(
                      fontSize: 12,
                      color: BrutalColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${credit.score}',
                  style: BrutalText.display(
                    fontSize: 30,
                    color: creditColor(credit.score),
                  ),
                ),
                Text(
                  'credit_score'.tr(),
                  style: BrutalText.labelBold(
                    fontSize: 10,
                    color: BrutalColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
