import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ERP login. Baked in at build time from the git-ignored `.env`
/// (`--dart-define-from-file=../.env`), then kept in Android secure storage.
class Credentials {
  static const _s = FlutterSecureStorage();
  static const _buildId = String.fromEnvironment('ERP_ID');
  static const _buildPw = String.fromEnvironment('ERP_PASSWORD');

  static Future<(String?, String?)> load() async {
    final id = await _s.read(key: 'erp_id');
    final pw = await _s.read(key: 'erp_pw');
    if (id != null && pw != null) return (id, pw);
    if (_buildId.isNotEmpty && _buildPw.isNotEmpty) {
      await save(_buildId, _buildPw);
      return (_buildId, _buildPw);
    }
    return (null, null);
  }

  static Future<void> save(String id, String pw) async {
    await _s.write(key: 'erp_id', value: id);
    await _s.write(key: 'erp_pw', value: pw);
  }
}
