import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Grains converge from a loose cloud into the child, then the child resolves.
/// Set [reverse] to blow the child away as dust instead.
class Grains extends StatefulWidget {
  Grains({
    super.key,
    required this.child,
    Color? color,
    this.reverse = false,
    this.duration = const Duration(milliseconds: 750),
    this.onDone,
  }) : color = color ?? Dissolve.fg;
  final Widget child;
  final Color color;
  final bool reverse;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<Grains> createState() => _GrainsState();
}

class _GrainsState extends State<Grains> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration)
    ..forward().whenComplete(() => widget.onDone?.call());
  final _seed = math.Random().nextInt(1 << 20);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final t = widget.reverse ? 1 - _c.value : _c.value;
      final show = Curves.easeOut.transform(((t - .45) / .55).clamp(0, 1));
      return CustomPaint(
        foregroundPainter: _GrainPainter(
          t: t,
          seed: _seed,
          color: widget.color,
          reverse: widget.reverse,
        ),
        child: Opacity(
          opacity: show,
          child: Transform.translate(
            offset: Offset(0, (1 - show) * 6),
            child: child,
          ),
        ),
      );
    },
    child: widget.child,
  );
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({
    required this.t,
    required this.seed,
    required this.color,
    required this.reverse,
  });
  final double t;
  final int seed;
  final Color color;
  final bool reverse;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final r = math.Random(seed);
    final n = (size.width * size.height / 55).clamp(40, 520).toInt();
    final p = Paint();
    for (var i = 0; i < n; i++) {
      final home = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final drift = reverse
          ? Offset(40 + r.nextDouble() * 120, -20 - r.nextDouble() * 60)
          : Offset((r.nextDouble() - .5) * 140, (r.nextDouble() - .5) * 90);
      final delay = reverse ? home.dx / size.width * .35 : r.nextDouble() * .3;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(local);
      final pos = home + drift * (1 - e);
      final fade = local < .85 ? math.min(1.0, local * 3) : (1 - local) / .15;
      p.color = color.withValues(alpha: .75 * fade.clamp(0, 1));
      canvas.drawCircle(pos, .6 + r.nextDouble() * .9, p);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter o) => o.t != t;
}

/// Text that decodes into place: letters scramble then land one by one.
class TextScramble extends StatefulWidget {
  const TextScramble(this.text, {super.key, this.style, this.speed = 28});
  final String text;
  final TextStyle? style;
  final int speed;

  @override
  State<TextScramble> createState() => _TextScrambleState();
}

class _TextScrambleState extends State<TextScramble>
    with SingleTickerProviderStateMixin {
  static const _glyphs = '!<>-_\\/[]{}—=+*^?#ABCDEFabcdef0123456789';
  late final Ticker _ticker = createTicker(_tick);
  final _r = math.Random();
  String _shown = '';
  Duration _start = Duration.zero;
  bool _reset = true;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didUpdateWidget(TextScramble old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _reset = true;
      if (!_ticker.isActive) _ticker.start();
    }
  }

  void _tick(Duration now) {
    if (_reset) {
      _start = now;
      _reset = false;
    }
    final ms = (now - _start).inMilliseconds;
    final landed = ms ~/ widget.speed;
    final b = StringBuffer();
    for (var i = 0; i < widget.text.length; i++) {
      final ch = widget.text[i];
      b.write(i < landed - 4 || ch == ' '
          ? ch
          : _glyphs[_r.nextInt(_glyphs.length)]);
    }
    setState(() => _shown = b.toString());
    if (landed - 4 >= widget.text.length) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(_shown, style: widget.style, maxLines: 1, overflow: TextOverflow.fade);
}

/// Three waving dots.
class TypingDots extends StatefulWidget {
  TypingDots({super.key, Color? color}) : color = color ?? Dissolve.muted;
  final Color color;
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Builder(builder: (_) {
            final w = math.sin((_c.value - i * .16) * 2 * math.pi);
            final up = math.max(0.0, w);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: 5,
              transform: Matrix4.translationValues(0, -up * 4, 0),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: .35 + .65 * up),
                shape: BoxShape.circle,
              ),
            );
          }),
      ],
    ),
  );
}

/// Tactile pill lit from the inside: gradient stroke, inner light and ring,
/// presses down on a crisp spring.
class GlossyButton extends StatefulWidget {
  const GlossyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.size = 44,
    this.enabled = true,
  });
  final Widget child;
  final VoidCallback onPressed;

  /// Icon/spinner color on the button face.
  static Color get ink => Dissolve.light ? Colors.white : const Color(0xFF0B0B10);
  final double size;
  final bool enabled;

  @override
  State<GlossyButton> createState() => _GlossyButtonState();
}

class _GlossyButtonState extends State<GlossyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        if (on) {
          HapticFeedback.selectionClick();
          widget.onPressed();
        }
      },
      child: AnimatedScale(
        scale: _down ? .9 : 1,
        duration: Duration(milliseconds: _down ? 90 : 380),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: on ? 1 : .4,
          child: Container(
            width: widget.size,
            height: widget.size,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: Dissolve.light
                    ? const [Color(0xFF8A8DA6), Color(0xFF111118)]
                    : const [Color(0xFFFFFFFF), Color(0x33FFFFFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Dissolve.accent.withValues(alpha: Dissolve.light ? .4 : .33),
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: Offset(0, Dissolve.light ? 6 : 0),
                ),
              ],
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, -.7),
                  radius: 1.1,
                  colors: Dissolve.light
                      ? const [Color(0xFF4A4C60), Color(0xFF1F2030), Color(0xFF0B0B10)]
                      : const [Color(0xFFFFFFFF), Color(0xFFD9DBE6), Color(0xFF9EA1B4)],
                  stops: const [0, .55, 1],
                ),
              ),
              child: IconTheme(
                data: IconThemeData(color: GlossyButton.ink, size: 20),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Copy icon breaks into grains that reform as a check.
class CopyButton extends StatefulWidget {
  const CopyButton({super.key, required this.text});
  final String text;
  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  int _burst = 0;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.lightImpact();
    setState(() {
      _copied = true;
      _burst++;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _copy,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox.square(
        dimension: 16,
        child: _burst == 0
            ? Icon(Icons.copy_rounded, size: 14, color: Dissolve.muted)
            : Grains(
                key: ValueKey((_burst, _copied)),
                color: _copied ? Dissolve.success : Dissolve.muted,
                duration: const Duration(milliseconds: 450),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 14,
                  color: _copied ? Dissolve.success : Dissolve.muted,
                ),
              ),
      ),
    ),
  );
}

/// An endless row that scrolls on its own; touching it pauses.
class Marquee extends StatefulWidget {
  const Marquee({super.key, required this.children, this.speed = 28});
  final List<Widget> children;
  final double speed;
  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  final _key = GlobalKey();
  double _x = 0;
  Duration _last = Duration.zero;
  bool _held = false;

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_held) return;
    final w = _key.currentContext?.size?.width ?? 0;
    if (w == 0) return;
    setState(() => _x = (_x + widget.speed * dt) % w);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget row([Key? k]) => Row(key: k, mainAxisSize: MainAxisSize.min, children: widget.children);
    return Listener(
      onPointerDown: (_) => _held = true,
      onPointerUp: (_) => _held = false,
      onPointerCancel: (_) => _held = false,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0, .1, .9, 1],
        ).createShader(r),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: Transform.translate(
              offset: Offset(-_x, 0),
              child: Row(children: [row(_key), row(), row()]),
            ),
          ),
        ),
      ),
    );
  }
}
