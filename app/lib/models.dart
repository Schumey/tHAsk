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

/// Wochenbeginn (Montag) und ISO-Kalenderwoche eines Datums.
int isoWeek(DateTime d) {
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

  /// Lesbare Bezeichnung, z. B. „KW 46“, „November“, „Q4 2026“. Das Jahr entfällt, wenn es das heutige ist.
  String label(DateTime today) {
    final String text;
    final int year;
    switch (granularity) {
      case Granularity.day:
        text = '${_weekdays[start.weekday - 1]}, ${start.day}. ${_monthsShort[start.month - 1]}';
        year = start.year;
      case Granularity.week:
        text = 'KW ${isoWeek(start)}';
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
  const Recurrence(this.unit, this.interval);

  final Granularity unit;
  final int interval;

  factory Recurrence.fromJson(Map<String, dynamic> json) =>
      Recurrence(Granularity.values.byName(json['unit'] as String), (json['interval'] as num?)?.toInt() ?? 1);

  Map<String, dynamic> toJson() => {'unit': unit.name, 'interval': interval};
}

class Step {
  const Step({required this.id, required this.title, this.completed = false});

  final String id;
  final String title;
  final bool completed;

  factory Step.fromJson(Map<String, dynamic> json) =>
      Step(id: json['id'] as String, title: json['title'] as String, completed: json['completed'] as bool? ?? false);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'completed': completed};
}

const taskSorts = ['manual', 'important', 'due', 'title', 'created'];

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
    this.important = false,
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
  final bool important;
  final Period? due;
  final String? dueTime;
  final String? reminder;
  final Recurrence? recurrence;
  final String? myDay;
  final List<Step> steps;
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
        important: json['important'] as bool? ?? false,
        due: json['due'] == null ? null : Period.fromJson(json['due'] as Map<String, dynamic>),
        dueTime: json['due_time'] as String?,
        reminder: json['reminder'] as String?,
        recurrence:
            json['recurrence'] == null ? null : Recurrence.fromJson(json['recurrence'] as Map<String, dynamic>),
        myDay: json['my_day'] as String?,
        steps: [for (final s in json['steps'] as List? ?? const []) Step.fromJson(s as Map<String, dynamic>)],
        categories: [for (final c in json['categories'] as List? ?? const []) c as String],
        position: (json['position'] as num?)?.toDouble() ?? 0,
        created: json['created'] as String? ?? '',
        completedAt: json['completed_at'] as String?,
      );

  bool inMyDay(DateTime today) => myDay == isoDate(today);

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
    case 'important':
      return _stable(manual, (a, b) => (a.important ? 0 : 1).compareTo(b.important ? 0 : 1));
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
