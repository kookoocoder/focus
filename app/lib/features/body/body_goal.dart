import 'package:flutter/material.dart';

import '../../core/store.dart';
import '../../ui/tokens.dart';

const bodyGoalKey = 'bodyGoal';
const weightLogKey = 'weightLog';

/// Height and the weight the user started at and is aiming for.
class BodyGoal {
  BodyGoal({required this.heightCm, required this.startKg, required this.targetKg, String? since})
    : since = since ?? DateTime.now().toIso8601String().substring(0, 10);
  final double heightCm, startKg, targetKg;
  final String since;

  factory BodyGoal.fromJson(Map<String, dynamic> j) => BodyGoal(
    heightCm: (j['heightCm'] as num).toDouble(),
    startKg: (j['startKg'] as num).toDouble(),
    targetKg: (j['targetKg'] as num).toDouble(),
    since: j['since'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'heightCm': heightCm,
    'startKg': startKg,
    'targetKg': targetKg,
    'since': since,
  };

  double bmiAt(double kg) => bmi(kg, heightCm);

  /// Healthy weight range for this height (BMI 18.5 to 24.9).
  (double, double) get healthy {
    final m = heightCm / 100;
    return (18.5 * m * m, 24.9 * m * m);
  }

  /// Daily protein, 1.6 g per kg of target weight.
  int get proteinTarget => (targetKg * 1.6).round();

  String get direction => targetKg < startKg - .5
      ? 'Lose'
      : targetKg > startKg + .5
      ? 'Gain'
      : 'Hold';

  /// 0..1 of the way from start to target.
  double progress(double kg) {
    final span = targetKg - startKg;
    if (span.abs() < .5) return (1 - (kg - targetKg).abs() / 3).clamp(0, 1);
    return ((kg - startKg) / span).clamp(0, 1);
  }
}

double bmi(double kg, double heightCm) => kg / ((heightCm / 100) * (heightCm / 100));

(String, Color) bmiBand(double b) => b < 18.5
    ? ('Underweight', Dissolve.sky)
    : b < 25
    ? ('Healthy', Dissolve.success)
    : b < 30
    ? ('Overweight', Dissolve.warning)
    : ('Obese', Dissolve.danger);

BodyGoal? loadGoal() {
  final j = Store.read<Map<String, dynamic>>(bodyGoalKey);
  return j == null ? null : BodyGoal.fromJson(j);
}

Future<void> saveGoal(BodyGoal g) => Store.write(bodyGoalKey, g.toJson());

/// Weigh-ins, newest first: `{date, kg}`.
List<Map<String, dynamic>> loadWeights() =>
    (Store.read<List>(weightLogKey) ?? []).cast<Map<String, dynamic>>();

Future<void> logWeight(double kg) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final log = loadWeights()..removeWhere((e) => e['date'] == today);
  log.insert(0, {'date': today, 'kg': kg});
  await Store.write(weightLogKey, log);
}

double? currentWeight() {
  final w = loadWeights();
  if (w.isNotEmpty) return (w.first['kg'] as num).toDouble();
  return loadGoal()?.startKg;
}

/// Height, current and target weight with a live BMI readout. Used by
/// onboarding and the Weight screen.
class GoalForm extends StatefulWidget {
  const GoalForm({super.key, this.initial, required this.onChanged});
  final BodyGoal? initial;
  final ValueChanged<BodyGoal?> onChanged;
  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  late final h = TextEditingController(text: _fmt(widget.initial?.heightCm));
  late final w = TextEditingController(text: _fmt(currentWeight() ?? widget.initial?.startKg));
  late final t = TextEditingController(text: _fmt(widget.initial?.targetKg));

  static String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  BodyGoal? get _goal {
    final hv = double.tryParse(h.text), wv = double.tryParse(w.text), tv = double.tryParse(t.text);
    if (hv == null || wv == null || tv == null || hv < 100 || hv > 250 || wv < 25 || tv < 25) {
      return null;
    }
    return BodyGoal(heightCm: hv, startKg: wv, targetKg: tv);
  }

  @override
  void dispose() {
    h.dispose();
    w.dispose();
    t.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, String unit) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) {
        setState(() {});
        widget.onChanged(_goal);
      },
      style: Typo.heading,
      decoration: InputDecoration(labelText: label, suffixText: unit),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final g = _goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _field(h, 'Height', 'cm'),
            const SizedBox(width: 12),
            _field(w, 'Weight now', 'kg'),
            const SizedBox(width: 12),
            _field(t, 'Target', 'kg'),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: Motion.fast,
          child: g == null
              ? Text('Enter all three to see your BMI.', key: const ValueKey(0), style: Typo.caption)
              : Column(
                  key: const ValueKey(1),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BmiScale(bmi: g.bmiAt(g.startKg), target: g.bmiAt(g.targetKg)),
                    const SizedBox(height: 10),
                    Text(
                      'BMI ${g.bmiAt(g.startKg).toStringAsFixed(1)} now, '
                      '${g.bmiAt(g.targetKg).toStringAsFixed(1)} at target. Healthy for your height: '
                      '${g.healthy.$1.round()} to ${g.healthy.$2.round()} kg.',
                      style: Typo.caption,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Horizontal BMI scale (15 to 35) split into the four bands, with a marker
/// for now and a hollow one for the target.
class BmiScale extends StatelessWidget {
  const BmiScale({super.key, required this.bmi, this.target});
  final double bmi;
  final double? target;

  static const _lo = 15.0, _hi = 35.0;
  static double _x(double b) => ((b - _lo) / (_hi - _lo)).clamp(0, 1);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final w = box.maxWidth;
      Widget band(double from, double to, Color c) => Container(
        width: w * (_x(to) - _x(from)),
        height: 8,
        color: c.withValues(alpha: .55),
      );
      return SizedBox(
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    band(_lo, 18.5, Dissolve.sky),
                    band(18.5, 25, Dissolve.success),
                    band(25, 30, Dissolve.warning),
                    band(30, _hi, Dissolve.danger),
                  ],
                ),
              ),
            ),
            if (target != null)
              AnimatedPositioned(
                duration: Motion.slow,
                curve: Motion.curve,
                top: 9,
                left: w * _x(target!) - 9,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Dissolve.fg, width: 2),
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: Motion.slow,
              curve: Motion.curve,
              top: 7,
              left: w * _x(bmi) - 11,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bmiBand(bmi).$2,
                  border: Border.all(color: Dissolve.surface, width: 3),
                  boxShadow: [BoxShadow(color: bmiBand(bmi).$2.withValues(alpha: .5), blurRadius: 10)],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
