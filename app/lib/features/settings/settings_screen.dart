import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/credentials.dart';
import '../../core/updater.dart';
import '../../core/store.dart';
import '../../main.dart' show lookKey, navigatorKey;
import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import '../alarms/alarms.dart';
import '../assistant/voice.dart';
import '../attendance/attendance_sync.dart';
import '../body/body_goal.dart';
import '../onboarding/onboarding_screen.dart' show onboardedKey;

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _app = MethodChannel('focus/app');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<Activity> activities = loadActivities();
  AppVersion? version;
  String? erpId;
  bool bubbleOn = false;
  bool bubbleCan = false;
  bool phononReady = false;
  double? phononProgress;
  BodyGoal? goal = loadGoal();

  @override
  void initState() {
    super.initState();
    appVersion().then((v) => mounted ? setState(() => version = v) : null);
    Credentials.id().then((id) => mounted ? setState(() => erpId = id) : null);
    PhononModel.ready().then((ok) => mounted ? setState(() => phononReady = ok) : null);
    _refreshBubble();
  }

  Future<void> _refreshBubble() async {
    try {
      final m = (await _app.invokeMethod<Map>('bubbleState'))?.cast<String, dynamic>();
      if (!mounted || m == null) return;
      setState(() {
        bubbleOn = m['on'] == true;
        bubbleCan = m['canDraw'] == true;
      });
    } catch (_) {}
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

  Future<void> _editErp() async {
    final id = TextEditingController(text: erpId ?? '');
    final pw = TextEditingController();
    String? err;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Dissolve.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('College ERP', style: Typo.heading),
              const SizedBox(height: 6),
              Text('Login stays in the phone’s secure vault.', style: Typo.caption),
              const SizedBox(height: 14),
              TextField(controller: id, decoration: const InputDecoration(labelText: 'ERP ID / PRN')),
              TextField(
                controller: pw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: TextStyle(color: Dissolve.danger, fontSize: 13)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  try {
                    await Credentials.connect(id.text.trim(), pw.text);
                    syncFromErp().ignore();
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setLocal(() => err = '$e');
                  }
                },
                child: const Text('Connect'),
              ),
              if (erpId != null)
                TextButton(
                  onPressed: () async {
                    await Credentials.clear();
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: Text('Disconnect', style: TextStyle(color: Dissolve.danger)),
                ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      final next = await Credentials.id();
      if (mounted) setState(() => erpId = next);
    }
  }

  Future<void> _toggleBubble(bool on) async {
    final ok = await _app.invokeMethod<bool>('setBubble', {'on': on}) ?? false;
    await _refreshBubble();
    if (!ok && on && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allow “Display over other apps” for Focus.')),
      );
    }
  }

  Future<void> _downloadPhonon() async {
    setState(() => phononProgress = 0);
    try {
      await PhononModel.download((p) {
        if (mounted) setState(() => phononProgress = p);
      });
      if (mounted) setState(() { phononReady = true; phononProgress = null; });
    } catch (e) {
      if (mounted) {
        setState(() => phononProgress = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
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
                const SnackBar(content: Text('Test alarm rings in 10 seconds. Lock the phone.')),
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
        SectionLabel('College ERP'),
        Panel(
          onTap: _editErp,
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(erpId == null ? 'Not connected' : 'Connected as $erpId', style: Typo.heading),
                    const SizedBox(height: 2),
                    Text(
                      erpId == null ? 'Tap to enter your ERP login' : 'Tap to change or disconnect',
                      style: Typo.caption,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
        SectionLabel('Body goal'),
        Panel(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  goal == null
                      ? 'No BMI goal set'
                      : 'BMI ${goal!.bmiAt(currentWeight() ?? goal!.startKg).toStringAsFixed(1)} · target ${goal!.targetKg.toStringAsFixed(1)} kg',
                  style: Typo.heading.copyWith(fontSize: 15.5),
                ),
              ),
              Text('Body → Weight', style: Typo.caption),
            ],
          ),
        ),
        SectionLabel('Assistant'),
        Panel(
          padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Floating bubble'),
            subtitle: Text(
              bubbleOn
                  ? bubbleCan
                      ? 'On — tap the orb over other apps'
                      : 'Waiting for overlay permission'
                  : 'Open Focus from anywhere on the phone',
            ),
            value: bubbleOn && bubbleCan,
            onChanged: _toggleBubble,
          ),
        ),
        Panel(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Voice (Phonon)', style: Typo.heading),
              const SizedBox(height: 4),
              Text(
                phononReady
                    ? 'On-device Phonon 31m ready · ~64 MB'
                    : 'Download Phonon 31m for natural mic replies. Until then the system voice is used.',
                style: Typo.caption,
              ),
              const SizedBox(height: 10),
              if (phononProgress != null)
                Column(
                  children: [
                    Bar(value: phononProgress!, color: Dissolve.accent, height: 6),
                    const SizedBox(height: 6),
                    Text('${(phononProgress! * 100).round()}%', style: Typo.caption),
                  ],
                )
              else
                Row(
                  children: [
                    TextButton(
                      onPressed: phononReady ? null : _downloadPhonon,
                      child: Text(phononReady ? 'Installed' : 'Download'),
                    ),
                    if (phononReady)
                      TextButton(
                        onPressed: () async {
                          await PhononModel.delete();
                          if (mounted) setState(() => phononReady = false);
                        },
                        child: const Text('Remove'),
                      ),
                  ],
                ),
            ],
          ),
        ),
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
                      Expanded(child: Text(a.label, style: Theme.of(context).textTheme.titleMedium)),
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
                    subtitle: Text(a.alarm ? 'Loud alarm with Stop / Snooze' : 'Notification only'),
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
                    Text(version == null ? 'Version' : 'Build ${version!.code}', style: Typo.heading),
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
        Panel(
          onTap: () async {
            await Store.remove(onboardedKey);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Onboarding will show next launch.')),
              );
            }
          },
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Text('Replay onboarding', style: Typo.heading.copyWith(fontSize: 15.5)),
        ),
      ],
    );
  }
}
