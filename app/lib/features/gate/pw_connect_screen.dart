import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'pw_data.dart';

/// Opens PW in a WebView so you log in with your own OTP. While PW loads your
/// batch, its course/progress/schedule responses are read into [PwCourse].
/// Nothing leaves the phone and no login token is stored by Focus.
class PwConnectScreen extends StatefulWidget {
  const PwConnectScreen({super.key});
  @override
  State<PwConnectScreen> createState() => _PwConnectScreenState();
}

const _hook = r'''
(function () {
  if (window.__focusHook) return;
  window.__focusHook = true;
  const want = (u) => /api\.penpencil\.co\/.*(\/v3\/batches\/[^/]+\/details|\/subject\/progress|\/todays-schedule)/i.test(u);
  const send = (url, body) => {
    try {
      if (body && body[0] === '{') FocusCapture.postMessage(JSON.stringify({url, body}));
    } catch (e) {}
  };
  const of = window.fetch;
  window.fetch = async function (input) {
    const res = await of.apply(this, arguments);
    try {
      const url = typeof input === 'string' ? input : input.url;
      if (want(url)) res.clone().text().then((t) => send(url, t));
    } catch (e) {}
    return res;
  };
  const oo = XMLHttpRequest.prototype.open, os = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) { this.__u = u; return oo.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function () {
    this.addEventListener('load', () => {
      try { if (want(this.__u)) send(this.__u, this.responseText); } catch (e) {}
    });
    return os.apply(this, arguments);
  };
})();
''';

class _PwConnectScreenState extends State<PwConnectScreen> {
  late final WebViewController _c;
  final course = PwCourse.load();
  int captured = 0;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FocusCapture',
        onMessageReceived: (m) {
          final j = jsonDecode(m.message) as Map<String, dynamic>;
          if (course.ingest(j['url'], j['body'])) {
            course.save();
            setState(() => captured++);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          // Truecaller and other app links can't open in a WebView; stay on the
          // page so PW falls back to SMS OTP.
          onNavigationRequest: (r) => r.url.startsWith('http')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (_) => _c.runJavaScript(_hook),
          onPageFinished: (_) => _c.runJavaScript(_hook),
        ),
      )
      ..loadRequest(Uri.parse('https://www.pw.live/study-v2/batches'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect PW'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                captured == 0 ? 'Open your batch' : '$captured updated ✓',
              ),
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: _c),
    );
  }
}
