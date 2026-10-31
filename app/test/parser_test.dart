import 'package:flutter_test/flutter_test.dart';
import 'package:thask/models.dart';
import 'package:thask/parser.dart';

// Dienstag der ISO-Woche 45. Die Fälle entsprechen tests/test_parser.py der Integration.
final today = DateTime(2026, 11, 3);

Period week(int year, int number) => Period.isoWeek(year, number)!;

void main() {
  final dueCases = <(String, String, Period)>[
    ('Reifen wechseln nächsten Monat', 'Reifen wechseln', Period.month(2026, 12)),
    ('Reifen wechseln naechsten Monat', 'Reifen wechseln', Period.month(2026, 12)),
    ('Steuer KW 47', 'Steuer', week(2026, 47)),
    ('Steuer kw47', 'Steuer', week(2026, 47)),
    ('Steuer bis KW 2', 'Steuer', week(2027, 2)),
    ('Zahnarzt anrufen diese Woche', 'Zahnarzt anrufen', week(2026, 45)),
    ('Urlaub planen übernächste Woche', 'Urlaub planen', week(2026, 47)),
    ('Geschenk kaufen bis Ende des Monats', 'Geschenk kaufen', Period.month(2026, 11)),
    ('Geschenk kaufen bis Monatsende', 'Geschenk kaufen', Period.month(2026, 11)),
    ('Bericht bis Ende nächster Woche', 'Bericht', week(2026, 46)),
    ('Steuererklärung Q1', 'Steuererklärung', Period.quarter(2027, 1)),
    ('Steuererklärung Q4 2026', 'Steuererklärung', Period.quarter(2026, 4)),
    ('Garten im März', 'Garten', Period.month(2027, 3)),
    ('Garten Dezember', 'Garten', Period.month(2026, 12)),
    ('Garten bis Nov.', 'Garten', Period.month(2026, 11)),
    ('Dach prüfen nächstes Jahr', 'Dach prüfen', Period.year(2027)),
    ('Dach prüfen bis 2028', 'Dach prüfen', Period.year(2028)),
    ('Milch heute', 'Milch', Period.day(DateTime(2026, 11, 3))),
    ('Milch morgen', 'Milch', Period.day(DateTime(2026, 11, 4))),
    ('Milch übermorgen', 'Milch', Period.day(DateTime(2026, 11, 5))),
    ('Arzt am Freitag', 'Arzt', Period.day(DateTime(2026, 11, 6))),
    ('Arzt Dienstag', 'Arzt', Period.day(DateTime(2026, 11, 10))),
    ('Rechnung 14.11.', 'Rechnung', Period.day(DateTime(2026, 11, 14))),
    ('Rechnung bis 2.1.', 'Rechnung', Period.day(DateTime(2027, 1, 2))),
    ('Rechnung 14.11.27', 'Rechnung', Period.day(DateTime(2027, 11, 14))),
    ('Rechnung 2026-12-24', 'Rechnung', Period.day(DateTime(2026, 12, 24))),
    ('Reifen in 2 Wochen', 'Reifen', week(2026, 47)),
    ('Reifen in 3 Tagen', 'Reifen', Period.day(DateTime(2026, 11, 6))),
    ('Reifen in einem Monat', 'Reifen', Period.month(2026, 12)),
    ('Call mom next week', 'Call mom', week(2026, 46)),
    ('Call mom tomorrow', 'Call mom', Period.day(DateTime(2026, 11, 4))),
  ];

  group('Fälligkeit', () {
    for (final (text, title, due) in dueCases) {
      test(text, () {
        final result = parse(text, today);
        expect(result.title, title);
        expect(result.due, due);
      });
    }
  });

  group('keine Fehltreffer', () {
    for (final text in [
      'Steuererklärung 2025 abgeben',
      'Mailand Reise',
      'Wochenplan schreiben',
      'Brief an Max',
      'Die Woche war lang',
    ]) {
      test(text, () {
        final result = parse(text, today);
        expect(result.due, isNull);
        expect(result.title, text);
      });
    }
  });

  test('Uhrzeit', () {
    var result = parse('Zahnarzt morgen um 9:30', today);
    expect((result.title, result.due, result.dueTime), ('Zahnarzt', Period.day(DateTime(2026, 11, 4)), '09:30'));
    result = parse('Anrufen 14 Uhr', today);
    expect((result.title, result.due, result.dueTime), ('Anrufen', Period.day(today), '14:00'));
  });

  test('Uhrzeit wird bei Zeiträumen ignoriert', () {
    final result = parse('Meeting KW 47 um 9:30', today);
    expect(result.due, week(2026, 47));
    expect(result.dueTime, isNull);
    expect(result.title, 'Meeting um 9:30');
  });

  test('Wiederholung', () {
    var result = parse('Rechnungen ablegen jeden Monat', today);
    expect(result.title, 'Rechnungen ablegen');
    expect(result.recurrence!.unit, Granularity.month);
    // Ohne ausdrückliche Fälligkeit gilt der laufende Zeitraum der Wiederholung.
    expect(result.due, Period.month(2026, 11));

    result = parse('Müll rausbringen jeden Montag', today);
    expect(result.recurrence!.unit, Granularity.week);
    expect(result.due, Period.day(DateTime(2026, 11, 9)));

    result = parse('Pflanzen gießen alle 2 Wochen', today);
    expect((result.recurrence!.unit, result.recurrence!.interval), (Granularity.week, 2));

    result = parse('Steuer jährlich bis Q2', today);
    expect(result.recurrence!.unit, Granularity.year);
    expect(result.due, Period.quarter(2027, 2));
  });

  test('Wiederholung an mehreren Wochentagen', () {
    var result = parse('Blumen gießen jeden Mittwoch und Samstag', today);
    expect(result.title, 'Blumen gießen');
    expect(result.recurrence!.unit, Granularity.week);
    expect(result.recurrence!.weekdays, [2, 5]);
    expect(result.due, Period.day(DateTime(2026, 11, 4)));

    result = parse('Sport jeden Mo, Mi und Fr um 18 Uhr', today);
    expect(result.recurrence!.weekdays, [0, 2, 4]);
    expect((result.title, result.dueTime), ('Sport', '18:00'));

    result = parse('Training alle 2 Wochen am Montag und Donnerstag', today);
    expect(result.recurrence!.interval, 2);
    expect(result.recurrence!.weekdays, [0, 3]);
    expect(result.title, 'Training');

    expect(parse('Yoga montags und donnerstags', today).recurrence!.weekdays, [0, 3]);
    expect(parse('Laufen jeden Mi. + Sa.', today).recurrence!.weekdays, [2, 5]);
    expect(parse('Gym every Tue and Thu', today).due, Period.day(today));
    expect(parse('Zeitung werktags', today).recurrence!.weekdays, [0, 1, 2, 3, 4]);
    expect(parse('Putzen jedes Wochenende', today).due, Period.day(DateTime(2026, 11, 7)));

    // Ein einzelner Wochentag braucht keine Liste, das sagt der Fälligkeitstag.
    expect(parse('Müll montags', today).recurrence!.weekdays, isEmpty);
    // Kurzformen allein oder in Wörtern sind keine Wochentage.
    expect(parse('Montags-Meeting vorbereiten', today).recurrence, isNull);
    expect(parse('Rechnungen jeden Monat', today).recurrence!.unit, Granularity.month);
  });

  test('Wochentage in JSON', () {
    final r = Recurrence.fromJson({'unit': 'week', 'interval': 1, 'weekdays': [5, 2]});
    expect(r.weekdays, [2, 5]);
    expect(r.toJson(), {'unit': 'week', 'interval': 1, 'weekdays': [2, 5]});
    expect(Recurrence.fromJson({'unit': 'month', 'weekdays': [1]}).toJson(), {'unit': 'month', 'interval': 1});
  });

  test('Priorität', () {
    final result = parse('Zahnarzt anrufen diese Woche !', today);
    expect(result.priority, 1);
    expect(result.title, 'Zahnarzt anrufen');
    expect(parse('Zahnarzt anrufen !!', today).priority, 2);
    expect(parse('Zahnarzt anrufen !!!', today).priority, 3);
    expect(parse('Zahnarzt anrufen !!!!!', today).priority, 3);
    expect(parse('Hallo!', today).priority, 0);
  });

  test('Token und abgeschaltete Arten', () {
    var result = parse('Rechnung vom 14.11. bezahlen', today);
    expect([for (final t in result.tokens) (t.kind, t.text)], [('due', '14.11.')]);
    result = parse('Rechnung vom 14.11. bezahlen', today, disabled: {'due'});
    expect(result.due, isNull);
    expect(result.title, 'Rechnung vom 14.11. bezahlen');
  });

  test('ungültige Daten bleiben im Titel', () {
    expect(parse('Rechnung 31.2.', today).due, isNull);
    expect(parse('Steuer KW 53 2027', today).due, isNull);
    expect(week(2026, 53).start, DateTime(2026, 12, 28));
  });
}
