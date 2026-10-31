import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// Legt den letzten Stand in den lokalen Einstellungen des Geräts ab.
class PrefsSnapshotCache implements SnapshotCache {
  static const _key = 'thask_snapshot';

  @override
  Future<String?> load() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String json) async => (await SharedPreferences.getInstance()).setString(_key, json);

  @override
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}
