import 'package:flutter/material.dart';

import '../../core/updater.dart';
import '../../core/store.dart';
import '../../main.dart' show lookKey, navigatorKey;
import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import '../alarms/alarms.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<Activity> activities = loadActivities();
  AppVersion? version;

  @override
  void initState() {
    super.initState();
    appVersion().then((v) => mounted ? setState(() => version = v) : null);
  }

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
    final muted = Dissolve.muted;
    return FocusPage(
      subtitle: '${activities.where((a) => a.enabled).length} reminders on',
      title: 'Settings',
      hue: Dissolve.muted,
      animateTitle: false,
      showSettings: false,
      actions: [
        GlassIcon(
          icon: Icons.alarm_rounded,
          tooltip: 'Test alarm',
          onTap: () async {
            await testAlarm();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test alarm rings in 10 seconds. Lock the phone.'),
                ),
              );
            }
          },
        ),
        GlassIcon(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onTap: () => Navigator.pop(context),
        ),
      ],
      children: [
          SectionLabel('Reminders'),
          for (final a in activities)
            Panel(
              glow: a.enabled ? Dissolve.accent : null,
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
              child: Opacity(
                opacity: a.enabled ? 1 : .55,
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
                      borderRadius: BorderRadius.circular(12),
                      child: Text(
                        a.time,
                        style: Typo.display.copyWith(
                          fontSize: 44,
                          fontWeight: FontWeight.w500,
                          color: a.enabled ? Dissolve.fg : muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var d = 1; d <= 7; d++)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                final on = !a.days.contains(d);
                                on ? a.days.add(d) : a.days.remove(d);
                                if (a.days.isEmpty) a.days.add(d);
                                _save();
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: a.days.contains(d) ? Dissolve.accent : Dissolve.raised,
                                  border: Border.all(color: Dissolve.border),
                                ),
                                child: Text(
                                  _dayLetters[d - 1],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: a.days.contains(d) ? Dissolve.ink : Dissolve.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
        SectionLabel('Appearance'),
        Panel(
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<Look>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Look.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: Look.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                ButtonSegment(value: Look.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
              ],
              selected: {Dissolve.look},
              onSelectionChanged: (s) {
                Store.write(lookKey, s.first.name);
                Dissolve.apply(s.first);
              },
            ),
          ),
        ),
        SectionLabel('App'),
        Panel(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version == null ? 'Version' : 'Build ${version!.code}',
                      style: Typo.heading,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      version == null ? '' : '${version!.name} · $channel · $gitSha',
                      style: Typo.caption,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => checkForUpdate(navigatorKey, manual: true),
                child: const Text('Check for updates'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
