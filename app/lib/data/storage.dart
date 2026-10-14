import 'package:shared_preferences/shared_preferences.dart';

/// Where the app keeps its single JSON document.
abstract class Storage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

class PrefsStorage implements Storage {
  static const key = 'glassful.v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read() async => (await _prefs).getString(key);

  @override
  Future<void> write(String data) async {
    await (await _prefs).setString(key, data);
  }

  @override
  Future<void> clear() async {
    await (await _prefs).remove(key);
  }
}
