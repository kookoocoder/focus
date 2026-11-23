import 'package:flutter/material.dart';

import '../alarms/alarms.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<Activity> activities = loadActivities();

  Future<void> _save() async {
    setState(() {});
    await saveActivities(activities);
  }

  Future<void> _pickTime(Activity a) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: a.hour, minute: a.minute),
    );
    if (t == null) return;
    a
      ..hour = t.hour
      ..minute = t.minute
      ..enabled = true;
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).disabledColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await testAlarm();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Test alarm rings in 10 seconds. Lock the phone.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.alarm),
            label: const Text('Test alarm'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Reminders'),
          ),
          for (final a in activities)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(
                          value: a.enabled,
                          onChanged: (v) {
                            a.enabled = v;
                            _save();
                          },
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _pickTime(a),
                      child: Text(
                        a.time,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          color: a.enabled ? null : muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          FilterChip(
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            label: Text(_dayLetters[d - 1]),
                            selected: a.days.contains(d),
                            onSelected: (v) {
                              v ? a.days.add(d) : a.days.remove(d);
                              if (a.days.isEmpty) a.days.add(d);
                              _save();
                            },
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Ring as alarm'),
                      subtitle: Text(
                        a.alarm
                            ? 'Loud alarm with Stop / Snooze'
                            : 'Notification only',
                      ),
                      value: a.alarm,
                      onChanged: a.enabled
                          ? (v) {
                              a.alarm = v;
                              _save();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
