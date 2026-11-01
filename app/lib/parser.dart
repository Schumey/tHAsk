/// Schnelleingabe: Fälligkeit, Uhrzeit, Wiederholung und Wichtig aus einem Aufgabentitel lösen.
///
/// „Reifen wechseln nächsten Monat !“ ergibt den Titel „Reifen wechseln“, fällig im nächsten Monat,
/// Priorität niedrig (`!` niedrig, `!!` mittel, `!!!` hoch).
/// Spiegelt `custom_components/thask/core/parser.py` (gleiche Regeln, gleiche Tests), damit die App
/// auch ohne Verbindung zu Home Assistant dasselbe erkennt.
library;

import 'models.dart';

const kindDue = 'due';
const kindTime = 'time';
const kindRecurrence = 'recurrence';
const kindPriority = 'priority';

class Token {
  const Token(this.kind, this.start, this.end, this.text);

  final String kind;
  final int start;
  final int end;
  final String text;
}

class ParseResult {
  const ParseResult({
    required this.title,
    this.due,
    this.dueTime,
    this.recurrence,
    this.priority = 0,
    this.tokens = const [],
  });

  final String title;
  final Period? due;
  final String? dueTime;
  final Recurrence? recurrence;
  /// 0 keine, 1 niedrig (`!`), 2 mittel (`!!`), 3 hoch (`!!!` und mehr).
  final int priority;
  final List<Token> tokens;
}

// Wortgrenzen mit Unicode-Buchstaben, weil `\w` in Dart nur ASCII kennt.
const _wordChar = r'[\p{L}\p{N}_]';

const _tokens = {
  '@B@': '(?<!$_wordChar)',
  '@E@': '(?!$_wordChar)',
  '@AE@': '(?:ä|ae)',
  '@OE@': '(?:ö|oe)',
  '@UE@': '(?:ü|ue)',
  '@PREP@': r'(?:(?:bis\s+(?:zum\s+|zur\s+)?|am\s+|im\s+|in\s+der\s+|in\s+|f@UE@r\s+|'
      r'f@AE@llig\s+(?:am\s+|im\s+|in\s+(?:der\s+)?|bis\s+)?|by\s+|on\s+)?)',
  // Wo das Wort allein zu mehrdeutig wäre („bis Nov.“, „bis 2027“), ist eine Präposition Pflicht.
  '@PREPREQ@': r'(?:(?:bis|im|in|ab|f@UE@r|by)\s+)',
  '@THIS@': r'(?:diese[nrsm]?|this)',
  '@NEXT@': r'(?:n@AE@chste[nrsm]?|kommende[nrsm]?|next)',
  '@AFTERNEXT@': r'(?:@UE@bern@AE@chste[nrsm]?)',
  '@WEEKDAY@': 'montag|monday|dienstag|tuesday|mittwoch|wednesday|donnerstag|thursday|freitag|friday|samstag|saturday|sonntag|sunday',
  // Kurzformen nur in Wiederholungen („jeden Mi und Sa“), allein sind sie zu mehrdeutig.
  '@RECDAY@': r'(?:@WEEKDAY@|(?:mo|mon|di|tue|tues|mi|wed|do|thu|thur|thurs|fr|fri|sa|sat|so|sun)\.?)',
  '@RECADVERB@': 'montags|dienstags|mittwochs|donnerstags|freitags|samstags|sonntags',
  '@DAYSEP@': r'(?:\s*[,/&+]\s*|\s+(?:und|and|u\.)\s+)',
  '@EVERY@': r'(?:jede[nrs]?|every)',
  '@MONTHFULL@': r'januar|februar|m@AE@rz|april|mai|juni|juli|august|september|oktober|november|dezember',
  '@MONTHSHORT@': r'jan|feb|m@AE@r|mrz|apr|mai|jun|jul|aug|sept|sep|okt|nov|dez',
};

String _expand(String template) {
  var result = template;
  // Platzhalter enthalten selbst Platzhalter.
  for (var pass = 0; pass < 3; pass++) {
    _tokens.forEach((key, value) => result = result.replaceAll(key, value));
  }
  return result;
}

RegExp _re(String template) => RegExp(_expand(template), caseSensitive: false, unicode: true);

const _weekdays = [
  ('montag', 'monday'),
  ('dienstag', 'tuesday'),
  ('mittwoch', 'wednesday'),
  ('donnerstag', 'thursday'),
  ('freitag', 'friday'),
  ('samstag', 'saturday'),
  ('sonntag', 'sunday'),
];

