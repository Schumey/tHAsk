import 'package:flutter_test/flutter_test.dart';
import 'package:thask/l10n.dart';
import 'package:thask/models.dart';
import 'package:thask/parser.dart';

// Wie tests/test_custom_periods.py der Integration.
final today = DateTime(2026, 11, 3);

Period block(DateTime start, DateTime end) => Period.custom(start, end, 'X-Block', 'x');

final blocks = [
  block(DateTime(2026, 11, 1), DateTime(2026, 11, 6)),
  block(DateTime(2026, 11, 20), DateTime(2026, 11, 28)),
  block(DateTime(2026, 12, 18), DateTime(2026, 12, 26)),
];

final periods = [CustomPeriod(id: 'x', name: 'X-Block', instances: blocks)];

void main() {
  setUp(() => L10n.lang = 'de');

  test('custom period round trip, end, label and shift', () {
    final period = blocks[1];
    expect(Period.fromJson(period.toJson()), period);
    expect(period.end, DateTime(2026, 11, 28));
    expect(period.label(today), 'X-Block 20. Nov.');
    expect(period.shift(1), block(DateTime(2026, 11, 29), DateTime(2026, 12, 7)));
    expect(period.shiftBy(1, Granularity.week).start, DateTime(2026, 11, 27));
  });

  test('found periods: next and previous', () {
    expect(customAdjacent(periods, blocks[1], 1, today), blocks[2]);
    expect(customAdjacent(periods, blocks[1], -1, today), blocks[0]);
    expect(customAdjacent(periods, blocks[2], 1, today), isNull);
    // The first block has ended by December.
    expect(customUpcoming(periods, 'x', DateTime(2026, 12, 1)), [blocks[2]]);
  });

  final cases = <(String, String, Period)>[
    ('Rasen mähen im X-Block', 'Rasen mähen', blocks[0]),
    ('Rasen mähen nächster X-Block', 'Rasen mähen', blocks[1]),
    ('Rasen mähen im nächsten x-block', 'Rasen mähen', blocks[1]),
    ('Keller übernächster X-Block', 'Keller', blocks[2]),
    ('Mow lawn next X-Block', 'Mow lawn', blocks[1]),
  ];
  for (final (text, title, due) in cases) {
    test('parse "$text"', () {
      final result = parse(text, today, custom: periods);
      expect(result.title, title);
      expect(result.due, due);
    });
  }

  test('every X block: recurrence and previews of found blocks only', () {
    final result = parse('Großeinkauf jeden X-Block', today, custom: periods);
    expect(result.title, 'Großeinkauf');
    expect(result.recurrence!.unit, Granularity.custom);
    expect(result.due, blocks[0]);
    expect(parse('Rasen im X-Block', today).due, isNull);

    expect(Recurrence(Granularity.custom, 1).nextPeriod(blocks[0], today, periods), blocks[1]);
    final task = Task.fromJson({
      'id': 't',
      'list_id': 'l',
      'title': 'Großeinkauf',
      'due': blocks[0].toJson(),
      'recurrence': {'unit': 'custom', 'interval': 1},
    });
    expect(task.projectedPeriods(DateTime(2027, 6, 1), today, periods: periods), [blocks[1], blocks[2]]);
    expect(dayTasks([task], DateTime(2026, 11, 22), today, periods).single.preview, isTrue);
  });
}
