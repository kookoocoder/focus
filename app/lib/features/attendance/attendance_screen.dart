import 'package:flutter/material.dart';

import '../../core/store.dart';
import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import 'attendance.dart';
import 'attendance_sync.dart';

/// Clean attendance view: overall ring + subjects below 75%. Full list opens
/// behind Details.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Subject> subjects = loadSubjects();
  String? error;
  bool syncing = false;

  static const _autoAfter = Duration(hours: 1);
  static const _manualGap = Duration(minutes: 5);

  Duration get _sinceSync {
    final last = Store.read<String>(lastSyncKey);
    return last == null
        ? const Duration(days: 1)
        : DateTime.now().difference(DateTime.parse(last));
  }

  @override
  void initState() {
    super.initState();
    if (_sinceSync > _autoAfter) _sync();
  }

  Future<void> _manualSync() async {
    final wait = _manualGap - _sinceSync;
    if (wait > Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Just synced. Try again in ${wait.inMinutes + 1} min.')),
      );
      return;
    }
    await _sync();
  }

  Future<void> _sync() async {
    if (syncing) return;
    setState(() => syncing = true);
    try {
      subjects = await syncFromErp();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => syncing = false);
  }

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AttendanceDetails(subjects: subjects),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overall = overallPercent(subjects);
    final last = Store.read<String>(lastSyncKey);
    final theory = subjects.where((s) => !s.isLab).toList()
      ..sort((a, b) => a.percent.compareTo(b.percent));
    final atRisk = theory.where((s) => s.percent < 75).toList();
    final color = scoreColor(overall, 50);
    return FocusPage(
      subtitle: last == null
          ? 'Not synced yet'
          : 'Synced ${last.substring(5, 16).replaceFirst('T', ' · ')}',
      title: 'Attendance',
      hue: Hue.classes,
      busy: syncing,
      onRefresh: _manualSync,
      actions: [
        GlassIcon(
          icon: Icons.sync_rounded,
          tooltip: 'Update from ERP',
          onTap: syncing ? null : _manualSync,
        ),
        GlassIcon(
          icon: Icons.list_alt_rounded,
          tooltip: 'All subjects',
          onTap: _openDetails,
        ),
      ],
      children: [
        if (error != null)
          Panel(
            glow: Dissolve.danger,
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: Dissolve.danger, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('ERP sync failed\n$error', style: TextStyle(color: Dissolve.danger, fontSize: 13)),
                ),
              ],
            ),
          ),
        Panel(
          glow: color,
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Ring(
                value: overall / 100,
                size: 128,
                stroke: 11,
                color: color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NumberTicker(overall.toStringAsFixed(1), style: Typo.metric),
                    Text('%', style: Typo.caption),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall', style: Typo.heading),
                    const SizedBox(height: 2),
                    Text('Minimum 50%', style: Typo.caption),
                    const SizedBox(height: 16),
                    _stat('${theory.length}', 'theory'),
                    const SizedBox(height: 6),
                    _stat(
                      '${atRisk.length}',
                      'below 75%',
                      color: atRisk.isNotEmpty ? Dissolve.danger : Dissolve.success,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (atRisk.isEmpty)
          Panel(
            glow: Dissolve.success,
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Dissolve.success, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Every theory subject is above 75%. Tap Details for the full list.',
                    style: Typo.body,
                  ),
                ),
              ],
            ),
          )
        else ...[
          SectionLabel('Needs attention'),
          for (final s in atRisk) _tile(s),
        ],
        Panel(
          onTap: _openDetails,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(child: Text('All subjects', style: Typo.heading.copyWith(fontSize: 15.5))),
              Text('${subjects.length}', style: Typo.caption),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Dissolve.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String n, String l, {Color? color}) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color ?? Dissolve.fg, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(n, style: TextStyle(color: color ?? Dissolve.fg, fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      Text(l, style: Typo.caption),
    ],
  );

  Widget _tile(Subject s) {
    final color = s.isLab ? Hue.classes : scoreColor(s.percent, 75);
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(s.name, style: Typo.heading.copyWith(fontSize: 15.5))),
              const SizedBox(width: 12),
              NumberTicker(
                '${s.percent.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Bar(value: s.percent / 100, color: color, height: 8),
          const SizedBox(height: 10),
          Text('${s.attended}/${s.total} attended  ·  ${verdict(s)}', style: Typo.caption),
        ],
      ),
    );
  }
}

class _AttendanceDetails extends StatelessWidget {
  const _AttendanceDetails({required this.subjects});
  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    final theory = subjects.where((s) => !s.isLab).toList()
      ..sort((a, b) => a.percent.compareTo(b.percent));
    final labs = subjects.where((s) => s.isLab).toList();
    return FocusPage(
      subtitle: '${subjects.length} subjects',
      title: 'Details',
      hue: Hue.classes,
      showSettings: false,
      actions: [
        GlassIcon(icon: Icons.close_rounded, tooltip: 'Close', onTap: () => Navigator.pop(context)),
      ],
      children: [
        if (theory.isNotEmpty) SectionLabel('Theory · lowest first'),
        for (final s in theory) _row(s),
        if (labs.isNotEmpty) SectionLabel('Labs & non-theory'),
        for (final s in labs) _row(s),
      ],
    );
  }

  Widget _row(Subject s) {
    final color = s.isLab ? Hue.classes : scoreColor(s.percent, 75);
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.name, style: Typo.heading.copyWith(fontSize: 15.5))),
              Text(
                '${s.percent.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Bar(value: s.percent / 100, color: color, height: 8),
          const SizedBox(height: 10),
          Text('${s.attended}/${s.total} attended  ·  ${verdict(s)}', style: Typo.caption),
        ],
      ),
    );
  }
}
