/// Datenmodell der tHAsk-API (spiegelt `custom_components/thask/core/models.py`).
library;

enum Granularity { day, week, month, quarter, year }

const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];
const _monthsShort = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
  'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monate zum Datum addieren; der Tag wird auf den letzten des Zielmonats begrenzt.
DateTime addMonths(DateTime d, int months) {
  final index = d.month - 1 + months;
  final year = d.year + (index / 12).floor();
  final month = index % 12 + 1;
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day < last ? d.day : last);
}

/// Wochenbeginn (Montag) und ISO-Kalenderwoche eines Datums.
int isoWeekNumber(DateTime d) {
  final thursday = dateOnly(d).add(Duration(days: 4 - d.weekday));
  final jan1 = DateTime(thursday.year, 1, 1);
  return (thursday.difference(jan1).inDays ~/ 7) + 1;
}

int isoWeekYear(DateTime d) => dateOnly(d).add(Duration(days: 4 - d.weekday)).year;

/// Ein Zeitraum, in dem eine Aufgabe fällig ist: Tag, Woche, Monat, Quartal oder Jahr.
class Period {
  const Period(this.granularity, this.start);

  final Granularity granularity;
  final DateTime start;

  factory Period.fromJson(Map<String, dynamic> json) => Period(
        Granularity.values.byName(json['granularity'] as String),
        dateOnly(DateTime.parse(json['start'] as String)),
      );

  Map<String, dynamic> toJson() => {'granularity': granularity.name, 'start': isoDate(start)};

  /// Letzter Tag des Zeitraums.
  DateTime get end => switch (granularity) {
        Granularity.day => start,
        Granularity.week => DateTime(start.year, start.month, start.day + 6),
        Granularity.month => DateTime(start.year, start.month + 1, 0),
        Granularity.quarter => DateTime(start.year, start.month + 3, 0),
        Granularity.year => DateTime(start.year, 12, 31),
      };

  bool contains(DateTime day) => !day.isBefore(start) && !day.isAfter(end);

  factory Period.day(DateTime day) => Period(Granularity.day, dateOnly(day));

  factory Period.month(int year, int month) => Period(Granularity.month, DateTime(year, month, 1));

  factory Period.quarter(int year, int quarter) => Period(Granularity.quarter, DateTime(year, 3 * (quarter - 1) + 1, 1));

  factory Period.year(int year) => Period(Granularity.year, DateTime(year, 1, 1));

  /// Die ISO-Kalenderwoche [week] des Jahres [year]; null, wenn es diese Woche nicht gibt (z. B. KW 53).
  static Period? isoWeek(int year, int week) {
    if (week < 1) return null;
    final jan4 = DateTime(year, 1, 4);
    final monday = DateTime(jan4.year, 1, 4 - (jan4.weekday - 1) + 7 * (week - 1));
    if (isoWeekYear(monday) != year || isoWeekNumber(monday) != week) return null;
    return Period(Granularity.week, monday);
  }

  /// Der Zeitraum gleicher Art, der [day] enthält.
  static Period containing(Granularity granularity, DateTime day) {
    final d = dateOnly(day);
    return Period(
      granularity,
      switch (granularity) {
        Granularity.day => d,
        Granularity.week => d.subtract(Duration(days: d.weekday - 1)),
        Granularity.month => DateTime(d.year, d.month, 1),
        Granularity.quarter => DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1, 1),
        Granularity.year => DateTime(d.year, 1, 1),
      },
    );
  }

  Period shift(int count) => Period(
        granularity,
        switch (granularity) {
          Granularity.day => DateTime(start.year, start.month, start.day + count),
          Granularity.week => DateTime(start.year, start.month, start.day + 7 * count),
          Granularity.month => DateTime(start.year, start.month + count, 1),
          Granularity.quarter => DateTime(start.year, start.month + 3 * count, 1),
          Granularity.year => DateTime(start.year + count, 1, 1),
        },
      );

  /// Lesbare Bezeichnung, z. B. „KW 46“, „November“, „Q4 2026“, bei Tagen „Heute“ und „Morgen“.
  /// Das Jahr entfällt, wenn es das heutige ist.
  String label(DateTime today) {
    final String text;
    final int year;
    switch (granularity) {
      case Granularity.day:
        final days = start.difference(dateOnly(today)).inDays;
        if (days == 0) return 'Heute';
        if (days == 1) return 'Morgen';
        text = '${_weekdays[start.weekday - 1]}, ${start.day}. ${_monthsShort[start.month - 1]}';
        year = start.year;
      case Granularity.week:
        text = 'KW ${isoWeekNumber(start)}';
        year = isoWeekYear(start);
      case Granularity.month:
        text = _months[start.month - 1];
        year = start.year;
      case Granularity.quarter:
        text = 'Q${(start.month - 1) ~/ 3 + 1}';
        year = start.year;
      case Granularity.year:
        return '${start.year}';
    }
    return year == today.year ? text : '$text $year';
  }

  @override
  bool operator ==(Object other) =>
      other is Period && other.granularity == granularity && other.start == start;

  @override
  int get hashCode => Object.hash(granularity, start);
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Recurrence {
  const Recurrence(this.unit, this.interval, [this.weekdays = const []]);

  final Granularity unit;
  final int interval;

  /// Wochentage einer wöchentlichen Wiederholung, 0 = Montag … 6 = Sonntag (wie in der Integration).
  /// Leer heißt: am Wochentag des Fälligkeitstags.
  final List<int> weekdays;

  factory Recurrence.fromJson(Map<String, dynamic> json) {
    final unit = Granularity.values.byName(json['unit'] as String);
    final days = unit == Granularity.week ? (json['weekdays'] as List<dynamic>? ?? const []) : const [];
    return Recurrence(
      unit,
      (json['interval'] as num?)?.toInt() ?? 1,
      ({for (final d in days) (d as num).toInt()}.toList()..sort()),
    );
  }

  Map<String, dynamic> toJson() => {
        'unit': unit.name,
        'interval': interval,
        if (weekdays.isNotEmpty) 'weekdays': weekdays,
      };
}