const _months = [
  ('januar', 'jan'),
  ('februar', 'feb'),
  ('m@AE@rz', 'm@AE@r|mrz'),
  ('april', 'apr'),
  ('mai', 'mai'),
  ('juni', 'jun'),
  ('juli', 'jul'),
  ('august', 'aug'),
  ('september', 'sept|sep'),
  ('oktober', 'okt'),
  ('november', 'nov'),
  ('dezember', 'dez'),
];

final _monthPatterns = [for (final (full, short) in _months) RegExp('^(?:${_expand(full)}|${_expand(short)})\$')];

const _numberWords = {
  'ein': 1, 'eine': 1, 'einen': 1, 'einer': 1, 'einem': 1, 'zwei': 2, 'drei': 3, 'vier': 4,
  'a': 1, 'one': 1, 'two': 2, 'other': 2, 'three': 3, 'four': 4,
};

const _weekdaysShort = [
  ['mo', 'mon'],
  ['di', 'tue', 'tues'],
  ['mi', 'wed'],
  ['do', 'thu', 'thur', 'thurs'],
  ['fr', 'fri'],
  ['sa', 'sat'],
  ['so', 'sun'],
];

Granularity _unit(String word) {
  final w = word.toLowerCase();
  if (w.startsWith('viertel') || w.startsWith('quartal') || w.startsWith('quarter') || w.startsWith('q')) {
    return Granularity.quarter;
  }
  if (w.startsWith('t') || w.startsWith('d')) return Granularity.day;
  if (w.startsWith('w')) return Granularity.week;
  if (w.startsWith('m')) return Granularity.month;
  return Granularity.year;
}

int _number(String word) => int.tryParse(word) ?? _numberWords[word.toLowerCase()]!;

/// Index des Wochentags, Montag = 1. Versteht auch Kurzformen („Mi.“) und „montags“.
int _weekdayIndex(String word) {
  final w = word.toLowerCase().replaceAll(RegExp(r'\.+$'), '');
  bool matches(List<String> names) =>
      names.contains(w) || (w.endsWith('s') && names.contains(w.substring(0, w.length - 1)));
  final full = _weekdays.indexWhere((names) => matches([names.$1, names.$2]));
  return (full >= 0 ? full : _weekdaysShort.indexWhere(matches)) + 1;
}

int _monthIndex(String word) {
  final w = word.toLowerCase().replaceAll(RegExp(r'\.+$'), '');
  return _monthPatterns.indexWhere((pattern) => pattern.hasMatch(w)) + 1;
}

DateTime _nextWeekday(DateTime today, int weekday, {required bool includeToday}) {
  var days = (weekday - today.weekday) % 7;
  if (days == 0 && !includeToday) days = 7;
  return DateTime(today.year, today.month, today.day + days);
}

/// Ein Datum ohne Jahr meint das nächste solche Datum, nie eines in der Vergangenheit.
int _yearFor(int month, int day, DateTime today) {
  final past = month < today.month || (month == today.month && day < today.day);
  return today.year + (past ? 1 : 0);
}

DateTime? _validDate(int year, int month, int day) {
  final d = DateTime(year, month, day);
  return d.year == year && d.month == month && d.day == day ? d : null;
}

DateTime _plusDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Felder, die eine Regel setzt; null, wenn sie nicht zutrifft.
typedef _Fields = Map<String, Object?>;
typedef _Handler = _Fields? Function(RegExpMatch match, DateTime today);

/// Wöchentlich an den Tagen (Montag = 1); ein einzelner Tag braucht keine Liste, das sagt der Fälligkeitstag.
_Fields _weeklyOn(List<int> days, int interval, DateTime today) {
  final unique = days.toSet().toList()..sort();
  final first = [for (final d in unique) _nextWeekday(today, d, includeToday: true)]
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return {
    'recurrence': Recurrence(
      Granularity.week,
      interval < 1 ? 1 : interval,
      unique.length > 1 ? [for (final d in unique) d - 1] : const [],
    ),
    'due': Period.day(first),
  };
}

final _recDayPattern = _re(r'@B@(?:@RECADVERB@|@RECDAY@)@E@');

_Fields _recurringWeekdays(RegExpMatch m, DateTime today) {
  final days = [for (final d in _recDayPattern.allMatches(m.namedGroup('days')!)) _weekdayIndex(d[0]!)];
  final n = m.namedGroup('n');
  return _weeklyOn(days, n == null || n.isEmpty ? 1 : _number(n), today);
}

