import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/attendance/erp_client.dart';

/// ERP login the user entered in onboarding or Settings, kept in Android
/// secure storage. Nothing is baked into the build.
class Credentials {
  static const _s = FlutterSecureStorage();

  static Future<(String?, String?)> load() async =>
      (await _s.read(key: 'erp_id'), await _s.read(key: 'erp_pw'));

  static Future<String?> id() => _s.read(key: 'erp_id');

  static Future<void> save(String id, String pw) async {
    await _s.write(key: 'erp_id', value: id);
    await _s.write(key: 'erp_pw', value: pw);
  }

  static Future<void> clear() async {
    await _s.delete(key: 'erp_id');
    await _s.delete(key: 'erp_pw');
  }

  /// Logs in once to check the pair, and saves it only if the ERP accepts it.
  static Future<void> connect(String id, String pw) async {
    final erp = ErpClient();
    try {
      await erp.login(id, pw);
    } finally {
      erp.close();
    }
    await save(id, pw);
  }
}
