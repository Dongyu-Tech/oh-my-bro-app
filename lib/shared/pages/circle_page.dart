import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// "夥伴" tab — your bros. Add a friend, see 粗哥's comic credit score for each
/// (how reliable they are at paying you back), and tap through to their report.
class CirclePage extends ConsumerStatefulWidget {
  const CirclePage({super.key});

  @override
  ConsumerState<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends ConsumerState<CirclePage> {
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    await ref.read(friendServiceProvider).addFriend(name);
    if (!mounted) return;
    _addCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).asData?.value ?? const [];

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
                    // Add a friend.
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: brutalDecoration(
                              color: BrutalColors.surface,
                              radius: BrutalSpec.pillRadius,
                              offset: 3,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: _addCtrl,
                              cursorColor: BrutalColors.onBackground,
                              onSubmitted: (_) => _add(),
                              style: BrutalText.body(fontSize: 16),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                border: InputBorder.none,
                                hintText: 'friend_add_hint'.tr(),
                                hintStyle: BrutalText.body(
                                  fontSize: 16,
                                  color: BrutalColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PressableBrutal(
                          onTap: _add,
                          color: BrutalColors.primaryContainer,
                          radius: BrutalSpec.pillRadius,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.userPlus, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'friend_add'.tr(),
                                style: BrutalText.labelBold(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: friends.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
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
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        children: [
                          for (final f in friends)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FriendCard(friend: f),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
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
            Container(
              width: 50,
              height: 50,
              decoration: brutalDecoration(
                color: BrutalColors.surfaceContainerHigh,
                radius: BrutalSpec.pillRadius,
                offset: 0,
                borderWidth: BrutalSpec.borderWidthThin,
              ),
              alignment: Alignment.center,
              child: Text(
                friend.name.characters.isEmpty
                    ? '?'
                    : friend.name.characters.first,
                style: BrutalText.headlineLgMobile(fontSize: 22),
              ),
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
