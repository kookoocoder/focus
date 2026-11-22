import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ERP login kept in the Android Keystore-backed secure storage on the device.
class Credentials {
  static const _s = FlutterSecureStorage();

  static Future<(String?, String?)> load() async =>
      (await _s.read(key: 'erp_id'), await _s.read(key: 'erp_pw'));

  static Future<void> save(String id, String pw) async {
    await _s.write(key: 'erp_id', value: id);
    await _s.write(key: 'erp_pw', value: pw);
  }
}
