import 'package:flutter/material.dart';

import 'pw_data.dart';
import 'pw_webview.dart';

/// Visible PW login/browse screen. Needed once (and again only if PW logs you out).
class PwConnectScreen extends StatefulWidget {
  const PwConnectScreen({super.key});
  @override
  State<PwConnectScreen> createState() => _PwConnectScreenState();
}

class _PwConnectScreenState extends State<PwConnectScreen> {
  final course = PwCourse.load();
  final kinds = <String>{};

  @override
  Widget build(BuildContext context) {
    final hint = kinds.contains('progress')
        ? 'All set ✓'
        : kinds.isEmpty
        ? 'Open your batch'
        : 'Now open Subjects';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect PW'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(hint),
            ),
          ),
        ],
      ),
      body: PwWebView(
        url: 'https://www.pw.live/study-v2/batches',
        course: course,
        onCaptured: (k) => setState(() => kinds.add(k)),
      ),
    );
  }
}
