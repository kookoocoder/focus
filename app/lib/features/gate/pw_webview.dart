import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'pw_data.dart';

/// Injected before PW's own scripts run, so even the very first API calls of a
/// page load are seen. Only batch details, subject progress and today's
/// schedule are forwarded; nothing else (no tokens) is read.
const _hook = r'''
(function () {
  if (window.__focusHook) return;
  window.__focusHook = true;
  const want = (u) => /api\.penpencil\.co\/.*(\/v3\/batches\/[^/]+\/details|\/subject\/progress|\/todays-schedule)/i.test(u);
  const queue = [];
  let ready = false;
  const flush = () => { while (ready && queue.length) window.flutter_inappwebview.callHandler('FocusCapture', queue.shift()); };
  window.addEventListener('flutterInAppWebViewPlatformReady', () => { ready = true; flush(); });
  const send = (url, body) => {
    if (!body || body[0] !== '{') return;
    queue.push(JSON.stringify({url, body, page: location.href}));
    flush();
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

/// PW site in a WebView that feeds captured data into [PwCourse].
class PwWebView extends StatelessWidget {
  final String url;
  final PwCourse course;
  final void Function(String kind)? onCaptured;
  final void Function(InAppWebViewController c)? onCreated;

  const PwWebView({
    super.key,
    required this.url,
    required this.course,
    this.onCaptured,
    this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
      ),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: _hook,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      // Truecaller and other app links can't open here; staying on the page
      // makes PW fall back to SMS OTP.
      shouldOverrideUrlLoading: (_, action) async =>
          action.request.url?.scheme.startsWith('http') == true
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL,
      onWebViewCreated: (c) {
        c.addJavaScriptHandler(
          handlerName: 'FocusCapture',
          callback: (args) {
            final j = jsonDecode(args.first as String) as Map<String, dynamic>;
            final kind = course.ingest(j['url'], j['body']);
            if (kind == null) return;
            course.save();
            rememberPwPage(kind, j['page']);
            onCaptured?.call(kind);
          },
        );
        onCreated?.call(c);
      },
    );
  }
}
