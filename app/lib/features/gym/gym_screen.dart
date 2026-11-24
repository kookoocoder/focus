import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications.dart';
import '../../core/store.dart';
import '../../ui/kit.dart';
import '../../ui/tokens.dart';

const _logKey = 'gym';
const _restId = 103;

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<Map<String, dynamic>> log = (Store.read<List>(_logKey) ?? [])
      .cast<Map<String, dynamic>>();

  DateTime? workoutStart;
  int restLeft = 0;
  Timer? _tick;

  String get today => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // ---------- timer ----------

  void _ensureTicking() {
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (restLeft > 0) {
        restLeft--;
        if (restLeft == 0) {
          HapticFeedback.heavyImpact();
          Notifier.show(
            _restId,
            'Rest over',
            'Next set!',
            channel: 'gym',
            channelName: 'Gym',
          );
        }
      }
      if (workoutStart == null && restLeft == 0) {
        _tick?.cancel();
        _tick = null;
      }
      setState(() {});
    });
  }

  void _toggleWorkout() {
    if (workoutStart == null) {
      workoutStart = DateTime.now();
      _ensureTicking();
    } else {
      final mins = DateTime.now().difference(workoutStart!).inMinutes;
      log.insert(0, {'date': today, 'name': 'Workout session', 'mins': mins});
      Store.write(_logKey, log);
      workoutStart = null;
      restLeft = 0;
    }
    setState(() {});
  }

  void _rest(int s) {
    restLeft = s;
    _ensureTicking();
    setState(() {});
  }

  String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  // ---------- log ----------

  Future<void> _addExercise() async {
    final name = TextEditingController();
    final sets = TextEditingController();
    final reps = TextEditingController();
    final kg = TextEditingController();
    Widget num(TextEditingController c, String l) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: l),
      ),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Exercise'),
            ),
            Row(
              children: [
                num(sets, 'Sets'),
                const SizedBox(width: 8),
                num(reps, 'Reps'),
                const SizedBox(width: 8),
                num(kg, 'kg'),
              ],
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
    if (ok == true && name.text.trim().isNotEmpty) {
      log.insert(0, {
        'date': today,
        'name': name.text.trim(),
        'sets': sets.text,
        'reps': reps.text,
        'kg': kg.text,
      });
      Store.write(_logKey, log);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = workoutStart != null;
    final elapsed = running
        ? DateTime.now().difference(workoutStart!).inSeconds
        : 0;
    final dates = log.map((e) => e['date'] as String).toSet().toList();

    final todayCount = log.where((e) => e['date'] == today).length;
    return FocusPage(
      subtitle: todayCount == 0 ? 'Nothing logged today' : '$todayCount logged today',
      title: 'Gym',
      hue: Hue.body,
      actions: [GlassIcon(icon: Icons.add_rounded, tooltip: 'Log exercise', onTap: _addExercise)],
      children: [
        Panel(
          glow: running ? Dissolve.success : Hue.body,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
          child: Column(
            children: [
              Text(
                running ? 'WORKOUT' : 'READY WHEN YOU ARE',
                style: Typo.label.copyWith(color: running ? Dissolve.success : Hue.body),
              ),
              const SizedBox(height: 8),
              NumberTicker(
                _fmt(elapsed),
                style: Typo.display.copyWith(
                  fontSize: 64,
                  color: running ? Dissolve.fg : Dissolve.muted,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: restLeft > 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          children: [
                            NumberTicker(
                              'Rest ${_fmt(restLeft)}',
                              style: Typo.heading.copyWith(color: Hue.body),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: running
                      ? FilledButton.styleFrom(
                          backgroundColor: Dissolve.danger.withValues(alpha: .15),
                          foregroundColor: Dissolve.danger,
                        )
                      : null,
                  onPressed: _toggleWorkout,
                  icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(running ? 'Finish workout' : 'Start workout'),
                ),
              ),
              if (running) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final s in [60, 90, 120])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            onPressed: () => _rest(s),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: Text('${s}s rest'),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (log.isEmpty)
          Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Tap + to log your first exercise.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Dissolve.muted),
            ),
          ),
        for (final d in dates) ...[
          SectionLabel(d == today ? 'Today' : d),
          for (final e in log.where((e) => e['date'] == d))
            DustRow(
              key: ObjectKey(e),
              onRemoved: () {
                log.remove(e);
                Store.write(_logKey, log);
                setState(() {});
              },
              builder: (dissolve) => Panel(
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Hue.body.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        e['mins'] != null ? Icons.timer_outlined : Icons.fitness_center_rounded,
                        size: 18,
                        color: Hue.body,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['name'], style: Typo.heading.copyWith(fontSize: 15.5)),
                          const SizedBox(height: 2),
                          Text(
                            e['mins'] != null
                                ? '${e['mins']} min'
                                : '${e['sets']} × ${e['reps']}  ·  ${e['kg']} kg',
                            style: Typo.caption,
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
      ],
    );
  }
}
