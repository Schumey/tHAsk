import 'package:flutter_test/flutter_test.dart';
import 'package:thask/l10n.dart';
import 'package:thask/models.dart';

void main() {
  tearDown(() => L10n.lang = 'de');

  test('Sprachcode des Geräts', () {
    expect(L10n.resolve('de-CH'), 'de');
    expect(L10n.resolve('fr_BE'), 'fr');
    expect(L10n.resolve('it'), 'en');
    expect(L10n.resolve(null), 'en');
  });

  test('Zeiträume in jeder Sprache', () {
    final today = DateTime(2026, 11, 2);
    final day = Period(Granularity.day, DateTime(2026, 11, 5));
    final week = Period.containing(Granularity.week, DateTime(2026, 11, 16));
    final month = Period(Granularity.month, DateTime(2027, 1, 1));
    final expected = {
      'de': ('Do, 5. Nov.', 'KW 47', 'Januar 2027', 'Heute'),
      'en': ('Thu, Nov 5', 'Week 47', 'January 2027', 'Today'),
      'nl': ('do 5 nov.', 'Week 47', 'januari 2027', 'Vandaag'),
      'fr': ('jeu. 5 nov.', 'Semaine 47', 'janvier 2027', "Aujourd'hui"),
      'es': ('jue, 5 nov', 'Semana 47', 'enero 2027', 'Hoy'),
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      L10n.lang = key;
      expect(day.label(today), value.$1, reason: key);
      expect(week.label(today), value.$2, reason: key);
      expect(month.label(today), value.$3, reason: key);
      expect(Period(Granularity.day, today).label(today), value.$4, reason: key);
    }
  });

  test('Platzhalter, Mehrzahl und Rückfall auf Englisch', () {
    L10n.lang = 'en';
    expect(tr('completed_n', [3]), 'Completed (3)');
    expect(trPlural(1, 'change'), '1 change');
    expect(trPlural(2, 'change'), '2 changes');
    expect(tr('does_not_exist'), 'does_not_exist');
  });
}
