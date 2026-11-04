/// Updates der App aus den öffentlichen GitHub-Releases: unter Android die APK, unter Windows das Setup.
///
/// Ein Release enthält die Apps als `thask-<Version>.apk` und `thask-setup-<Version>.exe`; die Version
/// der Apps ist eine andere als die der Integration im Tag. Gesucht wird deshalb über die letzten
/// Releases nach der höchsten App-Version, nicht nur im neuesten.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const releasesRepo = 'Schumey/tHAsk';

class AppUpdate {
  const AppUpdate({required this.version, required this.name, required this.url, required this.size, this.sha256});

  final String version;
  final String name;
  final Uri url;
  final int size;

  /// Prüfsumme, die GitHub für das Asset angibt (ohne „sha256:“), falls vorhanden.
  final String? sha256;
}

/// „0.9.14“ → [0, 9, 14]; Unlesbares zählt als 0.
List<int> parseVersion(String version) =>
    [for (final part in version.split('+').first.split('.')) int.tryParse(part) ?? 0];

int compareVersions(String a, String b) {
  final x = parseVersion(a), y = parseVersion(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// Name des Assets für die Plattform, mit der Version als Gruppe 1.
RegExp? assetPattern(String platform) => switch (platform) {
      'android' => RegExp(r'^thask-(\d+(?:\.\d+)*)\.apk$'),
      'windows' => RegExp(r'^thask-setup-(\d+(?:\.\d+)*)\.exe$'),
      _ => null,
    };

/// Das neueste Asset für [platform] aus der Antwort von `GET /repos/…/releases`, wenn es neuer als
/// [current] ist. Entwürfe und Vorabversionen zählen nicht.
AppUpdate? findUpdate(List<dynamic> releases, String platform, String current) {
  final pattern = assetPattern(platform);
  if (pattern == null) return null;
  AppUpdate? best;
  for (final release in releases.whereType<Map>()) {
    if (release['draft'] == true || release['prerelease'] == true) continue;
    for (final asset in (release['assets'] as List? ?? const []).whereType<Map>()) {
      final match = pattern.firstMatch('${asset['name']}');
      final url = Uri.tryParse('${asset['browser_download_url']}');
      if (match == null || url == null) continue;
      final version = match.group(1)!;
      if (best != null && compareVersions(version, best.version) <= 0) continue;
      final digest = asset['digest'];
      best = AppUpdate(
        version: version,
        name: '${asset['name']}',
        url: url,
        size: (asset['size'] as num?)?.toInt() ?? 0,
        sha256: digest is String && digest.startsWith('sha256:') ? digest.substring(7).toLowerCase() : null,
      );
    }
  }
  return best != null && compareVersions(best.version, current) > 0 ? best : null;
}

class Updater {
  Updater({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _checkedKey = 'update_checked_at';
  static const _channel = MethodChannel('thask/taskbar');

  static bool get supported => Platform.isAndroid || Platform.isWindows;

  String get platform => Platform.isAndroid ? 'android' : 'windows';

  Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;

  /// Fragt GitHub; null, wenn die installierte Version die neueste ist.
  Future<AppUpdate?> check() async {
    final response = await _client.get(
      Uri.https('api.github.com', '/repos/$releasesRepo/releases', {'per_page': '20'}),
      headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'tHAsk-app'},
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw HttpException('GitHub: HTTP ${response.statusCode}');
    final releases = jsonDecode(response.body);
    if (releases is! List) throw const FormatException('GitHub: unexpected answer');
    return findUpdate(releases, platform, await currentVersion());
  }

  /// Höchstens einmal am Tag, für die Prüfung beim Start; Fehler bleiben still.
  Future<AppUpdate?> checkDaily() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_checkedKey) ?? 0);
      if (DateTime.now().difference(last) < const Duration(hours: 20)) return null;
      final update = await check();
      await prefs.setInt(_checkedKey, DateTime.now().millisecondsSinceEpoch);
      return update;
    } catch (_) {
      return null;
    }
  }

  /// Lädt das Paket in den Zwischenspeicher; [onProgress] bekommt 0…1 (null, wenn die Größe fehlt).
  Future<File> download(AppUpdate update, void Function(double? progress) onProgress) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}thask-update');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}${update.name}');
    final response = await _client.send(http.Request('GET', update.url)..headers['User-Agent'] = 'tHAsk-app');
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
    final total = response.contentLength ?? update.size;
    final sink = file.openWrite();
    final hash = AccumulatorSink<Digest>();
    final hasher = sha256.startChunkedConversion(hash);
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : null);
      }
    } finally {
      await sink.close();
      hasher.close();
    }
    if (update.size > 0 && received != update.size) {
      throw HttpException('Download incomplete ($received of ${update.size} bytes)');
    }
    if (update.sha256 != null && hash.events.single.toString() != update.sha256) {
      throw const HttpException('Checksum does not match');
    }
    return file;
  }

  /// Android: öffnet die Paketinstallation. Windows: startet das Setup ohne Rückfragen und beendet die
  /// App; das Setup startet sie danach neu.
  Future<void> install(File file) async {
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) throw Exception(result.message);
      return;
    }
    await Process.start(file.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], mode: ProcessStartMode.detached);
    try {
      await _channel.invokeMethod('quit');
    } on MissingPluginException {
      exit(0);
    }
  }
}

/// Sammelt das Ergebnis der Prüfsumme (wie `AccumulatorSink` aus package:convert, ohne die Abhängigkeit).
class AccumulatorSink<T> implements Sink<T> {
  final events = <T>[];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
