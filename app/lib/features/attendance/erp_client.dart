import 'dart:convert';
import 'dart:io';

class ErpException implements Exception {
  final String message;
  ErpException(this.message);
  @override
  String toString() => message;
}

/// One subject's attendance as reported by the ERP.
class ErpSubject {
  final String name;
  final int present;
  final int absent;
  ErpSubject(this.name, this.present, this.absent);
}

/// Minimal client for the JUNO ERP (erp.mit.asia): password login, then reads
/// the current semester's attendance counts. Read-only.
class ErpClient {
  static const _base = 'https://erp.mit.asia';
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  final Map<String, String> _cookies = {};

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<(int, String, String?)> _send(String method, Uri uri,
      {Map<String, String>? form}) async {
    final req = await _http.openUrl(method, uri);
    req.followRedirects = false;
    req.headers.set(HttpHeaders.cookieHeader, _cookieHeader);
    req.headers.set('X-Requested-With', 'XMLHttpRequest');
    if (form != null) {
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
      req.write(form.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&'));
    }
    final res = await req.close();
    for (final c in res.cookies) {
      _cookies[c.name] = c.value;
    }
    final body = await res.transform(utf8.decoder).join();
    return (res.statusCode, body, res.headers.value(HttpHeaders.locationHeader));
  }

  Future<String> _get(String path, [Map<String, String>? q]) async {
    var uri = Uri.parse('$_base/$path').replace(queryParameters: q);
    for (var i = 0; i < 6; i++) {
      final (code, body, loc) = await _send('GET', uri);
      if (code >= 300 && code < 400 && loc != null) {
        uri = uri.resolve(loc);
        continue;
      }
      return body;
    }
    throw ErpException('Too many redirects');
  }

  Future<void> login(String id, String password) async {
    await _get('login.htm');
    var (code, _, loc) = await _send(
        'POST', Uri.parse('$_base/j_spring_security_check'),
        form: {'j_username': id, 'j_password': password});
    var hops = 0;
    while (code >= 300 && code < 400 && loc != null && hops++ < 6) {
      if (loc.contains('login.htm') || loc.contains('error')) {
        throw ErpException('ERP login failed (wrong ID/password, or OTP required)');
      }
      final r = await _send('GET', Uri.parse(_base).resolve(loc));
      code = r.$1;
      loc = r.$3;
    }
    if (!_cookies.containsKey('JSESSIONID')) {
      throw ErpException('ERP login failed');
    }
  }

  /// Attendance for the semester currently marked active by the ERP.
  Future<List<ErpSubject>> fetchAttendance() async {
    final termsRaw = await _get('stu_getTermsOfStudentForCourceFile.json');
    final List terms;
    try {
      terms = jsonDecode(termsRaw) as List;
    } catch (_) {
      throw ErpException('Not logged in or ERP returned unexpected data');
    }
    final t = terms.cast<Map<String, dynamic>>().firstWhere(
          (x) => x['terms2Status'] == true,
          orElse: () => terms.last as Map<String, dynamic>,
        );
    final body = await _get('stu_getSubjectOnChangeWithSemId1.json', {
      'termId': '${t['semesterId']}',
      'refreshData': '0',
      'subjectwisestudentids': '${t['subjectwiseStudentIds']}',
      'subejctwiseBatchIds': '${t['subejctwiseBatchIds']}',
      'batchsemestercapacity': '${t['batchsemesterCapacity']}',
    });
    final list = jsonDecode(body) as List;
    return [
      for (final s in list.cast<Map<String, dynamic>>())
        ErpSubject(
          '${s['subject']}'.trim(),
          (s['presentCount'] as num?)?.toInt() ?? 0,
          (s['absentCount'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  void close() => _http.close(force: true);
}
