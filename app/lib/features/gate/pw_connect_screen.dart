import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens PW in a WebView so you log in with your own OTP. While you browse
/// your batch, PW's own API responses are recorded locally (pw_capture.jsonl)
/// so the course structure can be imported. Nothing leaves the phone.
class PwConnectScreen extends StatefulWidget {
  const PwConnectScreen({super.key});
  @override
  State<PwConnectScreen> createState() => _PwConnectScreenState();
}

const _hook = r'''
(function () {
  if (window.__focusHook) return;
  window.__focusHook = true;
  const want = (u) => /penpencil|api\.pw\.live|pw\.live\/api/i.test(u);
  const send = (url, auth, body) => {
    try {
      if (!body || body[0] !== '{' && body[0] !== '[') return;
      FocusCapture.postMessage(JSON.stringify({url, auth, body: body.slice(0, 300000)}));
    } catch (e) {}
  };
  const of = window.fetch;
  window.fetch = async function (input, init) {
    const res = await of.apply(this, arguments);
    try {
      const url = typeof input === 'string' ? input : input.url;
      if (want(url)) {
        let auth = null;
        const h = (init && init.headers) || (input && input.headers);
        if (h) auth = h.get ? h.get('Authorization') : (h.Authorization || h.authorization);
        res.clone().text().then((t) => send(url, auth, t));
      }
    } catch (e) {}
    return res;
  };
  const oo = XMLHttpRequest.prototype.open, os = XMLHttpRequest.prototype.send,
        sh = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.open = function (m, u) { this.__u = u; return oo.apply(this, arguments); };
  XMLHttpRequest.prototype.setRequestHeader = function (k, v) {
    if (/^authorization$/i.test(k)) this.__a = v;
    return sh.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    this.addEventListener('load', () => {
      try { if (want(this.__u)) send(this.__u, this.__a || null, this.responseText); } catch (e) {}
    });
    return os.apply(this, arguments);
  };
})();
''';

class _PwConnectScreenState extends State<PwConnectScreen> {
  late final WebViewController _c;
  IOSink? _out;
  int captured = 0;

  @override
  void initState() {
    super.initState();
    _open();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FocusCapture', onMessageReceived: (m) {
        _out?.writeln(m.message);
        setState(() => captured++);
      })
      ..setNavigationDelegate(NavigationDelegate(
        // Truecaller and other app links can't open in a WebView; stay on the
        // page so PW falls back to SMS OTP.
        onNavigationRequest: (r) => r.url.startsWith('http')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageStarted: (_) => _c.runJavaScript(_hook),
        onPageFinished: (_) => _c.runJavaScript(_hook),
      ))
      ..loadRequest(Uri.parse('https://www.pw.live/study-v2/batches'));
  }

  Future<void> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    _out = File('${dir.path}/pw_capture.jsonl').openWrite(mode: FileMode.append);
    _out!.writeln(jsonEncode({'session': DateTime.now().toIso8601String()}));
  }

  @override
  void dispose() {
    _out?.close();
    super.dispose();
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
            child: Text('$captured captured'),
          )),
        ],
      ),
      body: WebViewWidget(controller: _c),
    );
  }
}