_Fields _recurringWorkdays(RegExpMatch m, DateTime today) {
  final weekend = RegExp('wochenend|weekend', caseSensitive: false).hasMatch(m[0]!);
  return _weeklyOn(weekend ? [6, 7] : [1, 2, 3, 4, 5], 1, today);
}

_Fields _recurringEveryN(RegExpMatch m, DateTime today) {
  final unit = _unit(m[2]!);
  final interval = int.parse(m[1]!);
  return {
    'recurrence': Recurrence(unit, interval < 1 ? 1 : interval),
    'default_due': Period.containing(unit, today),
  };
}

_Fields _recurringUnit(RegExpMatch m, DateTime today) {
  final word = [for (var i = 1; i <= m.groupCount; i++) m[i]].firstWhere((g) => g != null)!;
  final unit = _unit(word);
  return {'recurrence': Recurrence(unit, 1), 'default_due': Period.containing(unit, today)};
}

_Fields? _time(RegExpMatch m, DateTime today) {
  final hour = int.parse(m.namedGroup('hour')!);
  final minute = int.parse(m.namedGroup('minute') ?? m.namedGroup('minute2') ?? '0');
  if (hour > 23 || minute > 59) return null;
  return {'due_time': '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'};
}

_Fields _inN(RegExpMatch m, DateTime today) {
  final count = _number(m[1]!);
  final unit = _unit(m[2]!);
  return switch (unit) {
    Granularity.day => {'due': Period.day(_plusDays(today, count))},
    Granularity.week => {'due': Period.containing(Granularity.week, _plusDays(today, 7 * count))},
    Granularity.month => {'due': Period.containing(Granularity.month, addMonths(today, count))},
    _ => {'due': Period.containing(Granularity.year, addMonths(today, 12 * count))},
  };
}

_Fields _relativeDay(RegExpMatch m, DateTime today) {
  final word = m[1]!.toLowerCase();
  final offset = (word == 'heute' || word == 'today') ? 0 : (word == 'morgen' || word == 'tomorrow') ? 1 : 2;
  return {'due': Period.day(_plusDays(today, offset))};
}

final _afterNextWord = _re(r'^@AFTERNEXT@');
final _nextWord = _re(r'^@NEXT@');

_Fields _relativePeriod(RegExpMatch m, DateTime today) {
  final which = m[1]!.toLowerCase();
  final offset = _afterNextWord.hasMatch(which) ? 2 : (_nextWord.hasMatch(which) ? 1 : 0);
  return {'due': Period.containing(_unit(m[2]!), today).shift(offset)};
}

_Fields _endOf(RegExpMatch m, DateTime today) {
  final unit = _unit(m.namedGroup('unit') ?? m.namedGroup('unit2') ?? m.namedGroup('unit3')!);
  return {'due': Period.containing(unit, today).shift(m.namedGroup('next') != null ? 1 : 0)};
}

_Fields? _calendarWeek(RegExpMatch m, DateTime today) {
  final week = int.parse(m[1]!);
  int year;
  if (m[2] != null) {
    year = int.parse(m[2]!);
  } else {
    year = isoWeekYear(today);
    if (week < isoWeekNumber(today)) year += 1;
  }
  final period = Period.isoWeek(year, week);
  return period == null ? null : {'due': period};
}

_Fields _quarter(RegExpMatch m, DateTime today) {
  final quarter = int.parse(m[1]!);
  final year = m[2] != null ? int.parse(m[2]!) : today.year + (quarter < (today.month - 1) ~/ 3 + 1 ? 1 : 0);
  return {'due': Period.quarter(year, quarter)};
}

_Fields? _numericDate(RegExpMatch m, DateTime today) {
  final day = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  final year = m[3] != null ? int.parse(m[3]!) + (m[3]!.length == 2 ? 2000 : 0) : _yearFor(month, day, today);
  final date = _validDate(year, month, day);
  return date == null ? null : {'due': Period.day(date)};
}

_Fields? _isoDate(RegExpMatch m, DateTime today) {
  final parts = m[1]!.split('-').map(int.parse).toList();
  final date = _validDate(parts[0], parts[1], parts[2]);
  return date == null ? null : {'due': Period.day(date)};
}

_Fields _weekday(RegExpMatch m, DateTime today) =>
    {'due': Period.day(_nextWeekday(today, _weekdayIndex(m[1]!), includeToday: false))};

