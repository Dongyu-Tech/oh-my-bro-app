import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:heymybro/core/error/error_logger.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The 記帳 entry flow, hosted as the bottom-nav "+" tab inside [AppShell]'s
/// IndexedStack (a regular switchable tab, not a pushed route).
///
/// Drives a single [_EntryStatus] state machine; the mascot 粗哥 at the top
/// swaps sticker per status and voices a line in plain bold text. Below it a
/// frameless 誰欠誰 owe-selector sets the debt direction, then the body morphs
/// through: free-text input → AI analysis (skeleton) → parsed verdict card →
/// 「記帳！」. After recording, [onRecorded] asks the shell to switch back to
/// the ledger tab.
///
/// **Mockup only.** The "AI" step is a hardcoded 2-second [Future.delayed] that
/// always yields the same fake result. Wire a real parser into [_runAnalysis]
/// (return a `Result<ParsedEntry>`) and a Drift insert into [_record] when the
/// backend lands — the status/layout wiring stays the same.
class NewTransactionPage extends StatefulWidget {
  const NewTransactionPage({super.key, required this.onRecorded});

  /// Called once 粗哥 finishes "eating" so the host shell can leave this tab
  /// (e.g. jump back to the ledger).
  final VoidCallback onRecorded;

  @override
  State<NewTransactionPage> createState() => _NewTransactionPageState();
}

/// The 記帳 lifecycle. Each value maps to one mascot sticker (see [_mascotAsset]).
enum _EntryStatus {
  /// Waiting for the user to type / dictate the expense. → 07_weird-bill
  waitingInput,

  /// AI is parsing the free text. → 02_thinking
  analyzing,

  /// Parse succeeded; verdict card is filled. → 03_success
  success,

  /// 「記帳！」pressed; saving + chowing down before we pop. → 09_eating
  recording,
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _controller = TextEditingController();
  _EntryStatus _status = _EntryStatus.waitingInput;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _mascotAsset(_EntryStatus status) {
    switch (status) {
      case _EntryStatus.waitingInput:
        return 'assets/mascot/stickers/07_weird-bill.png';
      case _EntryStatus.analyzing:
        return 'assets/mascot/stickers/02_thinking.png';
      case _EntryStatus.success:
        return 'assets/mascot/stickers/03_success.png';
      case _EntryStatus.recording:
        return 'assets/mascot/stickers/09_eating.png';
    }
  }

  String _caption(_EntryStatus status) {
    switch (status) {
      case _EntryStatus.waitingInput:
        return 'new_tx_status_input'.tr();
      case _EntryStatus.analyzing:
        return 'new_tx_status_thinking'.tr();
      case _EntryStatus.success:
        return 'new_tx_status_success'.tr();
      case _EntryStatus.recording:
        return 'new_tx_status_eating'.tr();
    }
  }

  /// Confirm pressed → kick off the (fake) AI analysis. Hides the confirm
  /// button, shows the skeleton verdict card, then resolves to [success].
  Future<void> _runAnalysis() async {
    FocusScope.of(context).unfocus();
    setState(() => _status = _EntryStatus.analyzing);

    // TODO: replace with a real parser returning Result<ParsedEntry>.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _status = _EntryStatus.success);
  }

