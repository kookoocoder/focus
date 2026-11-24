import 'package:flutter/material.dart';

import '../../core/store.dart';
import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import 'attendance.dart';
import 'attendance_sync.dart';

/// Read-only view of ERP attendance. Syncs automatically when opened.
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
        ? Duration(days: 1)
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
        SnackBar(
          content: Text('Just synced. Try again in ${wait.inMinutes + 1} min.'),
        ),
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

  @override
  Widget build(BuildContext context) {
    final overall = overallPercent(subjects);
    final last = Store.read<String>(lastSyncKey);
    final theory = subjects.where((s) => !s.isLab).toList()
      ..sort((a, b) => a.percent.compareTo(b.percent));
    final labs = subjects.where((s) => s.isLab).toList();
    final atRisk = theory.where((s) => s.percent < 75).length;
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
      ],
      children: [
        if (error != null)
          Panel(
            glow: Dissolve.danger,
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: Dissolve.danger, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ERP sync failed\n$error',
                    style: TextStyle(color: Dissolve.danger, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Panel(
          glow: color,
          padding: EdgeInsets.all(22),
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
                    NumberTicker(
                      overall.toStringAsFixed(1),
                      style: Typo.metric,
                    ),
                    Text('%', style: Typo.caption),
                  ],
                ),
              ),
              SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall', style: Typo.heading),
                    SizedBox(height: 2),
                    Text('Minimum 50%', style: Typo.caption),
                    SizedBox(height: 16),
                    _stat('${theory.length}', 'theory'),
                    SizedBox(height: 6),
                    _stat(
                      '$atRisk',
                      'below 75%',
                      color: atRisk > 0 ? Dissolve.danger : Dissolve.success,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (theory.isNotEmpty) SectionLabel('Theory · lowest first'),
        for (final s in theory) _tile(s),
        if (labs.isNotEmpty) SectionLabel('Labs & non-theory · no 75% rule'),
        for (final s in labs) _tile(s),
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
              Expanded(
                child: Text(
                  s.name,
                  style: Typo.heading.copyWith(fontSize: 15.5),
                ),
              ),
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
          Text(
            '${s.attended}/${s.total} attended  ·  ${verdict(s)}',
            style: Typo.caption,
          ),
        ],
      ),
    );
  }
}