_Fields _month(RegExpMatch m, DateTime today) {
  final month = _monthIndex(m[1]!);
  final year = m[2] != null ? int.parse(m[2]!) : today.year + (month < today.month ? 1 : 0);
  return {'due': Period.month(year, month)};
}

_Fields _year(RegExpMatch m, DateTime today) => {'due': Period.year(int.parse(m[1]!))};

_Fields _priority(RegExpMatch m, DateTime today) => {'priority': m[0]!.trim().length.clamp(1, 3)};

class _Rule {
  _Rule(this.kind, String pattern, this.handler) : pattern = _re(pattern);

  final String kind;
  final RegExp pattern;
  final _Handler handler;
}

final _rules = _withOtherLanguages([
  _Rule(
    kindRecurrence,
    r'@B@(?:alle|every)\s+(?<n>\d+|zwei|drei|vier|two|three|four|other)\s+(?:wochen|weeks?)\s+(?:(?:am|an|on)\s+)?'
    r'(?<days>@RECDAY@(?:@DAYSEP@@RECDAY@)*)@E@',
    _recurringWeekdays,
  ),
  _Rule(
    kindRecurrence,
    r'@B@@EVERY@\s+(?<n>)(?<days>@RECDAY@(?:@DAYSEP@(?:@EVERY@\s+)?@RECDAY@)*)@E@',
    _recurringWeekdays,
  ),
  _Rule(
    kindRecurrence,
    r'@B@(?:werktags|wochentags|(?:an\s+)?werktagen|jeden\s+werktag|every\s+weekday|weekdays'
    r'|jedes\s+wochenende|wochenends|every\s+weekend)(?![\p{L}\p{N}_-])',
    _recurringWorkdays,
  ),
  _Rule(
    kindRecurrence,
    r'@B@(?:immer\s+)?(?<n>)(?<days>(?:@RECADVERB@)(?:@DAYSEP@(?:@RECADVERB@))*)(?![\p{L}\p{N}_-])',
    _recurringWeekdays,
  ),
  _Rule(
    kindRecurrence,
    r'@B@(?:alle|every)\s+(\d+)\s+(tage|wochen|monate|quartale|jahre|days|weeks|months|quarters|years)@E@',
    _recurringEveryN,
  ),
  _Rule(
    kindRecurrence,
    r'@B@(?:(?:jede[nrs]?|every)\s+(tag|woche|monat|quartal|jahr|day|week|month|quarter|year)'
    r'|(t@AE@glich|w@OE@chentlich|monatlich|viertelj@AE@hrlich|quartalsweise|j@AE@hrlich'
    r'|daily|weekly|monthly|quarterly|yearly))@E@',
    _recurringUnit,
  ),
  _Rule(
    kindTime,
    r'@B@(?:um\s+|at\s+)?(?<hour>\d{1,2})(?::(?<minute>\d{2})(?:\s*uhr)?|(?:\.(?<minute2>\d{2}))?\s*uhr)@E@',
    _time,
  ),
  _Rule(
    kindDue,
    r'@B@in\s+(\d+|eine[mnr]?|ein|zwei|drei|vier|a|one|two|three)\s+'
    r'(tag(?:en)?|wochen?|monat(?:en)?|jahr(?:en)?|days?|weeks?|months?|years?)@E@',
    _inN,
  ),
  _Rule(kindDue, r'@B@@PREP@(heute|today|morgen|tomorrow|@UE@bermorgen)@E@', _relativeDay),
  _Rule(
    kindDue,
    r'@B@@PREP@(?:ende\s+(?:(?:des|der)\s+)?(?<next>@NEXT@\s+)?(?:diese[sr]\s+)?(?<unit>woche|monats|quartals|jahres)'
    r'|(?<unit2>monats|quartals|jahres)ende|end\s+of\s+(?:the\s+)?(?<unit3>week|month|quarter|year))@E@',
    _endOf,
  ),
  _Rule(
    kindDue,
    r'@B@@PREP@(?:(?:der|den|dem|das)\s+)?(@AFTERNEXT@|@THIS@|@NEXT@)\s+'
    r'(woche|monats?|quartals?|jahr(?:es)?|week|month|quarter|year)@E@',
    _relativePeriod,
  ),
  _Rule(
    kindDue,
    r'@B@@PREP@(?:der\s+)?(?:kw|kalenderwoche|woche|week|wk)\s*(\d{1,2})(?:\s*[/.]?\s*(\d{4}))?@E@',
    _calendarWeek,
  ),
  _Rule(kindDue, r'@B@@PREP@(?:im\s+)?(?:q|quartal\s*)([1-4])(?:\s*[/.]?\s*(\d{4}))?@E@', _quarter),
  _Rule(kindDue, r'@B@@PREP@(\d{4}-\d{2}-\d{2})@E@', _isoDate),
  _Rule(kindDue, r'@B@@PREP@(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})?(?!\d)', _numericDate),
  _Rule(kindDue, r'@B@@PREP@(?:@NEXT@\s+)?(@WEEKDAY@)@E@', _weekday),
  _Rule(kindDue, r'@B@@PREP@(@MONTHFULL@)(?:\s+(\d{4}))?@E@', _month),
  _Rule(kindDue, r'@B@@PREPREQ@(@MONTHSHORT@)\.?(?:\s+(\d{4}))?@E@', _month),
  _Rule(kindDue, r'@B@(?:@PREPREQ@|im\s+jahr\s+|jahr\s+)(\d{4})@E@', _year),
  _Rule(kindPriority, r'(?<!\S)!+(?!\S)', _priority),
]);

