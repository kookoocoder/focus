import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

enum OrbState { idle, thinking, searching, listening, done, error }

/// A sphere of dots that shows what the agent is doing. Port of dissolve's
/// ThinkingOrb: every state change moves each dot from where it is to its new
/// place over 600 ms, staggered.
class ThinkingOrb extends StatefulWidget {
  const ThinkingOrb({
    super.key,
    this.state = OrbState.idle,
    this.size = 64,
    this.dots = 180,
    this.dotSize = 2.5,
    this.level = 0,
    this.interactive = false,
    this.haptics = true,
    this.color,
  });

  final OrbState state;
  final double size;
  final int dots;
  final double dotSize;
  final double level;
  final bool interactive;
  final bool haptics;
  final Color? color;

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _Dot {
  Offset from = Offset.zero;
  Offset pos = Offset.zero;
  double depth = 1;
  Offset push = Offset.zero;
  Color color = Dissolve.fg;
  Color fromColor = Dissolve.fg;
}

class _ThinkingOrbState extends State<ThinkingOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  late List<_Dot> _dots;
  late List<double> _stagger;
  Duration _now = Duration.zero;
  Duration _changedAt = Duration.zero;
  Offset? _finger;

  static const _morph = 600.0;
  static const _staggerSpan = 260.0;

  @override
  void initState() {
    super.initState();
    _build();
    _ticker = createTicker(_tick)..start();
  }

  void _build() {
    final r = math.Random(7);
    _dots = List.generate(widget.dots, (_) => _Dot());
    _stagger = List.generate(widget.dots, (_) => r.nextDouble() * _staggerSpan);
    for (final (i, d) in _dots.indexed) {
      final (p, z) = _target(OrbState.idle, i, 0);
      d
        ..pos = p
        ..from = p
        ..depth = z;
    }
  }

