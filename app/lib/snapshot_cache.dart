import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// Legt den letzten Stand in den lokalen Einstellungen des Geräts ab.
class PrefsSnapshotCache implements SnapshotCache {
  static const _key = 'thask_snapshot';
  static const _outboxKey = 'thask_outbox';

  @override
  Future<String?> load() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String json) async => (await SharedPreferences.getInstance()).setString(_key, json);

  @override
  Future<String?> loadOutbox() async => (await SharedPreferences.getInstance()).getString(_outboxKey);

  @override
  Future<void> saveOutbox(String json) async => (await SharedPreferences.getInstance()).setString(_outboxKey, json);

  @override
  Future<String?> loadSetting(String key) async => (await SharedPreferences.getInstance()).getString('thask_$key');

  @override
  Future<void> saveSetting(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString('thask_$key', value);

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_outboxKey);
  }
}