// -- Niederländisch, Französisch, Spanisch --------------------------------------------------------------------
// Die häufigsten Wendungen, wie in parser.py. Wörter stehen ausdrücklich für Einheiten, denn die
// Anfangsbuchstaben-Regel von _unit() passt hier nicht („jour“ ist ein Tag, „jaar“ ein Jahr).

const _xUnits = {
  Granularity.day: ['dag', 'dagen', 'jour', 'jours', 'día', 'dia', 'días', 'dias'],
  Granularity.week: ['week', 'weken', 'semaine', 'semaines', 'semana', 'semanas'],
  Granularity.month: ['maand', 'maanden', 'mois', 'mes', 'meses'],
  Granularity.quarter: ['kwartaal', 'kwartalen', 'trimestre', 'trimestres'],
  Granularity.year: ['jaar', 'jaren', 'an', 'ans', 'année', 'annee', 'années', 'annees', 'año', 'ano', 'años', 'anos'],
};
final _xUnit = ([for (final words in _xUnits.values) ...words]..sort((a, b) => b.length.compareTo(a.length))).join('|');

const _xWeekdays = [
  ['maandag', 'lundi', 'lunes'],
  ['dinsdag', 'mardi', 'martes'],
  ['woensdag', 'mercredi', 'miércoles', 'miercoles'],
  ['donderdag', 'jeudi', 'jueves'],
  ['vrijdag', 'vendredi', 'viernes'],
  ['zaterdag', 'samedi', 'sábado', 'sabado'],
  ['zondag', 'dimanche', 'domingo'],
];
final _xWeekday = [for (final names in _xWeekdays) ...names].join('|');
// Mehrzahl für Wiederholungen („tous les lundis“, „maandags“).
final _xRecDay = '(?:$_xWeekday|${[for (final names in _xWeekdays) '${names[0]}s|${names[1]}s'].join('|')})';

const _xMonths = [
  ['januari', 'janvier', 'enero'],
  ['februari', 'février', 'fevrier', 'febrero'],
  ['maart', 'marzo'],
  ['april', 'avril', 'abril'],
  ['mei', 'mayo'],
  ['juni', 'juin', 'junio'],
  ['juli', 'juillet', 'julio'],
  ['augustus', 'août', 'aout', 'agosto'],
  ['september', 'septembre', 'septiembre', 'setiembre'],
  ['oktober', 'octobre', 'octubre'],
  ['november', 'novembre', 'noviembre'],
  ['december', 'décembre', 'decembre', 'diciembre'],
];
// „mars“ (auch der Planet) und „mayo“ zählen nur nach einer Präposition.
final _xMonth = [for (final names in _xMonths) ...names.where((n) => n != 'mayo')].join('|');
const _xPrep = r'(?:(?:op|voor|tegen|uiterlijk|in|le|pour|d' "'" r'ici|avant|en|au|el|para|antes\s+del?|hasta\s+el)\s+)?';
const _xMonthPrep = r'(?:in|en|au\s+mois\s+de|d' "'" r'ici|avant|pour|para|antes\s+de|hasta)\s+';
const _xNext = r'(?:volgende|komende|prochaine?|próxim[oa]|proxim[oa])';
const _xThis = r'(?:deze|dit|cette|cet|ce|esta|este)';
const _xEvery = r'(?:elke|iedere|chaque|tous\s+les|toutes\s+les|cada|todos\s+los|todas\s+las)';
const _xAnd = r'(?:\s*[,/&+]\s*|\s+(?:en|et|y|e)\s+)';
const _xNumberWords = {
  'een': 1, 'un': 1, 'une': 1, 'una': 1, 'uno': 1, 'twee': 2, 'deux': 2, 'dos': 2, 'drie': 3, 'trois': 3, 'tres': 3,
};
final _xNumber = '(?:\\d+|${_xNumberWords.keys.join('|')})';
final _xRecDayPattern = _re('@B@$_xRecDay@E@');

