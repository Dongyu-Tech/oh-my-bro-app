import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rough Comic Neo-Brutalism design tokens — mirrors
/// `assets/page_reference/ledger.html` (tailwind config).
abstract class BrutalColors {
  // Surfaces
  static const background = Color(0xFFFFF8F1);
  static const surface = Color(0xFFFFF8F1);
  static const surfaceContainerLow = Color(0xFFFFF2D9);
  static const surfaceContainer = Color(0xFFFFECC1);
  static const surfaceContainerHigh = Color(0xFFFCE6B1);
  static const surfaceContainerHighest = Color(0xFFF6E1AB);
  static const surfaceVariant = Color(0xFFF6E1AB);

  // Primary (yellow) family
  static const primaryContainer = Color(
    0xFFFFD23F,
  ); // main yellow card / button
  static const primaryFixedDim = Color(0xFFEDC22E); // bright gold: fills/hover
  static const primary = Color(0xFF745C00);

  /// Income / positive-amount TEXT. Bright [primaryFixedDim] is gold-on-gold
  /// against the warm light surfaces (card = [surfaceContainerHighest]), so
  /// amount text uses this deep gold instead (~5:1 on the gold card).
  static const incomeInk = Color(0xFF745C00);

  // Ink / text on warm background
  static const onBackground = Color(0xFF241A00);
  static const onSurfaceVariant = Color(0xFF4D4634);
  static const onPrimaryContainer = Color(0xFF725A00);
  static const outline = Color(0xFF7F7661);

  // Status
  static const secondary = Color(0xFFB71422); // expense red
  static const dangerBanner = Color(0xFFFF4D4D); // vivid red banner
  static const onError = Color(0xFFFFFFFF);
  static const success = Color(
    0xFF4ADE80,
  ); // income / success green (DESIGN.md)

  // Aliases kept for legacy callers (so existing imports keep compiling)
  static const cream = background;
  static const yellow = primaryContainer;
  static const yellowDeep = primaryFixedDim;
  static const red = dangerBanner;
  static const greenInk = incomeInk;
  static const redInk = secondary;
  static const ink = onBackground;
  static const muted = onSurfaceVariant;
  static const purple = Color(0xFF6E5BD0);
}

/// Visual rhythm tokens kept consistent across the brutalism components.
abstract class BrutalSpec {
  static const double cardRadius = 12; // tailwind rounded-xl = 0.75rem
  static const double pillRadius = 8; // tailwind rounded-lg = 0.5rem
  static const double borderWidth = 4; // CSS: border: 4px
  static const double borderWidthThin = 2; // sub-icons
  static const double shadowOffset = 6; // CSS: 6px 6px 0 0
  static const double shadowOffsetMobile = 4;
  static const double shadowOffsetPressed = 2;
  static const Duration pressDuration = Duration(milliseconds: 120);

  /// Minimum time the "pressed" visual must stay locked on so that a quick
  /// tap still produces a visible press → release animation cycle.
  /// Without this, onTapUp fires ~50ms after onTapDown and AnimatedContainer
  /// never has time to interpolate.
  static const Duration pressMinHold = Duration(milliseconds: 140);
}

/// Single hard-shadow box decoration shared by cards and pills.
BoxDecoration brutalDecoration({
  Color color = BrutalColors.primaryContainer,
  double radius = BrutalSpec.cardRadius,
  double offset = BrutalSpec.shadowOffset,
  double borderWidth = BrutalSpec.borderWidth,
  Color borderColor = BrutalColors.onBackground,
  Color shadowColor = BrutalColors.onBackground,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: borderWidth),
    boxShadow: offset <= 0
        ? const []
        : [
            BoxShadow(
              color: shadowColor,
              offset: Offset(offset, offset),
              blurRadius: 0,
            ),
          ],
  );
}

