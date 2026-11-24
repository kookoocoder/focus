import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'effects.dart';
import 'tokens.dart';

/// Indigo glow over near-black, behind every screen.
class Backdrop extends StatelessWidget {
  Backdrop({super.key, Color? tint}) : tint = tint ?? Dissolve.glow;
  final Color tint;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Dissolve.bg,
      gradient: RadialGradient(
        center: Alignment(-.6, -1.1),
        radius: 1.3,
        colors: [tint, Dissolve.bg],
        stops: [0, .75],
      ),
    ),
  );
}

/// Segmented switch shown above the title of every [FocusPage] below it, so
/// one nav tab can hold several screens (Gym/Diet, Timer/Scroll).
class SubTabs extends InheritedWidget {
  const SubTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelect,
    required super.child,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;

  static SubTabs? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<SubTabs>();

  @override
  bool updateShouldNotify(SubTabs old) => old.index != index || old.labels != labels;
}

/// Large-title page: scrolling content under a header tinted with the
/// section's [hue].
class FocusPage extends StatelessWidget {
  FocusPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.onRefresh,
    this.fab,
    this.busy = false,
    Color? hue,
    this.animateTitle = true,
    this.showSettings = true,
  }) : hue = hue ?? Dissolve.accent;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? fab;
  final bool busy;
  final Color hue;
  final bool animateTitle;
  final bool showSettings;

  /// Set once by the app shell; opens Settings from any page header.
  static VoidCallback? openSettings;

  @override
  Widget build(BuildContext context) {
    final tabs = SubTabs.maybeOf(context);
    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
      children: [
        if (tabs != null)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: _SubTabBar(tabs: tabs, hue: hue),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(4, tabs != null ? 22 : 18, 0, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      AnimatedSwitcher(
                        duration: Motion.fast,
                        child: Text(
                          subtitle!.toUpperCase(),
                          key: ValueKey(subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Typo.label.copyWith(color: hue),
                        ),
                      ),
                    SizedBox(height: 8),
                    animateTitle
                        ? TextScramble(title, speed: 34, style: Typo.title)
                        : Text(title, style: Typo.title),
                  ],
                ),
              ),
              ...actions,
              if (showSettings && openSettings != null)
                GlassIcon(icon: Icons.settings_outlined, tooltip: 'Settings', onTap: openSettings),
            ],
          ),
        ),
        for (final (n, c) in children.indexed)
          animateTitle ? Rise(index: n, child: c) : c,
      ],
    );
    if (onRefresh != null) {
      list = RefreshIndicator(
        onRefresh: onRefresh!,
        color: Dissolve.bg,
        backgroundColor: hue,
        child: list,
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: fab == null
          ? null
          : Padding(padding: EdgeInsets.only(bottom: 84), child: fab),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-.7, -1.15),
                    radius: 1.1,
                    colors: [hue.withValues(alpha: .16), hue.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                list,
                if (busy)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: hue,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts its child in once, [index] steps after the page appears,
/// so page content arrives in order instead of all at once.
class Rise extends StatefulWidget {
  const Rise({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.base);
  late final _a = CurvedAnimation(parent: _c, curve: Motion.curve);

  @override
  void initState() {
    super.initState();
    Future.delayed(Motion.stagger * math.min(widget.index, 8), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(_a),
      child: widget.child,
    ),
  );
}

class _SubTabBar extends StatelessWidget {
  const _SubTabBar({required this.tabs, required this.hue});
  final SubTabs tabs;
  final Color hue;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Dissolve.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Dissolve.border),
      boxShadow: Dissolve.lift,
    ),
    child: Stack(
      children: [
        AnimatedAlign(
          duration: Motion.base,
          curve: Motion.curve,
          alignment: Alignment(
            tabs.labels.length == 1 ? 0 : -1 + 2 * tabs.index / (tabs.labels.length - 1),
            0,
          ),
          child: FractionallySizedBox(
            widthFactor: 1 / tabs.labels.length,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: hue,
                gradient: Dissolve.light
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(hue, Colors.white, .15)!, hue],
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Row(
          children: [
            for (final (n, l) in tabs.labels.indexed)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (n != tabs.index) HapticFeedback.selectionClick();
                    tabs.onSelect(n);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: Motion.fast,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: n == tabs.index ? Dissolve.ink : Dissolve.muted,
                      ),
                      child: Text(l),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Frosted panel with a hairline border.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.glow,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? glow;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 5),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              (glow ?? (Dissolve.light ? Dissolve.accent : Colors.white))
                  .withValues(alpha: Dissolve.light ? (glow == null ? .025 : .09) : .06),
              Dissolve.surface,
            ),
            Dissolve.surface.withValues(alpha: Dissolve.light ? .97 : .85),
          ],
        ),
        border: Border.all(color: Dissolve.border),
        boxShadow: Dissolve.lift,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(6, 22, 6, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(text.toUpperCase(), style: Typo.label),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Rolling digit columns.
class NumberTicker extends StatelessWidget {
  const NumberTicker(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, ch) in text.split('').indexed)
        ClipRect(
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.curve,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) {
              final incoming = child.key == ValueKey('$i$ch');
              return SlideTransition(
                position: Tween(
                  begin: Offset(0, incoming ? .9 : -.9),
                  end: Offset.zero,
                ).animate(a),
                child: FadeTransition(opacity: a, child: child),
              );
            },
            child: Text(
              ch,
              key: ValueKey('$i$ch'),
              style: style.copyWith(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ),
    ],
  );
}

/// Circular progress that sweeps to its value.
class Ring extends StatelessWidget {
  Ring({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 10,
    Color? color,
    this.child,
  }) : color = color ?? Dissolve.fg;
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final side = math.min(size, box.maxWidth);
      return TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (_, v, child) => CustomPaint(
          painter: _RingPainter(v, stroke, color),
          child: SizedBox.square(
            dimension: side,
            child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: child)),
          ),
        ),
        child: child,
      );
    },
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color);
  final double v, stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by a full stroke so the round cap and tip glow stay inside.
    final rect = (Offset.zero & size).deflate(stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Dissolve.track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (v <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: .35), color],
        stops: [0, v],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * v, false, arc);
    final end = -math.pi / 2 + 2 * math.pi * v;
    final tip = rect.center + Offset(math.cos(end), math.sin(end)) * rect.width / 2;
    canvas.drawCircle(
      tip,
      stroke * .9,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// Thin rounded bar that grows to its value.
class Bar extends StatelessWidget {
  Bar({super.key, required this.value, Color? color, this.height = 6})
      : color = color ?? Dissolve.fg;
  final double value;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Container(
      height: height,
      color: Dissolve.track,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (_, v, _) => FractionallySizedBox(
          widthFactor: v,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A row that leaves as dust: swipe left, or call the builder's `dissolve`.
class DustRow extends StatefulWidget {
  const DustRow({super.key, required this.builder, required this.onRemoved});
  final Widget Function(VoidCallback dissolve) builder;
  final VoidCallback onRemoved;
  @override
  State<DustRow> createState() => _DustRowState();
}

class _DustRowState extends State<DustRow> {
  bool _going = false;

  void _go() {
    if (_going) return;
    HapticFeedback.mediumImpact();
    setState(() => _going = true);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(_go);
    if (_going) {
      return Grains(
        reverse: true,
        duration: const Duration(milliseconds: 700),
        onDone: widget.onRemoved,
        child: IgnorePointer(child: child),
      );
    }
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _go();
        return false;
      },
      background: const SizedBox(),
      child: child,
    );
  }
}

/// Small glass icon button used in headers.
class GlassIcon extends StatelessWidget {
  const GlassIcon({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Dissolve.surface,
        elevation: Dissolve.light ? 2 : 0,
        shadowColor: const Color(0x33000000),
        shape: CircleBorder(side: BorderSide(color: Dissolve.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42,
            child: Icon(icon, size: 18, color: onTap == null ? Dissolve.muted : Dissolve.fg),
          ),
        ),
      ),
    ),
  );
}

Color scoreColor(double pct, double pass) => pct >= pass
    ? Dissolve.success
    : pct >= pass - 10
    ? Dissolve.warning
    : Dissolve.danger;