class TaskStep {
  const TaskStep({required this.id, required this.title, this.completed = false});

  final String id;
  final String title;
  final bool completed;

  factory TaskStep.fromJson(Map<String, dynamic> json) =>
      TaskStep(id: json['id'] as String, title: json['title'] as String, completed: json['completed'] as bool? ?? false);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'completed': completed};
}

const taskSorts = ['manual', 'priority', 'due', 'title', 'created'];

class TaskList {
  const TaskList({
    required this.id,
    required this.name,
    this.group,
    this.color,
    this.icon,
    this.position = 0,
    this.sort = 'manual',
  });

  final String id;
  final String name;
  final String? group;
  final String? color;
  final String? icon;
  final double position;
  final String sort;

  factory TaskList.fromJson(Map<String, dynamic> json) => TaskList(
        id: json['id'] as String,
        name: json['name'] as String,
        group: json['group'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        position: (json['position'] as num?)?.toDouble() ?? 0,
        sort: json['sort'] as String? ?? 'manual',
      );
}

class Task {
  const Task({
    required this.id,
    required this.listId,
    required this.title,
    this.notes = '',
    this.completed = false,
    this.priority = 0,
    this.due,
    this.dueTime,
    this.reminder,
    this.recurrence,
    this.myDay,
    this.steps = const [],
    this.categories = const [],
    this.position = 0,
    this.created = '',
    this.completedAt,
  });

  final String id;
  final String listId;
  final String title;
  final String notes;
  final bool completed;
  /// 0 keine, 1 niedrig, 2 mittel, 3 hoch.
  final int priority;
  final Period? due;
  final String? dueTime;
  final String? reminder;
  final Recurrence? recurrence;
  final String? myDay;
  final List<TaskStep> steps;
  final List<String> categories;
  final double position;
  final String created;
  final String? completedAt;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        listId: json['list_id'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
        // Ältere Server kennen nur das Wichtig-Kennzeichen; es entspricht Priorität hoch.
        priority: (json['priority'] as num?)?.toInt() ?? (json['important'] == true ? 3 : 0),
        due: json['due'] == null ? null : Period.fromJson(json['due'] as Map<String, dynamic>),
        dueTime: json['due_time'] as String?,
        reminder: json['reminder'] as String?,
        recurrence:
            json['recurrence'] == null ? null : Recurrence.fromJson(json['recurrence'] as Map<String, dynamic>),
        myDay: json['my_day'] as String?,
        steps: [for (final s in json['steps'] as List? ?? const []) TaskStep.fromJson(s as Map<String, dynamic>)],
        categories: [for (final c in json['categories'] as List? ?? const []) c as String],
        position: (json['position'] as num?)?.toDouble() ?? 0,
        created: json['created'] as String? ?? '',
        completedAt: json['completed_at'] as String?,
      );

  bool get isHighPriority => priority >= 3;

  /// „Heute“: offen und bis heute fällig (Überfälliges eingeschlossen), oder heute erledigt.
  bool inToday(DateTime today) {
    final day = dateOnly(today);
    if (due == null || due!.end.isAfter(day)) return false;
    if (!completed) return true;
    final done = completedAt == null ? null : DateTime.tryParse(completedAt!)?.toLocal();
    return done != null && !dateOnly(done).isBefore(day);
  }

  bool isOverdue(DateTime today) => !completed && due != null && due!.end.isBefore(dateOnly(today));
}

/// Aufgaben nach dem Sortiermodus einer Liste ordnen; Gleiche behalten die manuelle Reihenfolge.
List<Task> sortTasks(Iterable<Task> tasks, String mode) {
  final manual = tasks.toList()
    ..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.created.compareTo(b.created);
    });
  final far = DateTime(9999);
  switch (mode) {
    case 'priority':
    case 'important':
      return _stable(manual, (a, b) => b.priority.compareTo(a.priority));
    case 'due':
      return _stable(manual, (a, b) => (a.due?.end ?? far).compareTo(b.due?.end ?? far));
    case 'title':
      return _stable(manual, (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case 'created':
      return _stable(manual, (a, b) => b.created.compareTo(a.created));
  }
  return manual;
}

List<Task> _stable(List<Task> tasks, int Function(Task, Task) compare) {
  final indexed = [for (var i = 0; i < tasks.length; i++) (i, tasks[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
