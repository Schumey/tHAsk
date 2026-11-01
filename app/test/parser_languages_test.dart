import 'package:flutter_test/flutter_test.dart';
import 'package:thask/models.dart';
import 'package:thask/parser.dart';

// Wie test_other_languages* in tests/test_parser.py. Dienstag der ISO-Woche 45.
final today = DateTime(2026, 11, 3);

Period week(int year, int number) => Period.isoWeek(year, number)!;
Period day(int month, int d) => Period.day(DateTime(2026, month, d));

void main() {
  final cases = <(String, String, Period, String?)>[
    // Niederländisch
    ('Banden wisselen volgende maand', 'Banden wisselen', Period.month(2026, 12), null),
    ('Melk vandaag', 'Melk', day(11, 3), null),
    ('Melk overmorgen', 'Melk', day(11, 5), null),
    ('Tandarts vrijdag', 'Tandarts', day(11, 6), null),
    ('Tandarts morgen om 9 uur', 'Tandarts', day(11, 4), '09:00'),
    ('Tandarts om 9:30', 'Tandarts', day(11, 3), '09:30'),
    ('Rapport eind van de maand', 'Rapport', Period.month(2026, 11), null),
    ('Over 3 dagen bellen', 'bellen', day(11, 6), null),
    ('Tuin in maart', 'Tuin', Period.month(2027, 3), null),
    ('Belasting deze week', 'Belasting', week(2026, 45), null),
    // Französisch
    ('Changer les pneus le mois prochain', 'Changer les pneus', Period.month(2026, 12), null),
    ('Impôts semaine 47', 'Impôts', week(2026, 47), null),
    ("Lait aujourd'hui", 'Lait', day(11, 3), null),
    ('Lait demain à 9h', 'Lait', day(11, 4), '09:00'),
    ('Réunion 14h30', 'Réunion', day(11, 3), '14:30'),
    ('Dentiste vendredi', 'Dentiste', day(11, 6), null),
    ('Rapport fin du mois', 'Rapport', Period.month(2026, 11), null),
    ('Appeler dans 3 jours', 'Appeler', day(11, 6), null),
    ('Jardin en mars', 'Jardin', Period.month(2027, 3), null),
    ("Vacances l'année prochaine", 'Vacances', Period.year(2027), null),
    // Spanisch
    ('Cambiar neumáticos el próximo mes', 'Cambiar neumáticos', Period.month(2026, 12), null),
    ('Impuestos semana 47', 'Impuestos', week(2026, 47), null),
    ('Leche hoy', 'Leche', day(11, 3), null),
    ('Leche mañana a las 9', 'Leche', day(11, 4), '09:00'),
    ('Leche pasado mañana', 'Leche', day(11, 5), null),
    ('Dentista el viernes', 'Dentista', day(11, 6), null),
    ('Informe a finales de mes', 'Informe', Period.month(2026, 11), null),
    ('Llamar en 3 días', 'Llamar', day(11, 6), null),
    ('Jardín en mayo', 'Jardín', Period.month(2027, 5), null),
    ('Comprar la semana que viene', 'Comprar', week(2026, 46), null),
  ];

  group('Fälligkeit in anderen Sprachen', () {
    for (final (text, title, due, time) in cases) {
      test(text, () {
        final result = parse(text, today);
        expect(result.title, title);
        expect(result.due, due);
        expect(result.dueTime, time);
      });
    }
  });

  group('Wiederholung in anderen Sprachen', () {
    for (final (text, unit, weekdays) in <(String, Granularity, List<int>)>[
      ('Bloemen elke woensdag en zaterdag', Granularity.week, [2, 5]),
      ('Planten dagelijks', Granularity.day, []),
      ('Arroser chaque mercredi et samedi', Granularity.week, [2, 5]),
      ('Arroser tous les jours', Granularity.day, []),
      ('Facture tous les mois', Granularity.month, []),
      ('Regar cada miércoles y sábado', Granularity.week, [2, 5]),
      ('Regar todos los días', Granularity.day, []),
      ('Pagar mensualmente', Granularity.month, []),
    ]) {
      test(text, () {
        final recurrence = parse(text, today).recurrence!;
        expect(recurrence.unit, unit);
        expect(recurrence.weekdays, weekdays);
      });
    }
  });

  group('keine Fehltreffer in anderen Sprachen', () {
    for (final text in ['Mars Riegel kaufen', 'Mayo kaufen', 'Le Monde lesen', 'En route', '2 h joggen', 'Semaine des Kinos', 'Morgenroutine']) {
      test(text, () {
        final result = parse(text, today);
        expect(result.title, text);
        expect(result.due, isNull);
        expect(result.dueTime, isNull);
      });
    }
  });
}
