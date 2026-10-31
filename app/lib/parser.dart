/// Schnelleingabe: Fälligkeit, Uhrzeit, Wiederholung und Wichtig aus einem Aufgabentitel lösen.
///
/// „Reifen wechseln nächsten Monat !“ ergibt den Titel „Reifen wechseln“, fällig im nächsten Monat, wichtig.
/// Spiegelt `custom_components/thask/core/parser.py` (gleiche Regeln, gleiche Tests), damit die App
/// auch ohne Verbindung zu Home Assistant dasselbe erkennt.
library;

import 'models.dart';

const kindDue = 'due';
const kindTime = 'time';
const kindRecurrence = 'recurrence';
const kindImportant = 'important';

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
    this.important = false,
    this.tokens = const [],
  });

  final String title;
  final Period? due;
  final String? dueTime;
  final Recurrence? recurrence;
  final bool important;
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
  'a': 1, 'one': 1, 'two': 2, 'three': 3,
};

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

/// Index des Wochentags, Montag = 1.
int _weekdayIndex(String word) {
  final w = word.toLowerCase();
  return _weekdays.indexWhere((names) => names.$1 == w || names.$2 == w) + 1;
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

_Fields _recurringWeekday(RegExpMatch m, DateTime today) => {
      'recurrence': const Recurrence(Granularity.week, 1),
      'due': Period.day(_nextWeekday(today, _weekdayIndex(m[1]!), includeToday: true)),
    };

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

_Fields _important(RegExpMatch m, DateTime today) => {'important': true};

class _Rule {
  _Rule(this.kind, String pattern, this.handler) : pattern = _re(pattern);

  final String kind;
  final RegExp pattern;
  final _Handler handler;
}

final _rules = [
  _Rule(kindRecurrence, r'@B@(?:jede[nrs]?|every)\s+(@WEEKDAY@)@E@', _recurringWeekday),
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
  _Rule(kindImportant, r'(?<!\S)!+(?!\S)', _important),
];

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
    important: fields['important'] == true,
    tokens: tokens,
  );
}
