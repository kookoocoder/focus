import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications.dart';
import '../../core/store.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Gym')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Exercise'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    running ? _fmt(elapsed) : 'Ready',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  if (restLeft > 0)
                    Text(
                      'Rest ${_fmt(restLeft)}',
                      style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _toggleWorkout,
                    icon: Icon(running ? Icons.stop : Icons.play_arrow),
                    label: Text(running ? 'Finish workout' : 'Start workout'),
                  ),
                  if (running) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in [60, 90, 120])
                          ActionChip(
                            label: Text('Rest ${s}s'),
                            onPressed: () => _rest(s),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (final d in dates) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text(
                d == today ? 'Today' : d,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final e in log.where((e) => e['date'] == d))
              ListTile(
                dense: true,
                title: Text(e['name']),
                subtitle: Text(
                  e['mins'] != null
                      ? '${e['mins']} min'
                      : '${e['sets']} × ${e['reps']} @ ${e['kg']} kg',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    log.remove(e);
                    Store.write(_logKey, log);
                    setState(() {});
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
