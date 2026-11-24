import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/store.dart';
import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import '../attendance/attendance.dart';
import '../attendance/attendance_sync.dart';
import '../body/body_goal.dart';
import '../gate/pw_data.dart';
import '../scroll/scroll_screen.dart' show dayScore, fmtSecs, goodDay;

const _scroll = MethodChannel('focus/scroll');
const _app = MethodChannel('focus/app');

/// First tab: one glance at attendance risk, GATE, body, focus and phone use.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  List<Subject> subjects = loadSubjects();
  BodyGoal? goal = loadGoal();
  double? weight = currentWeight();
  PwCourse gate = PwCourse.load();
  int scrollScore = -1;
  String? usageLine;
  int? usageRating;

  @override
  void initState() {
    super.initState();
    _loadFocus();
    _loadUsage();
  }

  Future<void> _loadFocus() async {
    try {
      final lim = await _scroll.invokeMethod<int>('getLimit') ?? 300;
      final tlim = await _scroll.invokeMethod<int>('getTimeLimit') ?? 60;
      final h = jsonDecode(await _scroll.invokeMethod<String>('history') ?? '{}');
      final days = (h['days'] as List? ?? []).cast<Map<String, dynamic>>();
      if (!mounted || days.isEmpty) return;
      setState(() => scrollScore = dayScore(days.first, lim, tlim));
    } catch (_) {}
  }

  Future<void> _loadUsage() async {
    try {
      final ok = await _app.invokeMethod<bool>('usageAccess') ?? false;
      if (!ok) {
        if (mounted) setState(() => usageLine = 'Grant usage access in Settings');
        return;
      }
      final raw = await _app.invokeMethod<String>('usage', {'days': 1});
      final j = jsonDecode(raw!) as Map<String, dynamic>;
      final days = (j['days'] as List).cast<Map<String, dynamic>>();
      final secs = (days.first['secs'] as num).toInt();
      final unlocks = (days.first['unlocks'] as num).toInt();
      // Rough rating: under 3h = 90+, under 5h = 70+, under 7h = 50+, else lower.
      final hours = secs / 3600;
      final rating = (hours <= 3
              ? 95
              : hours <= 5
              ? 80
              : hours <= 7
              ? 60
              : hours <= 9
              ? 40
              : 20)
          .clamp(0, 100);
      if (!mounted) return;
      setState(() {
        usageLine = '${fmtSecs(secs)} · $unlocks unlocks';
        usageRating = rating;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theory = subjects.where((s) => !s.isLab).toList()
      ..sort((a, b) => a.percent.compareTo(b.percent));
    final risk = theory.where((s) => s.percent < 75).take(3).toList();
    final overall = overallPercent(subjects);
    final last = Store.read<String>(lastSyncKey);
    final protein = (Store.read<List>('diet') ?? [])
        .cast<Map<String, dynamic>>()
        .where((e) => e['date'] == DateTime.now().toIso8601String().substring(0, 10))
        .fold<num>(0, (a, e) => a + (num.tryParse('${e['protein']}') ?? 0));
    final pTarget = goal?.proteinTarget;
    final gateSubjects = gate.studySubjects;
    final gateTotal = gateSubjects.fold<int>(0, (a, s) => a + s.total);
    final gateDone = gateSubjects.fold<int>(0, (a, s) => a + s.completed);
    final gatePct = gateTotal == 0 ? 0.0 : gateDone / gateTotal;
    final gateConnected = gate.batchName.isNotEmpty || gateSubjects.isNotEmpty;

    return FocusPage(
      subtitle: last == null ? 'Welcome' : 'Synced ${last.substring(5, 16).replaceFirst('T', ' · ')}',
      title: 'Today',
      hue: Dissolve.accent,
      children: [
        Panel(
          glow: scoreColor(overall, 50),
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Ring(
                value: overall / 100,
                size: 108,
                stroke: 10,
                color: scoreColor(overall, 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NumberTicker(overall.toStringAsFixed(0), style: Typo.metric),
                    Text('%', style: Typo.caption),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance', style: Typo.heading),
                    const SizedBox(height: 4),
                    Text(
                      risk.isEmpty
                          ? 'All theory subjects above 75%'
                          : '${risk.length} below 75%',
                      style: Typo.caption,
                    ),
                    if (risk.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final s in risk)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(s.name, style: Typo.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text(
                                '${s.percent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: scoreColor(s.percent, 75),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _tile(
                'GATE',
                !gateConnected ? 'Not connected' : '${(gatePct * 100).round()}%',
                Hue.gate,
                gatePct,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tile(
                'Focus',
                scrollScore < 0 ? '—' : '$scrollScore',
                Hue.focus,
                scrollScore < 0 ? 0 : scrollScore / 100,
                caption: scrollScore >= goodDay ? 'good day' : scrollScore < 0 ? null : 'tighten up',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _tile(
                'Weight',
                weight == null ? 'Set goal' : '${weight!.toStringAsFixed(1)} kg',
                Hue.body,
                goal == null || weight == null ? 0 : goal!.progress(weight!),
                caption: goal == null ? null : 'BMI ${goal!.bmiAt(weight!).toStringAsFixed(1)}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tile(
                'Protein',
                pTarget == null ? '$protein g' : '$protein / $pTarget g',
                Dissolve.sky,
                pTarget == null ? 0 : (protein / pTarget).clamp(0, 1).toDouble(),
              ),
            ),
          ],
        ),
        if (usageLine != null)
          Panel(
            glow: usageRating == null ? null : scoreColor(usageRating!.toDouble(), 70),
            child: Row(
              children: [
                Icon(Icons.phone_android_rounded, color: Dissolve.muted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phone today', style: Typo.heading.copyWith(fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Text(usageLine!, style: Typo.caption),
                    ],
                  ),
                ),
                if (usageRating != null)
                  Text(
                    '$usageRating',
                    style: Typo.metric.copyWith(
                      fontSize: 22,
                      color: scoreColor(usageRating!.toDouble(), 70),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(String label, String value, Color hue, double progress, {String? caption}) => Panel(
    glow: hue,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: Typo.label.copyWith(color: hue)),
        const SizedBox(height: 10),
        Text(value, style: Typo.heading),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption, style: Typo.caption),
        ],
        const SizedBox(height: 12),
        Bar(value: progress, color: hue, height: 6),
      ],
    ),
  );
}