/// Reusable static (non-interactive) card with thick border + hard shadow.
class BrutalCard extends StatelessWidget {
  const BrutalCard({
    super.key,
    required this.child,
    this.color = BrutalColors.primaryContainer,
    this.padding = const EdgeInsets.all(20),
    this.radius = BrutalSpec.cardRadius,
    this.offset = BrutalSpec.shadowOffsetMobile,
    this.borderWidth = BrutalSpec.borderWidth,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double offset;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: color,
        radius: radius,
        offset: offset,
        borderWidth: borderWidth,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Static decorative pill (no press animation).
class BrutalPill extends StatelessWidget {
  const BrutalPill({
    super.key,
    required this.child,
    this.color = BrutalColors.surface,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.borderWidth = BrutalSpec.borderWidth,
    this.radius = BrutalSpec.pillRadius,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: brutalDecoration(
        color: color,
        radius: radius,
        offset: 0, // pill embedded inside cards — no extra shadow
        borderWidth: borderWidth,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Tappable brutalism surface that animates the press exactly like the
/// reference HTML's `.neo-brutal:hover`:
///   shadow shrinks 4px → 2px AND the box translates (2px,2px).
class PressableBrutal extends StatefulWidget {
  const PressableBrutal({
    super.key,
    required this.child,
    this.onTap,
    this.color = BrutalColors.primaryContainer,
    this.radius = BrutalSpec.pillRadius,
    this.borderWidth = BrutalSpec.borderWidth,
    this.restOffset = BrutalSpec.shadowOffsetMobile,
    this.pressedOffset = BrutalSpec.shadowOffsetPressed,
    this.padding,
    this.alignment,
    this.width,
    this.height,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final double radius;
  final double borderWidth;
  final double restOffset;
  final double pressedOffset;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final double? width;
  final double? height;

  @override
  State<PressableBrutal> createState() => _PressableBrutalState();
}

class _PressableBrutalState extends State<PressableBrutal> {
  bool _pressed = false;
  DateTime? _pressedAt;
  int _releaseToken = 0;

  void _press() {
    if (_pressed) return;
    setState(() {
      _pressed = true;
      _pressedAt = DateTime.now();
    });
  }

  void _release() {
    final token = ++_releaseToken;

    void apply() {
      if (!mounted) return;
      if (token != _releaseToken) return; // user pressed again — keep pressed
      if (!_pressed) return;
      setState(() => _pressed = false);
    }

    final elapsed = _pressedAt == null
        ? Duration.zero
        : DateTime.now().difference(_pressedAt!);
    final remaining = BrutalSpec.pressMinHold - elapsed;
    if (remaining <= Duration.zero) {
      apply();
    } else {
      Future.delayed(remaining, apply);
    }
  }

  @override
  Widget build(BuildContext context) {
    final delta = widget.restOffset - widget.pressedOffset;
    final translate = _pressed ? delta : 0.0;
    final shadow = _pressed ? widget.pressedOffset : widget.restOffset;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: BrutalSpec.pressDuration,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(translate, translate, 0),
        width: widget.width,
        height: widget.height,
        decoration: brutalDecoration(
          color: widget.color,
          radius: widget.radius,
          offset: shadow,
          borderWidth: widget.borderWidth,
        ),
        padding: widget.padding,
        alignment: widget.alignment,
        child: widget.child,
      ),
    );
  }
}

/// Highlighter-marker band drawn *behind* its child, like a felt-tip stroke
/// swiped across the lower portion of a heading. A core neo-brutalism motif —
/// reuse for any title that needs the yellow underline emphasis.
///
/// Sizes to the child (plus [padding]); the band fills the bottom
/// [heightFactor] of that box, so it scales with the text.
class MarkerHighlight extends StatelessWidget {
  const MarkerHighlight({
    super.key,
    required this.child,
    this.color = BrutalColors.primaryContainer,
    this.heightFactor = 0.45,
    this.padding = const EdgeInsets.only(left: 2, right: 10),
  });

  final Widget child;
  final Color color;

  /// Fraction of the box height the band covers, anchored to the bottom.
  final double heightFactor;

  /// Extra space around the child; the band also covers this, so a little
  /// right padding makes the stroke "overshoot" past the text like a marker.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: heightFactor,
              child: Container(color: color),
            ),
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    );
  }
}

/// Thick brutal horizontal rule — the design system's `<hr>`. A hard black
/// bar for separating sections; reuse anywhere a divider is needed.
class BrutalDivider extends StatelessWidget {
  const BrutalDivider({
    super.key,
    this.thickness = BrutalSpec.borderWidth,
    this.color = BrutalColors.onBackground,
    this.margin = const EdgeInsets.symmetric(vertical: 16),
  });

  final double thickness;
  final Color color;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: thickness,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(thickness / 2),
      ),
    );
  }
}

/// Loading-placeholder that gently pulses between two warm surface shades.
/// Keeps the brutalist look (opaque, hard border, no blur) — use while real
/// content (avatars, list rows) is still loading.
class BrutalSkeleton extends StatefulWidget {
  const BrutalSkeleton({
    super.key,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.radius = BrutalSpec.pillRadius,
    this.borderWidth = BrutalSpec.borderWidth,
  });

