import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import 'body_goal.dart';

/// BMI goal tracker: where you are on the BMI scale, how far to the target
/// weight, and a weigh-in log.
class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});
  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  BodyGoal? goal = loadGoal();
  List<Map<String, dynamic>> log = loadWeights();

  Future<void> _editGoal() async {
    BodyGoal? draft = goal;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Dissolve.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your goal', style: Typo.heading),
            const SizedBox(height: 14),
            GoalForm(initial: goal, onChanged: (g) => draft = g),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save goal')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || draft == null) return;
    final g = draft!;
    final keepSince = goal != null && goal!.startKg == g.startKg ? goal!.since : null;
    await saveGoal(BodyGoal(heightCm: g.heightCm, startKg: g.startKg, targetKg: g.targetKg, since: keepSince));
    if (log.isEmpty) await logWeight(g.startKg);
    setState(() {
      goal = loadGoal();
      log = loadWeights();
    });
  }

  Future<void> _weighIn() async {
    final c = TextEditingController(text: currentWeight()?.toStringAsFixed(1) ?? '');
    final kg = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weigh-in'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(c.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (kg == null || kg < 25) return;
    await logWeight(kg);
    setState(() => log = loadWeights());
  }

  @override
  Widget build(BuildContext context) {
    final g = goal;
    if (g == null) {
      return FocusPage(
        subtitle: 'No goal yet',
        title: 'Weight',
        hue: Hue.body,
        children: [
          Panel(
            onTap: _editGoal,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(Icons.monitor_weight_outlined, color: Hue.body, size: 30),
                const SizedBox(height: 12),
                Text('Set your BMI goal', style: Typo.heading),
                const SizedBox(height: 4),
                Text('Height, weight now and target. Then log weigh-ins to track it.',
                    textAlign: TextAlign.center, style: Typo.caption),
              ],
            ),
          ),
        ],
      );
    }
    final now = currentWeight()!;
    final b = g.bmiAt(now);
    final (band, bandColor) = bmiBand(b);
    final left = (g.targetKg - now).abs();
    final p = g.progress(now);
    return FocusPage(
      subtitle: '${g.direction} · target ${g.targetKg.toStringAsFixed(1)} kg',
      title: 'Weight',
      hue: Hue.body,
      actions: [
        GlassIcon(icon: Icons.tune_rounded, tooltip: 'Edit goal', onTap: _editGoal),
        GlassIcon(icon: Icons.add_rounded, tooltip: 'Weigh-in', onTap: _weighIn),
      ],
      children: [
        Panel(
          glow: bandColor,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  NumberTicker(b.toStringAsFixed(1), style: Typo.display.copyWith(color: Dissolve.fg)),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('BMI', style: Typo.caption),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(band, style: Typo.caption.copyWith(color: bandColor, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BmiScale(bmi: b, target: g.bmiAt(g.targetKg)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (final t in ['15', '18.5', '25', '30', '35']) Text(t, style: Typo.caption)],
              ),
            ],
          ),
        ),
        Panel(
          glow: Hue.body,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _kg('Start', g.startKg)),
                  Expanded(child: _kg('Now', now, color: Hue.body)),
                  Expanded(child: _kg('Target', g.targetKg)),
                ],
              ),
              const SizedBox(height: 16),
              Bar(value: p, color: Hue.body, height: 8),
              const SizedBox(height: 10),
              Text(
                left < .3
                    ? 'Target reached. Hold it.'
                    : '${left.toStringAsFixed(1)} kg to go · ${(p * 100).round()}% of the way',
                style: Typo.caption,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _fact(
                'Healthy range',
                '${g.healthy.$1.round()}–${g.healthy.$2.round()}',
                'kg',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _fact('Protein / day', '${g.proteinTarget}', 'g')),
          ],
        ),
        if (log.length > 1) ...[
          SectionLabel('Trend'),
          Panel(child: SizedBox(height: 110, child: _Spark(log: log, target: g.targetKg))),
        ],
        SectionLabel('Weigh-ins'),
        for (final (i, e) in log.take(10).indexed)
          Panel(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Expanded(child: Text('${e['date']}', style: Typo.body)),
                if (i + 1 < log.length) _delta((e['kg'] as num) - (log[i + 1]['kg'] as num)),
                const SizedBox(width: 12),
                Text('${(e['kg'] as num).toStringAsFixed(1)} kg', style: Typo.heading),
              ],
            ),
          ),
      ],
    );
  }

  Widget _kg(String label, double v, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: Typo.label),
      const SizedBox(height: 6),
      Text(v.toStringAsFixed(1), style: Typo.metric.copyWith(color: color ?? Dissolve.fg, fontSize: 24)),
    ],
  );

  Widget _fact(String label, String v, String unit) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Typo.caption),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: v, style: Typo.metric.copyWith(color: Dissolve.fg, fontSize: 24)),
          TextSpan(text: ' $unit', style: Typo.caption),
        ])),
      ],
    ),
  );

  Widget _delta(num d) {
    final good = goal == null || (goal!.targetKg < goal!.startKg ? d <= 0 : d >= 0);
    return Text(
      '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}',
      style: Typo.caption.copyWith(color: good ? Dissolve.success : Dissolve.warning, fontWeight: FontWeight.w700),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.log, required this.target});
  final List<Map<String, dynamic>> log;
  final double target;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Motion.slow,
    curve: Motion.curve,
    builder: (_, t, _) => CustomPaint(
      painter: _SparkPainter(
        [for (final e in log.take(30).toList().reversed) (e['kg'] as num).toDouble()],
        target,
        t,
        Hue.body,
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.target, this.t, this.color);
  final List<double> v;
  final double target, t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = math.min(v.reduce(math.min), target) - .5;
    final hi = math.max(v.reduce(math.max), target) + .5;
    double y(double kg) => size.height - (kg - lo) / (hi - lo) * size.height;
    final dash = Paint()
      ..color = Dissolve.muted.withValues(alpha: .6)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y(target)), Offset(x + 4, y(target)), dash);
    }
    final path = Path();
    for (final (i, kg) in v.indexed) {
      final p = Offset(i / (v.length - 1) * size.width, y(kg));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.t != t || o.v != v;
}
