import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'pw_data.dart';
import 'pw_webview.dart';

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
  final course = PwCourse.load();
  final pages = pwPages().values.toSet().toList();

  Future<void> _run(InAppWebViewController c) async {
    for (var i = 0; i < pages.length; i++) {
      if (i > 0) await c.loadUrl(urlRequest: URLRequest(url: WebUri(pages[i])));
      await Future.delayed(const Duration(seconds: 15));
      if (!mounted) return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1,
    height: 1,
    child: PwWebView(url: pages.first, course: course, onCreated: _run),
  );
}