  /// 「記帳！」pressed → let 粗哥 eat for a beat, ask the shell to swipe back
  /// to the ledger, then reset the form off-screen (this tab stays alive in the
  /// PageView, so the reset must not be visible mid-slide).
  Future<void> _record() async {
    setState(() => _status = _EntryStatus.recording);

    // TODO: persist the parsed entry to Drift here.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Start sliding away while 粗哥 is still eating.
    widget.onRecorded();

    // Wait for the swipe to finish, then reset for next time off-screen.
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() {
      _status = _EntryStatus.waitingInput;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: SafeArea(
        bottom: false,
        child: DottedBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Left-aligned tab title, mirroring the other bottom-nav tabs.
              Align(
                alignment: Alignment.centerLeft,
                child: MarkerHighlight(
                  child: Text(
                    'new_tx_title'.tr(),
                    style: BrutalText.headlineLgMobile(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Mascot(asset: _mascotAsset(_status)),
              const SizedBox(height: 12),
              _Caption(text: _caption(_status)),
              const SizedBox(height: 20),
              _InputCard(
                controller: _controller,
                enabled: _status == _EntryStatus.waitingInput,
                onMic: comingSoon,
              ),
              const SizedBox(height: 16),
              // 誰欠誰 composer — tap chips to build the debt sentence; leave
              // empty for a personal entry.
              const _OweComposer(),
              const SizedBox(height: 20),
              // Confirm — full width, disappears once analysis starts.
              if (_status == _EntryStatus.waitingInput)
                _WideButton(
                  label: 'new_tx_analyze'.tr(),
                  icon: LucideIcons.sparkles,
                  onTap: _runAnalysis,
                ),
              // Verdict card — skeleton while analyzing, filled once parsed.
              if (_status != _EntryStatus.waitingInput) ...[
                _VerifyCard(loading: _status == _EntryStatus.analyzing),
                const SizedBox(height: 20),
              ],
              // 記帳！ — appears only when the parse succeeded.
              if (_status == _EntryStatus.success ||
                  _status == _EntryStatus.recording)
                _WideButton(
                  label: 'new_tx_record'.tr(),
                  icon: LucideIcons.utensils,
                  // Ignore taps while 粗哥 is mid-bite + navigating away.
                  onTap: _status == _EntryStatus.success ? _record : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mascot 粗哥 — cross-fades between stickers as the status changes
// ---------------------------------------------------------------------------

class _Mascot extends StatelessWidget {
  const _Mascot({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Image.asset(
            asset,
            key: ValueKey(asset),
            height: 160,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// 粗哥's current line — natural bold text (no bordered bubble), cross-fading
/// as the status changes.
class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: BrutalText.body(fontSize: 17, weight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 誰欠誰 composer — a Duolingo-style word-bank. Tap the bank chips to build the
// debt "sentence": 「欠」's position picks the direction and 「我」is auto-inserted,
// so a debt is always between the user and exactly ONE friend (friend-owes-
// friend can't be composed). Compose nothing → it stays a personal entry.
// ---------------------------------------------------------------------------

/// A pickable friend in the composer bank. Sample data for the mockup; a real
/// build would stream these from the circle/friends repository.
class _Friend {
  const _Friend({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;
}

enum _TokKind { friend, owe, me }

/// One tile in the composed line.
class _Tok {
  const _Tok.owe() : kind = _TokKind.owe, friend = null;
  const _Tok.me() : kind = _TokKind.me, friend = null;
  const _Tok.friend(this.friend) : kind = _TokKind.friend;

  final _TokKind kind;
  final _Friend? friend;
}

class _OweComposer extends StatefulWidget {
  const _OweComposer();

  @override
  State<_OweComposer> createState() => _OweComposerState();
}

class _OweComposerState extends State<_OweComposer> {
  late final List<_Friend> _friends = [
    _Friend(id: 'f1', name: 'new_tx_friend1'.tr(), color: const Color(0xFF7CB3FF)),
    _Friend(id: 'f2', name: 'new_tx_friend2'.tr(), color: const Color(0xFF8FD89B)),
    _Friend(id: 'f3', name: 'new_tx_friend3'.tr(), color: const Color(0xFFF4A6C0)),
  ];

  final List<_Tok> _picked = [];

  bool get _complete => _picked.length == 3; // friend + 欠 + 我
  bool get _hasFriend => _picked.any((t) => t.kind == _TokKind.friend);
  bool get _hasOwe => _picked.any((t) => t.kind == _TokKind.owe);

  void _tapFriend(_Friend f) {
    if (_complete || _hasFriend) return;
    setState(() {
      final pendingMeOwe = _picked.length == 2 &&
          _picked[0].kind == _TokKind.me &&
          _picked[1].kind == _TokKind.owe;
      if (pendingMeOwe) {
        _picked.add(_Tok.friend(f)); // 我 → 欠 → <friend>
      } else {
        _picked
          ..clear()
          ..add(_Tok.friend(f)); // <friend> first; direction still pending
      }
    });
  }

  void _tapOwe() {
    if (_complete || _hasOwe) return;
    setState(() {
      if (_hasFriend) {
        // 欠 dropped after a friend → "<friend> 欠 我"; auto-append 我.
        _picked
          ..add(const _Tok.owe())
          ..add(const _Tok.me());
      } else {
        // 欠 dropped first → "我 欠 …"; auto-prepend 我, await the friend.
        _picked
          ..add(const _Tok.me())
          ..add(const _Tok.owe());
      }
    });
  }

  void _reset() => setState(() => _picked.clear());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'new_tx_field_who'.tr(),
          style: BrutalText.labelBold(
            color: BrutalColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _ComposedLine(picked: _picked, onReset: _reset),
        // Extra gap so the 「添加」slot reads as separate from the word bank.
        const SizedBox(height: 24),
        // Bank of word tiles.
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _WordChip(
              label: 'ledger_owes'.tr(),
              bg: BrutalColors.onBackground,
              fg: BrutalColors.primaryContainer,
              onTap: _tapOwe,
              disabled: _hasOwe || _complete,
            ),
            for (final f in _friends)
              _WordChip(
                label: f.name,
                avatar: f.name.substring(0, 1),
                avatarColor: f.color,
                onTap: () => _tapFriend(f),
                disabled: _complete || _hasFriend,
              ),
          ],
        ),
      ],
    );
  }
}

/// The assembled "sentence". Empty → a small dashed 「添加」chip (content-width,
/// not a full row); once filled, the tiles read left-to-right as the
/// relationship (e.g. 小明 欠 我). Tap the filled row to start over.
class _ComposedLine extends StatelessWidget {
  const _ComposedLine({required this.picked, required this.onReset});

  final List<_Tok> picked;
  final VoidCallback onReset;

  Widget _tokChip(_Tok t) {
    switch (t.kind) {
      case _TokKind.owe:
        return _WordChip(
          label: 'ledger_owes'.tr(),
          bg: BrutalColors.onBackground,
          fg: BrutalColors.primaryContainer,
        );
      case _TokKind.me:
        return _WordChip(
          label: 'new_tx_me'.tr(),
          avatar: 'new_tx_me'.tr(),
          avatarColor: BrutalColors.primaryContainer,
        );
      case _TokKind.friend:
        final f = t.friend!;
        return _WordChip(
          label: f.name,
          avatar: f.name.substring(0, 1),
          avatarColor: f.color,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (picked.isEmpty) return const _AddChip();
    return GestureDetector(
      onTap: onReset,
      behavior: HitTestBehavior.opaque,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [for (final t in picked) _tokChip(t)],
      ),
    );
  }
}

/// Empty-state placeholder: a compact dashed pill reading 「＋ 添加」. Flutter's
/// [Border] can't dash, so the outline is drawn by [_DashedRRectPainter].
class _AddChip extends StatelessWidget {
  const _AddChip();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        radius: BrutalSpec.pillRadius,
        color: BrutalColors.outline,
        strokeWidth: BrutalSpec.borderWidthThin,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add,
              size: 16,
              color: BrutalColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'new_tx_add'.tr(),
              style: BrutalText.labelBold(
                color: BrutalColors.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle outline sized to the painted box.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
  });

  final double radius;
  final Color color;
  final double strokeWidth;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + _dash;
        final end = next < metric.length ? next : metric.length;
        dashed.addPath(metric.extractPath(dist, end), Offset.zero);
        dist = next + _gap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// One word tile. Tappable (with press feedback) when [onTap] is set — that's a
/// bank tile; static when null — that's a tile already placed in the line.
class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.label,
    this.avatar,
    this.avatarColor,
    this.bg = BrutalColors.surface,
    this.fg,
    this.onTap,
    this.disabled = false,
  });

  final String label;
  final String? avatar;
  final Color? avatarColor;
  final Color bg;
  final Color? fg;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    // Fixed 24px content band so chips with an avatar and text-only chips
    // (e.g. 欠) end up the same height.
    final row = SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar != null) ...[
            _Avatar(
              text: avatar!,
              color: avatarColor ?? BrutalColors.primaryContainer,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: BrutalText.labelBold(
              color: fg ?? BrutalColors.onBackground,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );

    // Static tile (placed in the composed line).
    if (onTap == null) {
      return Container(
        decoration: brutalDecoration(
          color: bg,
          radius: BrutalSpec.pillRadius,
          offset: 0,
          borderWidth: BrutalSpec.borderWidthThin,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: row,
      );
    }

    // Tappable bank tile.
    final chip = PressableBrutal(
      color: bg,
      radius: BrutalSpec.pillRadius,
      borderWidth: BrutalSpec.borderWidthThin,
      restOffset: 3,
      pressedOffset: 1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: onTap,
      child: row,
    );
    return disabled ? Opacity(opacity: 0.3, child: IgnorePointer(child: chip)) : chip;
  }
}

/// Small round monogram avatar for a friend / 我 tile.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: BrutalColors.onBackground,
          width: BrutalSpec.borderWidthThin,
        ),
      ),
      alignment: Alignment.center,
      child: Text(text, style: BrutalText.labelBold(fontSize: 11)),
    );
  }
}

// ---------------------------------------------------------------------------
// Free-text input card with a mic affordance (mirrors the design reference)
// ---------------------------------------------------------------------------

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.controller,
    required this.enabled,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: BrutalSpec.cardRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            enabled: enabled,
            minLines: 3,
            maxLines: 3,
            style: BrutalText.body(fontSize: 18),
            cursorColor: BrutalColors.onBackground,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'new_tx_hint'.tr(),
              hintStyle: BrutalText.body(
                fontSize: 18,
                color: BrutalColors.outline,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Yellow round mic button anchored bottom-right.
          PressableBrutal(
            color: BrutalColors.primaryContainer,
            radius: 26,
            width: 52,
            height: 52,
            restOffset: BrutalSpec.shadowOffsetMobile,
            pressedOffset: 1,
            alignment: Alignment.center,
            onTap: onMic,
            child: const Icon(
              LucideIcons.mic,
              color: BrutalColors.onBackground,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI verdict card — skeleton while analyzing, parsed fields once resolved
// ---------------------------------------------------------------------------

class _VerifyCard extends StatelessWidget {
  const _VerifyCard({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    // Hardcoded fake parse result for the mockup.
    final friend = 'new_tx_sample_friend'.tr();
    final who = '$friend ${'ledger_owes'.tr()} ${'new_tx_you'.tr()} \$125';

    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.surfaceContainerHighest,
        radius: BrutalSpec.cardRadius,
        offset: BrutalSpec.shadowOffsetMobile,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BrutalColors.onBackground,
                  borderRadius: BorderRadius.circular(BrutalSpec.pillRadius),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.sparkles,
                  color: BrutalColors.primaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'new_tx_verify_title'.tr(),
                style: BrutalText.labelBold(fontSize: 15, letterSpacing: 0.5),
              ),
            ],
          ),
          const BrutalDivider(margin: EdgeInsets.symmetric(vertical: 14)),
          _VerifyRow(
            label: 'tx_item'.tr(),
            loading: loading,
            child: Text(
              'new_tx_sample_name'.tr(),
              style: BrutalText.headlineLgMobile(fontSize: 20),
            ),
          ),
          const SizedBox(height: 16),
          _VerifyRow(
            label: 'new_tx_field_type'.tr(),
            loading: loading,
            child: const _ExpenseBadge(),
          ),
          const SizedBox(height: 16),
          _VerifyRow(
            label: 'new_tx_field_who'.tr(),
            loading: loading,
            child: Text(who, style: BrutalText.labelBold(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

/// One label → value row in the verdict card. Swaps the value for a pulsing
/// [BrutalSkeleton] bar while the analysis is still running.
class _VerifyRow extends StatelessWidget {
  const _VerifyRow({
    required this.label,
    required this.loading,
    required this.child,
  });

  final String label;
  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: BrutalText.labelBold(
              color: BrutalColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: loading
                ? const BrutalSkeleton(
                    width: double.infinity,
                    height: 24,
                    borderWidth: BrutalSpec.borderWidthThin,
                  )
                : child,
          ),
        ),
      ],
    );
  }
}

/// Red 支出 badge reused from the transaction card visual language.
class _ExpenseBadge extends StatelessWidget {
  const _ExpenseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: BrutalColors.secondary,
        radius: BrutalSpec.pillRadius,
        offset: 0,
        borderWidth: BrutalSpec.borderWidthThin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        'ledger_expense'.tr(),
        style: BrutalText.labelBold(color: BrutalColors.onError, fontSize: 13),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-width pressable action button
// ---------------------------------------------------------------------------

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: PressableBrutal(
        color: BrutalColors.primaryContainer,
        radius: BrutalSpec.pillRadius,
        width: double.infinity,
        restOffset: BrutalSpec.shadowOffset,
        pressedOffset: BrutalSpec.shadowOffsetPressed,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: BrutalColors.onPrimaryContainer),
            const SizedBox(width: 10),
            Text(
              label,
              style: BrutalText.headlineLgMobile(
                fontSize: 20,
                color: BrutalColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
