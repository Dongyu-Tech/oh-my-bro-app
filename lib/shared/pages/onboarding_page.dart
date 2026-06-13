import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

/// First-run / signed-out gate.
///
/// Renders the comic "ROUGH BOOKIE" hero with the pointing mascot, then
/// immediately raises a bottom sheet the user can't dismiss — the only way
/// forward is signing in with Google. On success we leave onboarding for the
/// app shell ('/').
///
/// Auth is the [authServiceProvider] seam (defaults to the no-op service, which
/// returns an error). Wire a real Google Sign-In implementation there and this
/// flow lights up unchanged.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _sheetShown = false;

  @override
  void initState() {
    super.initState();
    // Raise the (non-dismissible) login sheet once the first frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLoginSheet());
  }

  Future<void> _openLoginSheet() async {
    if (_sheetShown || !mounted) return;
    _sheetShown = true;
    await showModalBottomSheet<void>(
      context: context,
      // "關不掉的" — a barrier tap, a drag-down, and the system back button all
      // can't close it (see the PopScope inside _LoginBottomSheet). Only a
      // successful sign-in pops it programmatically.
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Fully transparent barrier: the sheet must not dim/tint the hero behind
      // it. It still blocks touches to the background, but isn't dismissible.
      barrierColor: Colors.transparent,
      builder: (_) => const _LoginBottomSheet(),
    );
    _sheetShown = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalColors.background,
      body: DottedBackdrop(
        animate: true,
        dotColor: BrutalColors.yellow,
        dotRadius: 2,
        child: SafeArea(
          child: Padding(
            // Bottom inset reserves room so the mascot floats above the sheet.
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    BrutalPill(
                      color: BrutalColors.surface,
                      borderWidth: BrutalSpec.borderWidthThin,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'v1.0.0',
                        style: BrutalText.labelBold(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _BrandTitle('ROUGH BOOKIE'),
                const SizedBox(height: 18),
                _SpeechBubble(text: 'onboarding_slogan'.tr()),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/mascot/stickers/01_main-pointing.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Comic outlined wordmark: a thick ink stroke behind a yellow fill, mirroring
/// [BrutalText.display]'s font role.
class _BrandTitle extends StatelessWidget {
  const _BrandTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    const fontSize = 46.0;
    // Stroke layer. No `color` is set here so we can use `foreground` without
    // tripping TextStyle's "color + foreground" assertion.
    final strokeStyle = GoogleFonts.bricolageGrotesque(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: fontSize * -0.04,
      height: 1.1,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..color = BrutalColors.onBackground,
    );

    return Stack(
      children: [
        Text(text, style: strokeStyle),
        Text(
          text,
          style: BrutalText.display(
            fontSize: fontSize,
            color: BrutalColors.primaryContainer,
          ),
        ),
      ],
    );
  }
}

/// Tilted speech-bubble pill holding the slogan, comic-sticker style.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.rotate(
        angle: -0.02,
        child: BrutalCard(
          color: BrutalColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(text, style: BrutalText.labelBold(fontSize: 16)),
        ),
      ),
    );
  }
}

/// The "關不掉的" login sheet. Wrapped in `PopScope(canPop: false)` so the system
/// back button/gesture can't pop it either; combined with the host's
/// `isDismissible: false` / `enableDrag: false`, the sheet can only be closed
/// by [_signInWithGoogle] after a successful sign-in.
class _LoginBottomSheet extends ConsumerStatefulWidget {
  const _LoginBottomSheet();

  @override
  ConsumerState<_LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends ConsumerState<_LoginBottomSheet> {
  void _signInWithGoogle() {
    // 先暫時這樣做: skip auth and go straight to the app shell so the flow is
    // navigable without a backend. Capture the router before popping so we
    // don't read a defunct context.
    //
    // TODO(auth): swap this for the real sign-in once authServiceProvider is
    // wired (add a loading state + handle Result):
    //   switch (await ref.read(authServiceProvider).signIn()) {
    //     case Ok():
    //       final router = GoRouter.of(context);
    //       Navigator.of(context).pop();
    //       router.go('/');
    //     case Error(error: final e):
    //       showErrorSnakeBar(e.toString());
    //   }
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: BrutalColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BrutalSpec.cardRadius),
          ),
          // Uniform 4px outline on every edge. A single-side `Border(top: ...)`
          // renders an uneven-width stroke around the rounded corners, so use
          // `Border.all` for a clean, equal-width outline.
          // border: Border.all(
          // color: BrutalColors.onBackground,
          // width: BrutalSpec.borderWidth,
          // ),
          boxShadow: const [
            BoxShadow(
              color: BrutalColors.onBackground,
              offset: Offset(0, -4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'onboarding_welcome_title'.tr(),
                style: BrutalText.headlineLgMobile(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'onboarding_welcome_subtitle'.tr(),
                style: BrutalText.body(
                  fontSize: 15,
                  color: BrutalColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              _GoogleSignInButton(loading: false, onTap: _signInWithGoogle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width (`w-full`), rounded-xl, border-less ("no-outline") Google button.
/// Keeps a hard drop shadow + press translate so it still reads as a brutalism
/// control without an outline.
class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.loading) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _pressed && !widget.loading;
    final offset = pressed ? 2.0 : 4.0;
    final shift = pressed ? 2.0 : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.loading ? null : widget.onTap,
      child: AnimatedContainer(
        duration: BrutalSpec.pressDuration,
        curve: Curves.easeOut,
        height: 56,
        transform: Matrix4.translationValues(shift, shift, 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BrutalSpec.cardRadius),
          // "no-outline": no border. A hard shadow only, for the comic lift.
          boxShadow: [
            BoxShadow(
              color: BrutalColors.onBackground,
              offset: Offset(offset, offset),
              blurRadius: 0,
            ),
          ],
        ),
        child: widget.loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: BrutalColors.onBackground,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/google-icon.png',
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'onboarding_google_login'.tr(),
                    style: BrutalText.labelBold(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}