Granularity _xUnitOf(String word) {
  final w = word.toLowerCase();
  return _xUnits.entries.firstWhere((e) => e.value.contains(w)).key;
}

int _xNumberOf(String word) => int.tryParse(word) ?? _xNumberWords[word.toLowerCase()]!;

/// Montag = 1, wie _weekdayIndex.
int _xWeekdayIndex(String word) {
  final w = word.toLowerCase();
  return _xWeekdays.indexWhere(
        (names) => names.contains(w) || (w.endsWith('s') && names.contains(w.substring(0, w.length - 1))),
      ) +
      1;
}

int _xMonthIndex(String word) {
  final w = word.toLowerCase();
  if (w == 'mars') return 3;
  return _xMonths.indexWhere((names) => names.contains(w)) + 1;
}

_Fields _xRelativeDay(RegExpMatch m, DateTime today) {
  final word = m[1]!.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const offsets = {'vandaag': 0, "aujourd'hui": 0, 'hoy': 0, 'demain': 1, 'mañana': 1, 'manana': 1};
  return {'due': Period.day(_plusDays(today, offsets[word] ?? 2))};
}

_Fields _xPeriod(RegExpMatch m, DateTime today) {
  final next = m.namedGroup('next');
  return {
    'due': Period.containing(_xUnitOf(m.namedGroup('unit')!), today).shift(next != null && next.isNotEmpty ? 1 : 0),
  };
}

_Fields _xInN(RegExpMatch m, DateTime today) {
  final count = _xNumberOf(m[1]!);
  return switch (_xUnitOf(m[2]!)) {
    Granularity.day => {'due': Period.day(_plusDays(today, count))},
    Granularity.week => {'due': Period.containing(Granularity.week, _plusDays(today, 7 * count))},
    Granularity.month => {'due': Period.containing(Granularity.month, addMonths(today, count))},
    Granularity.quarter => {'due': Period.containing(Granularity.quarter, addMonths(today, 3 * count))},
    Granularity.year => {'due': Period.containing(Granularity.year, addMonths(today, 12 * count))},
  };
}

_Fields _xEndOf(RegExpMatch m, DateTime today) {
  final unit = m.namedGroup('unit') ?? m.namedGroup('unit2') ?? m.namedGroup('unit3')!;
  final next = m.namedGroup('next') ?? m.namedGroup('next2') ?? m.namedGroup('next3');
  return {'due': Period.containing(_xUnitOf(unit), today).shift(next != null ? 1 : 0)};
}

_Fields _xWeekdayDue(RegExpMatch m, DateTime today) =>
    {'due': Period.day(_nextWeekday(today, _xWeekdayIndex(m[1]!), includeToday: false))};

_Fields _xMonthDue(RegExpMatch m, DateTime today) {
  final month = _xMonthIndex(m[1]!);
  final year = m[2] != null ? int.parse(m[2]!) : today.year + (month < today.month ? 1 : 0);
  return {'due': Period.month(year, month)};
}

_Fields _xRecurringWeekdays(RegExpMatch m, DateTime today) =>
    _weeklyOn([for (final d in _xRecDayPattern.allMatches(m.namedGroup('days')!)) _xWeekdayIndex(d[0]!)], 1, today);

_Fields _xRecurringUnit(RegExpMatch m, DateTime today) {
  final adverb = m.namedGroup('adverb')?.toLowerCase();
  final Granularity unit;
  if (adverb != null) {
    bool starts(List<String> stems) => stems.any(adverb.startsWith);
    unit = starts(['dage', 'quotid', 'diari'])
        ? Granularity.day
        : starts(['weke', 'hebdo', 'seman'])
            ? Granularity.week
            : starts(['maand', 'mensu'])
                ? Granularity.month
                : Granularity.year;
  } else {
    unit = _xUnitOf(m.namedGroup('unit')!);
  }
  return {'recurrence': Recurrence(unit, 1), 'default_due': Period.containing(unit, today)};
}

