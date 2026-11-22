import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'alarms.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});
  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  List<AlarmItem> items = loadAlarms();

  Future<void> _save() async {
    items.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    await saveAlarms(items);
    setState(() {});
  }

  Future<void> _edit([AlarmItem? existing]) async {
    final t = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? const TimeOfDay(hour: 6, minute: 0)
          : TimeOfDay(hour: existing.hour, minute: existing.minute),
    );
    if (t == null || !mounted) return;
    var kind = existing?.kind ?? AlarmKind.wake;
    final days = [...(existing?.days ?? [1, 2, 3, 4, 5, 6, 7])];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t.format(ctx), style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            SegmentedButton<AlarmKind>(
              segments: [
                for (final k in AlarmKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {kind},
              onSelectionChanged: (v) => set(() => kind = v.first),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_dayLetters[d - 1]),
                  selected: days.contains(d),
                  onSelected: (v) => set(() => v ? days.add(d) : days.remove(d)),
                ),
            ]),
            Text(days.isEmpty ? 'One-time' : 'Repeats', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    if (existing == null) {
      final id = items.isEmpty ? 1 : items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
      items.add(AlarmItem(id: id, kind: kind, hour: t.hour, minute: t.minute, days: days));
    } else {
      existing
        ..kind = kind
        ..hour = t.hour
        ..minute = t.minute
        ..days = days
        ..on = true;
    }
    await _save();
  }

  String _daysText(List<int> d) {
    if (d.isEmpty) return 'Once';
    if (d.length == 7) return 'Every day';
    if (d.length == 5 && !d.contains(6) && !d.contains(7)) return 'Weekdays';
    return [for (final x in d..sort()) _dayLetters[x - 1]].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarms')),
      floatingActionButton: FloatingActionButton(onPressed: _edit, child: const Icon(Icons.add_alarm)),
      body: items.isEmpty
          ? const Center(child: Text('No alarms. Tap + to add one.'))
          : ListView(children: [
              for (final a in items)
                Dismissible(
                  key: ValueKey(a.id),
                  onDismissed: (_) async {
                    await Alarm.stop(a.id);
                    items.remove(a);
                    await _save();
                  },
                  child: ListTile(
                    onTap: () => _edit(a),
                    title: Text(a.time,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: a.on ? null : Theme.of(context).disabledColor)),
                    subtitle: Text('${a.kind.label} · ${_daysText(a.days)}'),
                    trailing: Switch(
                      value: a.on,
                      onChanged: (v) {
                        a.on = v;
                        _save();
                      },
                    ),
                  ),
                ),
            ]),
    );
  }
}
