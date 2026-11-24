import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import 'pw_auto_refresh.dart';
import 'pw_connect_screen.dart';
import 'pw_data.dart';

/// GATE 2028 (CSE) progress, taken only from your PW batch.
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  // GATE 2028 exam date is not announced yet; Feb 2028 is the target.
  static final target = DateTime(2028, 2, 1);
  PwCourse course = PwCourse.load();
  bool autoRefreshing = PwAutoRefresh.due;

  @override
  void initState() {
    super.initState();
    _importOldCapture();
  }

  /// One-time import of the first raw capture, then delete it (it held tokens).
  Future<void> _importOldCapture() async {
    final f = File(
      '${(await getApplicationDocumentsDirectory()).path}/pw_capture.jsonl',
    );
    if (!await f.exists()) return;
    course = await rebuildFromCapture();
    await f.delete();
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PwConnectScreen()),
    );
    setState(() => course = PwCourse.load());
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final days = target.difference(DateTime.now()).inDays;
    final subjects = course.studySubjects;
    final total = subjects.fold<int>(0, (a, s) => a + s.total);
    final done = subjects.fold<int>(0, (a, s) => a + s.completed);
    final today = DateTime.now();
    final todays = course.schedule
        .where(
          (l) =>
              l.start.year == today.year &&
              l.start.month == today.month &&
              l.start.day == today.day,
        )
        .toList();

    final pct = total == 0 ? 0.0 : done / total;
    return FocusPage(
      subtitle: course.batchName.isEmpty ? 'Target · Feb 2028' : course.batchName,
      title: 'GATE 2028',
      hue: Hue.gate,
      actions: [
        GlassIcon(
          icon: course.subjects.isEmpty ? Icons.link_rounded : Icons.sync_rounded,
          tooltip: course.subjects.isEmpty ? 'Connect PW' : 'Update',
          onTap: _refresh,
        ),
      ],
      children: [
        Panel(
          glow: Dissolve.accent,
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NumberTicker(
                      '$days',
                      style: Typo.display,
                    ),
                    const SizedBox(height: 4),
                    Text('days to go', style: Typo.caption),
                  ],
                ),
              ),
              if (total > 0)
                Ring(
                  value: pct,
                  size: 96,
                  stroke: 8,
                  color: Dissolve.accent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(pct * 100).round()}%', style: Typo.metric.copyWith(fontSize: 20)),
                      Text('$done/$total', style: TextStyle(color: Dissolve.muted, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (course.subjects.isEmpty)
          Panel(
            onTap: _refresh,
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                Icon(Icons.link_rounded, color: Dissolve.accent),
                SizedBox(height: 10),
                Text('Connect PW', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                SizedBox(height: 6),
                Text(
                  'Log in and open your batch. Subjects and lectures come straight from PW.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Dissolve.muted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        if (todays.isNotEmpty) ...[
          SectionLabel("Today's lectures"),
          for (final l in todays)
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Dissolve.accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _hm(l.start),
                      style: TextStyle(color: Dissolve.accent, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.subject, style: Typo.heading.copyWith(fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text(l.topic, style: Typo.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (subjects.isNotEmpty) SectionLabel('Subjects'),
        for (final s in subjects)
          Panel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s.name, style: Typo.heading.copyWith(fontSize: 15.5))),
                    Text(
                      s.total == 0 ? 'not started' : '${s.completed}/${s.total}',
                      style: TextStyle(
                        color: s.total > 0 && s.completed == s.total ? Dissolve.success : Dissolve.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (s.total > 0) ...[
                  const SizedBox(height: 12),
                  Bar(
                    value: s.completed / s.total,
                    color: s.completed == s.total ? Dissolve.success : Hue.gate,
                    height: 8,
                  ),
                ],
              ],
            ),
          ),
        if (course.updated != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'From PW · ${course.updated!.substring(0, 16).replaceFirst('T', ' ')}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Dissolve.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
