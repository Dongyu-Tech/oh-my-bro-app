import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Cover-colour choices for a new group (from the brutalism palette).
const _coverColors = <Color>[
  BrutalColors.primaryContainer,
  BrutalColors.purple,
  BrutalColors.success,
  BrutalColors.secondary,
  BrutalColors.primaryFixedDim,
];

/// Create-a-circle screen: name it, pick a cover colour, add members (plain
/// names — no account needed), then create and jump into the group.
class NewGroupPage extends ConsumerStatefulWidget {
  const NewGroupPage({super.key});

  @override
  ConsumerState<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends ConsumerState<NewGroupPage> {
  final _nameController = TextEditingController();
  final _memberController = TextEditingController();
  // Members to add: a name plus an optional linked friend id.
  final _members = <({String name, String? friendId})>[];
  int _colorIndex = 0;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _members.add((name: name, friendId: null));
      _memberController.clear();
    });
  }

  void _toggleFriend(Friend friend) {
    setState(() {
      final i = _members.indexWhere((m) => m.friendId == friend.id);
      if (i >= 0) {
        _members.removeAt(i);
      } else {
        _members.add((name: friend.name, friendId: friend.id));
      }
    });
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showErrorSnakeBar('group_name_required'.tr());
      return;
    }
    setState(() => _creating = true);
    final id = await ref
        .read(groupServiceProvider)
        .createGroup(
          name: name,
          colorValue: _coverColors[_colorIndex].toARGB32(),
          members: _members,
        );
    // Land on the invite room (big code + QR) —揪人 first, then split.
    if (mounted) context.pushReplacement('/group/$id/room');
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).asData?.value ?? const [];
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                child: Row(
                  children: [
                    const BrutalBackButton(),
                    const SizedBox(width: 12),
                    Text(
                      'group_new'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _Label('group_name_label'.tr()),
                    _Field(
                      controller: _nameController,
                      hint: 'group_name_hint'.tr(),
                    ),
                    const SizedBox(height: 18),
                    _Label('group_color_label'.tr()),
                    Row(
                      children: [
                        for (var i = 0; i < _coverColors.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () => setState(() => _colorIndex = i),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: brutalDecoration(
                                  color: _coverColors[i],
                                  radius: BrutalSpec.pillRadius,
                                  offset: _colorIndex == i ? 3 : 0,
                                  borderWidth: _colorIndex == i
                                      ? BrutalSpec.borderWidth
                                      : BrutalSpec.borderWidthThin,
                                ),
                                child: _colorIndex == i
                                    ? const Icon(LucideIcons.check, size: 20)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _Label('group_members_label'.tr()),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        BrutalPill(
                          color: BrutalColors.primaryContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: Text(
                            'group_me'.tr(),
                            style: BrutalText.labelBold(fontSize: 14),
                          ),
                        ),
                        for (var i = 0; i < _members.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _members.removeAt(i)),
                            child: BrutalPill(
                              color: _members[i].friendId != null
                                  ? BrutalColors.surfaceContainerHigh
                                  : BrutalColors.surface,
                              padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_members[i].friendId != null) ...[
                                    const Icon(LucideIcons.user, size: 13),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    _members[i].name,
                                    style: BrutalText.labelBold(fontSize: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(LucideIcons.x, size: 15),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _memberController,
                            hint: 'group_add_member_hint'.tr(),
                            onSubmitted: (_) => _addMember(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PressableBrutal(
                          onTap: _addMember,
                          color: BrutalColors.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text(
                            'group_add_member'.tr(),
                            style: BrutalText.labelBold(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    if (friends.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Label('group_pick_friends'.tr()),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in friends)
                            GestureDetector(
                              onTap: () => _toggleFriend(f),
                              child: BrutalPill(
                                color: _members.any((m) => m.friendId == f.id)
                                    ? BrutalColors.primaryContainer
                                    : BrutalColors.surface,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.user, size: 13),
                                    const SizedBox(width: 5),
                                    Text(
                                      f.name,
                                      style: BrutalText.labelBold(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: PressableBrutal(
                  onTap: _creating ? null : _create,
                  color: BrutalColors.primaryContainer,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(
                    'group_create'.tr(),
                    style: BrutalText.labelBold(fontSize: 17),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: BrutalText.labelBold(
        fontSize: 14,
        color: BrutalColors.onSurfaceVariant,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.pillRadius,
        offset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        cursorColor: BrutalColors.onBackground,
        style: BrutalText.body(fontSize: 16),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: BrutalText.body(
            fontSize: 16,
            color: BrutalColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