  final double? width;
  final double? height;
  final BoxShape shape;
  final double radius;
  final double borderWidth;

  @override
  State<BrutalSkeleton> createState() => _BrutalSkeletonState();
}

class _BrutalSkeletonState extends State<BrutalSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = widget.shape == BoxShape.circle;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(
          BrutalColors.surfaceContainer,
          BrutalColors.surfaceContainerHighest,
          _controller.value,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            shape: widget.shape,
            borderRadius: isCircle
                ? null
                : BorderRadius.circular(widget.radius),
            border: Border.all(
              color: BrutalColors.onBackground,
              width: widget.borderWidth,
            ),
          ),
        );
      },
    );
  }
}

/// Typography helpers. Mirrors the HTML's font roles 1:1 so swapping a
/// design system update is local to this file.
abstract class BrutalText {
  /// CJK glyph fallback. The roles below all use Latin-only fonts (Bricolage
  /// Grotesque, Space Grotesk, Plus Jakarta Sans carry no Chinese glyphs), so
  /// Chinese characters would otherwise hit a platform fallback that often
  /// defaults to Japanese-variant glyphs (e.g. 帳). Pinning Noto Sans TC forces
  /// consistent Traditional-Chinese glyphs for every string through BrutalText.
  static final List<String> _cjkFallback = [
    GoogleFonts.notoSansTc().fontFamily!,
  ];

  static TextStyle display({Color? color, double fontSize = 48}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: fontSize * -0.04,
        height: 1.1,
        color: color ?? BrutalColors.onBackground,
      ).copyWith(fontFamilyFallback: _cjkFallback);

  static TextStyle headlineLgMobile({
    Color? color,
    double fontSize = 28,
    FontWeight weight = FontWeight.w900,
  }) => GoogleFonts.bricolageGrotesque(
    fontSize: fontSize,
    fontWeight: weight,
    height: 1.2,
    color: color ?? BrutalColors.onBackground,
  ).copyWith(fontFamilyFallback: _cjkFallback);

  static TextStyle labelBold({
    Color? color,
    double fontSize = 14,
    FontWeight weight = FontWeight.w700,
    double? letterSpacing,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    fontWeight: weight,
    height: 1.2,
    letterSpacing: letterSpacing,
    color: color ?? BrutalColors.onBackground,
  ).copyWith(fontFamilyFallback: _cjkFallback);

  static TextStyle body({
    Color? color,
    double fontSize = 18,
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: weight,
    height: 1.6,
    color: color ?? BrutalColors.onBackground,
  ).copyWith(fontFamilyFallback: _cjkFallback);
}

/// Decorative diagonal-striped band drawn on the top edge of the page.
/// Recolored to match the warm-cream palette (ink hatch on cream).
class StripedBand extends StatelessWidget {
  const StripedBand({
    super.key,
    this.height = 14,
    this.color = BrutalColors.onBackground,
    this.background = BrutalColors.surfaceContainerHigh,
    this.spacing = 10,
    this.stroke = 4,
  });

  final double height;
  final double spacing;
  final double stroke;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _StripedPainter(
          color: color,
          background: background,
          spacing: spacing,
          stroke: stroke,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StripedPainter extends CustomPainter {
  _StripedPainter({
    required this.color,
    required this.background,
    required this.spacing,
    required this.stroke,
  });

  final Color color;
  final Color background;
  final double spacing;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, bg);

    final line = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;

    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }

    final base = Paint()
      ..color = BrutalColors.onBackground
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      base,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedPainter old) =>
      old.color != color ||
      old.background != background ||
      old.spacing != spacing ||
      old.stroke != stroke;
}

/// Background dot grid matching HTML's `.dot-pattern`:
///   radial-gradient(#111111 2px, transparent 2px) / 24px 24px / opacity 0.05.
///
/// Set [animate] to let the grid drift toward the bottom-left in a seamless
/// loop. The animated path lays the dots out as a diamond (菱形) lattice —
/// alternate rows are offset half a cell — and one cycle shifts the field by
/// exactly `2×[spacing]` on each axis, which is the lattice's repeat vector, so
/// the loop has no visible seam. The static (default) path renders identically
/// to before — a plain square grid — so other screens are untouched.
class DottedBackdrop extends StatefulWidget {
  const DottedBackdrop({
    super.key,
    required this.child,
    this.dotColor = const Color(0x0D111111), // ~5% opacity
    this.spacing = 24,
    this.dotRadius = 2,
    this.animate = false,
    this.animateDuration = const Duration(seconds: 8),
  });

