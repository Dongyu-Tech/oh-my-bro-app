import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:heymybro/shared/pages/join_room_sheet.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// Full-page "enter a room code to join".
///
/// 首頁 now opens [showJoinRoomSheet] instead of pushing here, but the `/join`
/// route is kept because its path mirrors the invite link
/// (`https://ohmybro.app/join/<code>`) and is where a deep link should land.
/// The form itself lives in [JoinRoomForm] so both entry points stay identical.
class JoinRoomPage extends ConsumerWidget {
  const JoinRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        child: DottedBackdrop(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                child: Row(
                  children: [
                    const BrutalBackButton(),
                    const SizedBox(width: 12),
                    Text(
                      'join_title'.tr(),
                      style: BrutalText.headlineLgMobile(fontSize: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  children: [
                    SizedBox(
                      height: 120,
                      child: Center(
                        child: Image.asset(
                          'assets/mascot/stickers/01_main-pointing.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    JoinRoomForm(
                      onJoined: (groupId) =>
                          context.pushReplacement('/group/$groupId/room'),
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
