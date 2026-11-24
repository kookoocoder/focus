import 'package:flutter/material.dart';

import '../../core/store.dart';
import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import '../body/body_goal.dart';

/// Minimal diet log: you type what you ate plus protein/carbs totals. No auto breakdown.
class DietScreen extends StatefulWidget {
  const DietScreen({super.key});
  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  static const _key = 'diet';
  List<Map<String, dynamic>> log = [];
  String get today => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    log = (Store.read<List>(_key) ?? []).cast<Map<String, dynamic>>();
  }

  num _sum(String f) => log
      .where((e) => e['date'] == today)
      .fold<num>(0, (a, e) => a + (num.tryParse('${e[f]}') ?? 0));

  Future<void> _add() async {
    final food = TextEditingController();
    final protein = TextEditingController();
    final carbs = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What did you eat?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: food,
              decoration: const InputDecoration(labelText: 'Food'),
            ),
            TextField(
              controller: protein,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Protein (g)'),
            ),
            TextField(
              controller: carbs,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carbs (g)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && food.text.trim().isNotEmpty) {
      log.insert(0, {
        'date': today,
        'food': food.text.trim(),
        'protein': protein.text,
        'carbs': carbs.text,
      });
      Store.write(_key, log);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final todays = log.where((e) => e['date'] == today).toList();
    return FocusPage(
      subtitle: '${todays.length} meals today',
      title: 'Diet',
      hue: Hue.body,
      actions: [GlassIcon(icon: Icons.add_rounded, tooltip: 'Log food', onTap: _add)],
      children: [
        Row(
          children: [
            Expanded(
              child: _macro(
                'Protein',
                _sum('protein'),
                Dissolve.sky,
                Icons.egg_alt_outlined,
                target: loadGoal()?.proteinTarget,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _macro('Carbs', _sum('carbs'), Dissolve.warning, Icons.grain_rounded)),
          ],
        ),
        if (todays.isNotEmpty) SectionLabel('Today'),
        if (todays.isEmpty)
          Panel(
            onTap: _add,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(Icons.restaurant_rounded, color: Dissolve.muted),
                SizedBox(height: 10),
                Text('Nothing logged yet', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Tap to add what you ate', style: TextStyle(color: Dissolve.muted, fontSize: 13)),
              ],
            ),
          ),
        for (final e in todays)
          DustRow(
            key: ObjectKey(e),
            onRemoved: () {
              log.remove(e);
              Store.write(_key, log);
              setState(() {});
            },
            builder: (dissolve) => Panel(
              padding: const EdgeInsets.fromLTRB(18, 14, 6, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['food'], style: Typo.heading.copyWith(fontSize: 15.5)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _pill('P ${e['protein']}g', Dissolve.sky),
                            const SizedBox(width: 6),
                            _pill('C ${e['carbs']}g', Dissolve.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: Dissolve.muted),
                    onPressed: dissolve,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _macro(String label, num grams, Color color, IconData icon, {int? target}) => Panel(
    glow: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: Typo.caption),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            NumberTicker(
              '$grams',
              style: Typo.metric.copyWith(fontSize: 38),
            ),
            Padding(
              padding: EdgeInsets.only(left: 3, bottom: 4),
              child: Text(target == null ? 'g' : 'g / $target', style: Typo.caption),
            ),
          ],
        ),
        if (target != null) ...[
          const SizedBox(height: 10),
          Bar(value: grams / target, color: color),
        ],
      ],
    ),
  );

  Widget _pill(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}