_Fields _xRecurringEveryN(RegExpMatch m, DateTime today) {
  final unit = _xUnitOf(m[2]!);
  final interval = int.parse(m[1]!);
  return {'recurrence': Recurrence(unit, interval < 1 ? 1 : interval), 'default_due': Period.containing(unit, today)};
}

_Fields? _xTime(RegExpMatch m, DateTime today) {
  final hour = int.parse(m.namedGroup('hour')!);
  final minute = int.parse(m.namedGroup('minute') ?? '0');
  if (hour > 23 || minute > 59) return null;
  return {'due_time': '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'};
}

final _xRecurrenceRules = [
  // Wochentage als Wiederholung brauchen „jede“: „elke maandag“, „chaque lundi“, „tous les lundis“, „cada lunes“.
  _Rule(kindRecurrence, '@B@$_xEvery\\s+(?<days>$_xRecDay(?:$_xAnd(?:$_xEvery\\s+)?$_xRecDay)*)@E@', _xRecurringWeekdays),
  _Rule(kindRecurrence, '@B@(?:om\\s+de|tous\\s+les|toutes\\s+les|cada)\\s+(\\d+)\\s+($_xUnit)@E@', _xRecurringEveryN),
  _Rule(
    kindRecurrence,
    '@B@(?:$_xEvery\\s+(?<unit>$_xUnit)'
        r'|(?<adverb>dagelijks|wekelijks|maandelijks|jaarlijks|quotidiennement|quotidien(?:ne)?|hebdomadaire'
        r'|mensuel(?:le)?|annuel(?:le)?|diariamente|diario|semanal(?:mente)?|mensual(?:mente)?|anual(?:mente)?))@E@',
    _xRecurringUnit,
  ),
];

final _xTimeRules = [
  // „om 9 uur“, „om 9:30“, „à 9h“, „14h30“, „à 9:30“, „a las 9“, „a las 9:30“.
  _Rule(kindTime, r'@B@(?:om\s+)?(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\s*uur@E@', _xTime),
  _Rule(kindTime, r'@B@om\s+(?<hour>\d{1,2}):(?<minute>\d{2})@E@', _xTime),
  // „9h“ allein könnte eine Dauer sein („2h lernen“); ohne „à“ nur mit Minuten.
  _Rule(kindTime, r'@B@à\s+(?<hour>\d{1,2})\s*h(?:\s*(?<minute>\d{2}))?@E@', _xTime),
  _Rule(kindTime, r'@B@(?<hour>\d{1,2})h(?<minute>\d{2})@E@', _xTime),
  _Rule(kindTime, r'@B@à\s+(?<hour>\d{1,2}):(?<minute>\d{2})@E@', _xTime),
  _Rule(kindTime, r'@B@a\s+las?\s+(?<hour>\d{1,2})(?::(?<minute>\d{2}))?@E@', _xTime),
];

