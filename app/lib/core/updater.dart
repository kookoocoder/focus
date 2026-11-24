import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../ui/kit.dart';
import '../ui/tokens.dart';

const _ch = MethodChannel('focus/app');
const _repo = 'kookoocoder/focus';

/// Baked in by `tool/release.sh` via --dart-define.
const channel = String.fromEnvironment('CHANNEL', defaultValue: 'local');
const gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'dev');
const _token = String.fromEnvironment('GITHUB_TOKEN');

class AppVersion {
  const AppVersion(this.name, this.code);
  final String name;
  final int code;
  @override
  String toString() => '$name ($code) · $channel · $gitSha';
}

/// versionName/versionCode as Android sees them (same values `adb shell
/// dumpsys package` reports).
Future<AppVersion> appVersion() async {
  try {
    final m = await _ch.invokeMapMethod<String, Object?>('version');
    return AppVersion('${m!['name']}', (m['code'] as num).toInt());
  } on MissingPluginException {
    return const AppVersion('0.0.0', 0);
  }
}

class Release {
  Release(this.tag, this.build, this.notes, this.assetUrl, this.size, this.dev);
  final String tag;
  final int build;
  final String notes;
  final String assetUrl;
  final int size;
  final bool dev;
}

/// Newest release on this build's channel. Dev builds also take stable
/// releases when those are newer.
Future<Release?> latestRelease() async {
  if (_token.isEmpty) return null;
  final r = await http.get(
    Uri.parse('https://api.github.com/repos/$_repo/releases?per_page=30'),
    headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/vnd.github+json'},
  );
  if (r.statusCode != 200) throw 'GitHub ${r.statusCode}';
  Release? best;
  for (final j in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>()) {
    final dev = j['prerelease'] == true;
    if (dev && channel != 'dev') continue;
    final build = int.tryParse(RegExp(r'(\d+)$').stringMatch('${j['tag_name']}') ?? '');
    final apk = (j['assets'] as List).cast<Map<String, dynamic>>().where(
      (a) => '${a['name']}'.endsWith('.apk'),
    );
    if (build == null || apk.isEmpty) continue;
    if (best == null || build > best.build) {
      best = Release(
        '${j['tag_name']}',
        build,
        '${j['body'] ?? ''}'.trim(),
        '${apk.first['url']}',
        (apk.first['size'] as num).toInt(),
        dev,
      );
    }
  }
  return best;
}

/// On launch: if a newer build exists, offer it.
Future<void> checkForUpdate(GlobalKey<NavigatorState> nav, {bool manual = false}) async {
  try {
    final (v, r) = (await appVersion(), await latestRelease());
    final ctx = nav.currentContext;
    if (ctx == null || !ctx.mounted) return;
    if (r == null || r.build <= v.code) {
      if (manual) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(_token.isEmpty ? 'Updates are off in this build' : 'You are on the latest build')),
        );
      }
      return;
    }
    await showDialog<void>(context: ctx, builder: (_) => _UpdateDialog(v, r));
  } catch (e) {
    final ctx = nav.currentContext;
    if (manual && ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Update check failed: $e')));
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog(this.current, this.release);
  final AppVersion current;
  final Release release;
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> with WidgetsBindingObserver {
  double? progress;
  String? status;
  File? apk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the "install unknown apps" screen: try again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && apk != null && status == 'permission') _install();
  }

  Future<void> _download() async {
    setState(() => progress = 0);
    try {
      final req = http.Request('GET', Uri.parse(widget.release.assetUrl))
        ..headers.addAll({'Authorization': 'Bearer $_token', 'Accept': 'application/octet-stream'});
      final res = await http.Client().send(req);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final f = File('${(await getTemporaryDirectory()).path}/update-${widget.release.build}.apk');
      final sink = f.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (mounted) setState(() => progress = got / widget.release.size);
      }
      await sink.close();
      apk = f;
      await _install();
    } catch (e) {
      if (mounted) {
        setState(() {
          progress = null;
          status = 'Download failed: $e';
        });
      }
    }
  }

  Future<void> _install() async {
    final r = await _ch.invokeMethod<String>('install', {'path': apk!.path});
    if (!mounted) return;
    setState(() => status = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    final mb = (r.size / 1048576).toStringAsFixed(1);
    final busy = progress != null && apk == null;
    return AlertDialog(
      title: Text('Update to build ${r.build}', style: Typo.heading.copyWith(fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.dev ? 'Dev' : 'Stable'} · $mb MB · you have ${widget.current.code}',
            style: Typo.caption,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Text(r.notes.isEmpty ? 'No notes.' : r.notes, style: Typo.body),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 18),
            Bar(value: progress!, color: Dissolve.accent, height: 8),
            const SizedBox(height: 6),
            Text(
              apk == null ? '${(progress! * 100).round()}%' : 'Downloaded',
              style: Typo.caption,
            ),
          ],
          if (status == 'permission') ...[
            const SizedBox(height: 12),
            Text(
              'Allow "Install unknown apps" for Focus, then come back. One time only.',
              style: Typo.caption,
            ),
          ] else if (status != null && status != 'started') ...[
            const SizedBox(height: 12),
            Text(status!, style: Typo.caption.copyWith(color: Dissolve.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
        FilledButton(
          onPressed: busy ? null : (apk == null ? _download : _install),
          child: Text(apk == null ? 'Update' : 'Install'),
        ),
      ],
    );
  }
}
