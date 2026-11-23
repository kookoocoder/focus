import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'pw_connect_screen.dart';
import 'pw_data.dart';

/// Invisible 1x1 WebView that reloads the remembered PW pages so PW's own
/// site fetches fresh data, then calls [onDone]. Uses PW's saved web login.
class PwAutoRefresh extends StatefulWidget {
  final VoidCallback onDone;
  const PwAutoRefresh({super.key, required this.onDone});

  static const every = Duration(hours: 6);

  static bool get due {
    if (pwPages().isEmpty) return false;
    final u = PwCourse.load().updated;
    return u == null || DateTime.now().difference(DateTime.parse(u)) > every;
  }

  @override
  State<PwAutoRefresh> createState() => _PwAutoRefreshState();
}

class _PwAutoRefreshState extends State<PwAutoRefresh> {
  late final WebViewController _c;
  final course = PwCourse.load();

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FocusCapture',
        onMessageReceived: (m) {
          final j = jsonDecode(m.message) as Map<String, dynamic>;
          if (course.ingest(j['url'], j['body']) != null) course.save();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) => r.url.startsWith('http')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (_) => _c.runJavaScript(pwHook),
          onPageFinished: (_) => _c.runJavaScript(pwHook),
        ),
      );
    _run();
  }

  Future<void> _run() async {
    for (final page in pwPages().values.toSet()) {
      await _c.loadRequest(Uri.parse(page));
      await Future.delayed(const Duration(seconds: 15));
      if (!mounted) return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 1, height: 1, child: WebViewWidget(controller: _c));
}