final _xDueRules = [
  _Rule(kindDue, '@B@(?:over|binnen|dans|en|dentro\\s+de)\\s+($_xNumber)\\s+($_xUnit)@E@', _xInN),
  _Rule(
    kindDue,
    r'@B@(?:pour\s+|para\s+)?(vandaag|aujourd' "'" r'hui|hoy|overmorgen|après-demain|apres-demain|demain'
        r'|pasado\s+mañana|pasado\s+manana|mañana|manana)@E@',
    _xRelativeDay,
  ),
  _Rule(
    kindDue,
    r'@B@(?:eind(?:e)?\s+(?:van\s+)?(?:de\s+|het\s+)?(?<next>volgende\s+)?(?:deze\s+|dit\s+)?(?<unit>week|maand|kwartaal|jaar)'
        r'|fin\s+(?:de\s+la\s+|du\s+|de\s+l' "'" r'|d' "'" r')(?<unit2>semaine|mois|trimestre|année|annee)(?<next2>\s+prochaine?)?'
        r'|(?:a\s+)?finales?\s+de(?:l|\s+la)?\s+(?<unit3>semana|mes|trimestre|año|ano)(?<next3>\s+que\s+viene)?)@E@',
    _xEndOf,
  ),
  _Rule(kindDue, '@B@$_xPrep(?:(?:la|le|l\'|el)\\s*)?(?<next>$_xNext)\\s+(?<unit>$_xUnit)@E@', _xPeriod),
  _Rule(
    kindDue,
    '@B@$_xPrep(?:(?:la|le|l\'|el)\\s*)?(?<unit>semaine|mois|trimestre|année|annee|an|semana|mes|trimestre|año|ano)'
        r'\s+(?<next>prochaine?|que\s+viene|próxim[oa]|proxim[oa])@E@',
    _xPeriod,
  ),
  _Rule(kindDue, '@B@$_xPrep(?<next>)$_xThis\\s+(?<unit>$_xUnit)@E@', _xPeriod),
  _Rule(
    kindDue,
    '@B@$_xPrep' r'(?:la\s+|en\s+la\s+)?(?:semaine|semana|sem\.?)\s*(\d{1,2})(?:\s*[/.]?\s*(\d{4}))?@E@',
    _calendarWeek,
  ),
  _Rule(
    kindDue,
    '@B@$_xPrep' r'(?:(?:volgende|komende|el\s+próximo|el\s+proximo|el)\s+)?(' '$_xWeekday' r')(?:\s+prochain)?@E@',
    _xWeekdayDue,
  ),
  _Rule(kindDue, '@B@$_xPrep($_xMonth)' r'(?:\s+(?:de\s+)?(\d{4}))?@E@', _xMonthDue),
  _Rule(kindDue, '@B@$_xMonthPrep' r'(mars|mayo)(?:\s+(?:de\s+)?(\d{4}))?@E@', _xMonthDue),
];

/// Wiederholungen und Uhrzeiten vor der deutsch-englischen Uhrzeitregel, damit von „om 9:30“ kein „om“ im
/// Titel bleibt; die übrigen Fälligkeiten zuletzt.
List<_Rule> _withOtherLanguages(List<_Rule> rules) {
  final firstTime = rules.indexWhere((rule) => rule.kind == kindTime);
  return [
    ...rules.sublist(0, firstTime),
    ..._xRecurrenceRules,
    ..._xTimeRules,
    ...rules.sublist(firstTime),
    ..._xDueRules,
  ];
}

const _trimChars = ' ,;:-–';

String _trim(String text) {
  var start = 0;
  var end = text.length;
  while (start < end && _trimChars.contains(text[start])) {
    start++;
  }
  while (end > start && _trimChars.contains(text[end - 1])) {
    end--;
  }
  return text.substring(start, end);
}

/// Strukturierte Angaben aus einem Aufgabentitel holen. Arten in [disabled] bleiben im Titel stehen.
ParseResult parse(String text, DateTime today, {Set<String> disabled = const {}}) {
  today = dateOnly(today);
  final fields = <String, Object?>{};
  var tokens = <Token>[];

  bool free(int start, int end) => tokens.every((t) => end <= t.start || start >= t.end);

  for (final rule in _rules) {
    final kind = rule.kind;
    if (disabled.contains(kind) || (kind == kindDue && fields.containsKey('due')) || fields.containsKey(kind)) {
      continue;
    }
    for (final match in rule.pattern.allMatches(text)) {
      if (!free(match.start, match.end)) continue;
      final values = rule.handler(match, today);
      if (values == null) continue;
      fields.addAll(values);
      tokens.add(Token(kind, match.start, match.end, match[0]!.trim()));
      break;
    }
  }

  var due = (fields['due'] ?? fields['default_due']) as Period?;
  var dueTime = fields['due_time'] as String?;
  if (dueTime != null && due == null) due = Period.day(today);
  if (dueTime != null && due!.granularity != Granularity.day) {
    // „KW 47 um 9 Uhr“ ergibt keinen Sinn; die Uhrzeit bleibt dann im Titel.
    tokens = [for (final t in tokens) if (t.kind != kindTime) t];
    dueTime = null;
  }

  var title = text;
  final byEnd = [...tokens]..sort((a, b) => b.start.compareTo(a.start));
  for (final token in byEnd) {
    title = '${title.substring(0, token.start)} ${title.substring(token.end)}';
  }
  title = _trim(title.replaceAll(RegExp(r'\s+'), ' '));
  tokens.sort((a, b) => a.start.compareTo(b.start));
  return ParseResult(
    title: title,
    due: due,
    dueTime: dueTime,
    recurrence: fields['recurrence'] as Recurrence?,
    priority: (fields['priority'] as int?) ?? 0,
    tokens: tokens,
  );
}