  @override
  void didUpdateWidget(ThinkingOrb old) {
    super.didUpdateWidget(old);
    if (old.dots != widget.dots) _build();
    if (old.state != widget.state) {
      for (final d in _dots) {
        d
          ..from = d.pos
          ..fromColor = d.color;
      }
      _changedAt = _now;
      if (widget.haptics) {
        if (widget.state == OrbState.done) HapticFeedback.lightImpact();
        if (widget.state == OrbState.error) HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  /// Unit-space target (radius 1) and depth 0..1 for dot [i] at time [t] s.
  (Offset, double) _target(OrbState s, int i, double t) {
    final n = _dots.length;
    switch (s) {
      case OrbState.idle:
      case OrbState.listening:
        final pulse = s == OrbState.listening
            ? .82 + .22 * widget.level.clamp(0, 1) + .04 * math.sin(t * 9)
            : .9 + .035 * math.sin(t * 1.6);
        return _sphere(i, n, t * .35, .35, pulse);
      case OrbState.thinking:
        final ring = i % 3;
        final k = i ~/ 3;
        final per = (n / 3).ceil();
        final a = 2 * math.pi * k / per + t * (1.4 + ring * .35) * (ring.isEven ? 1 : -1);
        var v = _V(math.cos(a) * .88, math.sin(a) * .88, 0);
        v = v.rotX(1.15 + ring * .35).rotY(ring * 2.1 + t * .3);
        return _project(v);
      case OrbState.searching:
        final (p, _) = _sphere(i, n, t * .5, 0, .92);
        final flat = Offset(p.dx, p.dy * .32);
        final ang = math.atan2(flat.dy / .32, flat.dx);
        final sweep = (t * 3.2) % (2 * math.pi);
        var diff = (sweep - ang) % (2 * math.pi);
        if (diff < 0) diff += 2 * math.pi;
        final lit = math.max(0.0, 1 - diff / 1.6);
        return (flat, .25 + .75 * lit);
      case OrbState.done:
        const a = Offset(-.52, .02), b = Offset(-.14, .4), c = Offset(.58, -.42);
        final la = (b - a).distance, lb = (c - b).distance;
        final u = (i / n) * (la + lb);
        final base = u < la
            ? Offset.lerp(a, b, u / la)!
            : Offset.lerp(b, c, (u - la) / lb)!;
        final j = math.sin(i * 12.9898) * .035;
        return (base + Offset(j, -j), 1);
      case OrbState.error:
        final since = (_now - _changedAt).inMilliseconds / 1000;
        if (since < .9) {
          final (p, z) = _sphere(i, n, 0, .35, .9);
          final g = math.pow(math.max(0, since - _stagger[i] / 1000), 2) * 4.2;
          return (Offset(p.dx, math.min(1.05, p.dy + g)), z);
        }
        final shake = math.sin(t * 40) * .025 * math.max(0, 1.6 - since);
        final (p, z) = _sphere(i, n, t * .35, .35, .86);
        return (p + Offset(shake, 0), z);
    }
  }

  (Offset, double) _sphere(int i, int n, double spin, double tilt, double r) {
    final y = 1 - 2 * (i + .5) / n;
    final rad = math.sqrt(1 - y * y);
    final th = i * math.pi * (3 - math.sqrt(5));
    final v = _V(math.cos(th) * rad * r, y * r, math.sin(th) * rad * r)
        .rotY(spin)
        .rotX(tilt);
    return _project(v);
  }

  (Offset, double) _project(_V v) => (Offset(v.x, v.y), (v.z + 1) / 2);

  Color _targetColor(OrbState s) {
    final fg = widget.color ?? Dissolve.fg;
    return switch (s) {
      OrbState.done => Dissolve.success,
      OrbState.error => Dissolve.danger,
      _ => fg,
    };
  }

  void _tick(Duration now) {
    _now = now;
    final t = now.inMicroseconds / 1e6;
    final since = (now - _changedAt).inMicroseconds / 1000;
    final half = widget.size / 2;
    final col = _targetColor(widget.state);
    for (final (i, d) in _dots.indexed) {
      final (p, z) = _target(widget.state, i, t);
      final raw = ((since - _stagger[i]) / _morph).clamp(0.0, 1.0);
      final e = Curves.easeInOutCubic.transform(raw);
      d
        ..pos = Offset.lerp(d.from, p, e)!
        ..depth = z
        ..color = Color.lerp(d.fromColor, col, e)!;
      var want = Offset.zero;
      if (_finger != null) {
        final px = d.pos * half * .92 + Offset(half, half);
        final delta = px - _finger!;
        final dist = delta.distance;
        if (dist < 40 && dist > .01) {
          want = delta / dist * (40 - dist) * .9;
        }
      }
      d.push = Offset.lerp(d.push, want, .18)!;
    }
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    Widget orb = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _OrbPainter(this),
      ),
    );
    if (widget.interactive) {
      orb = Listener(
        onPointerDown: (e) => _finger = e.localPosition,
        onPointerMove: (e) => _finger = e.localPosition,
        onPointerUp: (_) => _finger = null,
        onPointerCancel: (_) => _finger = null,
        child: MouseRegion(
          onHover: (e) => _finger = e.localPosition,
          onExit: (_) => _finger = null,
          child: orb,
        ),
      );
    }
    return SizedBox.square(dimension: widget.size, child: orb);
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.s) : super(repaint: s._repaint);
  final _ThinkingOrbState s;

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    final c = Offset(half, half);
    final p = Paint();
    final base = s.widget.dotSize * (size.width / 64).clamp(.6, 2.2);
    for (final d in s._dots) {
      final pos = c + d.pos * half * .92 + d.push;
      final a = .22 + .78 * d.depth;
      p.color = d.color.withValues(alpha: a);
      canvas.drawCircle(pos, base / 2 * (.65 + .55 * d.depth), p);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => false;
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V rotY(double a) =>
      _V(x * math.cos(a) + z * math.sin(a), y, -x * math.sin(a) + z * math.cos(a));
  _V rotX(double a) =>
      _V(x, y * math.cos(a) - z * math.sin(a), y * math.sin(a) + z * math.cos(a));
}