  final Widget child;
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  /// When true, the dot grid drifts toward the bottom-left, looping forever.
  final bool animate;

  /// Time for one full drift loop. The diamond lattice repeats every two cells,
  /// so a loop covers `2×[spacing]` per axis. Lower = faster.
  final Duration animateDuration;

  @override
  State<DottedBackdrop> createState() => _DottedBackdropState();
}

class _DottedBackdropState extends State<DottedBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _startTicker();
  }

  void _startTicker() {
    _controller = AnimationController(
      vsync: this,
      duration: widget.animateDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant DottedBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.animate && _controller == null) {
      _startTicker();
    } else if (!widget.animate && _controller != null) {
      _controller!.dispose();
      _controller = null;
    } else if (_controller != null &&
        widget.animateDuration != old.animateDuration) {
      _controller!.duration = widget.animateDuration;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Static path: reuse the original painter untouched.
    if (controller == null) {
      return CustomPaint(
        painter: _DotPainter(
          color: widget.dotColor,
          spacing: widget.spacing,
          radius: widget.dotRadius,
        ),
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 向左下: x drifts negative (left), y drifts positive (down). One loop
        // travels 2×spacing — the diamond lattice's repeat vector — so the end
        // of the cycle lands back on the start with no seam.
        final shift = controller.value * 2 * widget.spacing;
        return CustomPaint(
          painter: _DriftingDotPainter(
            color: widget.dotColor,
            spacing: widget.spacing,
            radius: widget.dotRadius,
            offset: Offset(-shift, shift),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.color != color || old.spacing != spacing || old.radius != radius;
}

/// Dot field for the animated backdrop, translated by [offset] and laid out as
/// a diamond (菱形) lattice: every odd row is nudged half a cell in x, so each
/// dot sits between the two above it and the four nearest neighbours form a
/// rhombus rather than a square.
///
/// Rows/cols are walked by absolute lattice index (not draw order) so a row's
/// odd/even parity — hence its half-cell stagger — stays pinned to the lattice
/// as the whole field drifts. One extra ring of cells past every edge keeps the
/// borders filled while dots scroll in and out.
class _DriftingDotPainter extends CustomPainter {
  _DriftingDotPainter({
    required this.color,
    required this.spacing,
    required this.radius,
    required this.offset,
  });

  final Color color;
  final double spacing;
  final double radius;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final firstRow = ((-spacing - offset.dy) / spacing).floor();
    final lastRow = ((size.height + spacing - offset.dy) / spacing).ceil();
    for (int row = firstRow; row <= lastRow; row++) {
      final y = row * spacing + offset.dy;
      // Odd rows step half a cell right → the diamond stagger.
      final rowShift = (row.isOdd ? spacing / 2 : 0) + offset.dx;
      final firstCol = ((-spacing - rowShift) / spacing).floor();
      final lastCol = ((size.width + spacing - rowShift) / spacing).ceil();
      for (int col = firstCol; col <= lastCol; col++) {
        canvas.drawCircle(Offset(col * spacing + rowShift, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DriftingDotPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.radius != radius ||
      old.offset != offset;
}
