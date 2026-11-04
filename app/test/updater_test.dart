import 'package:flutter_test/flutter_test.dart';
import 'package:thask/updater.dart';

Map<String, Object?> _release(String tag, List<String> assets, {bool prerelease = false}) => {
      'tag_name': tag,
      'draft': false,
      'prerelease': prerelease,
      'assets': [
        for (final name in assets)
          {
            'name': name,
            'size': 1000,
            'browser_download_url': 'https://github.com/Schumey/tHAsk/releases/download/$tag/$name',
            'digest': 'sha256:ABC',
          },
      ],
    };

void main() {
  test('Versionen vergleichen', () {
    expect(compareVersions('0.9.15', '0.9.14'), 1);
    expect(compareVersions('0.10.0', '0.9.99'), 1);
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('0.9.14+22', '0.9.14'), 0);
    expect(compareVersions('0.9.1', '0.9.14'), -1);
  });

  test('Neuestes Paket der Plattform aus mehreren Releases', () {
    final releases = [
      _release('v0.18.0', []), // nur die Integration
      _release('v0.19.0', ['thask-0.9.20.apk', 'thask-setup-0.9.20.exe'], prerelease: true),
      _release('v0.17.0', ['thask-0.9.16.apk', 'thask-setup-0.9.16.exe']),
      _release('v0.16.0', ['thask-0.9.15.apk', 'thask-setup-0.9.15.exe']),
    ];
    final android = findUpdate(releases, 'android', '0.9.14')!;
    expect(android.version, '0.9.16');
    expect(android.name, 'thask-0.9.16.apk');
    expect(android.url.path, endsWith('/v0.17.0/thask-0.9.16.apk'));
    expect(android.sha256, 'abc');
    expect(findUpdate(releases, 'windows', '0.9.14')!.name, 'thask-setup-0.9.16.exe');
    expect(findUpdate(releases, 'android', '0.9.16'), isNull);
    expect(findUpdate(releases, 'linux', '0.9.14'), isNull);
  });
}
