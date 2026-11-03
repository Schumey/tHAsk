/// Datenmodell der tHAsk-API (spiegelt `custom_components/thask/core/models.py`).
library;

import 'l10n.dart';

/// [custom]: ein eigener Zeitraum („X-Block“), den eine Regel der Integration in einem Kalender findet;
/// er hat eigenen Anfang, eigenes Ende und einen Namen.
enum Granularity { day, week, month, quarter, year, custom }

/// Die Granularitäten, die sich aus einem Datum ergeben (ohne [Granularity.custom]).
const fixedGranularities = [Granularity.day, Granularity.week, Granularity.month, Granularity.quarter, Granularity.year];

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

/// Ein Zeitraum, in dem eine Aufgabe fällig ist: Tag, Woche, Monat, Quartal, Jahr oder ein eigener Zeitraum.
class Period {
  const Period(this.granularity, this.start, {this.until, this.name = '', this.rule});

  /// Ein eigener Zeitraum von [start] bis [end] (wie Period.custom in core/period.py).
  factory Period.custom(DateTime start, DateTime end, String name, String? rule) =>
      Period(Granularity.custom, dateOnly(start), until: dateOnly(end).isBefore(start) ? dateOnly(start) : dateOnly(end), name: name, rule: rule);

  final Granularity granularity;
  final DateTime start;

  /// Nur eigene Zeiträume: letzter Tag, Name und die Regel, die ihn gefunden hat.
  final DateTime? until;
  final String name;
  final String? rule;

  factory Period.fromJson(Map<String, dynamic> json) {
    final granularity = Granularity.values.byName(json['granularity'] as String);
    final start = dateOnly(DateTime.parse(json['start'] as String));
    if (granularity != Granularity.custom) return Period(granularity, start);
    final end = json['end'] as String?;
    return Period.custom(start, end == null ? start : DateTime.parse(end), json['name'] as String? ?? '', json['rule'] as String?);
  }

  Map<String, dynamic> toJson() => {
        'granularity': granularity.name,
        'start': isoDate(start),
        if (granularity == Granularity.custom) ...{'end': isoDate(end), 'name': name, 'rule': rule},
      };

  /// Letzter Tag des Zeitraums.
  DateTime get end => switch (granularity) {
        Granularity.custom => until ?? start,
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
        Granularity.day || Granularity.custom => d,
        Granularity.week => d.subtract(Duration(days: d.weekday - 1)),
        Granularity.month => DateTime(d.year, d.month, 1),
        Granularity.quarter => DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1, 1),
        Granularity.year => DateTime(d.year, 1, 1),
      },
    );
  }

  int get _length => end.difference(start).inHours ~/ 24 + 1;

  /// Ein eigener Zeitraum mit gleicher Länge ab [from].
  Period _customFrom(DateTime from) => Period.custom(from, DateTime(from.year, from.month, from.day + _length - 1), name, rule);

  Period shift(int count) => granularity == Granularity.custom
      ? _customFrom(DateTime(start.year, start.month, start.day + _length * count))
      : Period(
        granularity,
        switch (granularity) {
          Granularity.custom || Granularity.day => DateTime(start.year, start.month, start.day + count),
          Granularity.week => DateTime(start.year, start.month, start.day + 7 * count),
          Granularity.month => DateTime(start.year, start.month + count, 1),
          Granularity.quarter => DateTime(start.year, start.month + 3 * count, 1),
          Granularity.year => DateTime(start.year + count, 1, 1),
        },
      );

  /// Um [count] Einheiten [unit] verschieben; die Art des Zeitraums bleibt (wie Period.shift in core/period.py).
  /// Ein eigener Zeitraum behält seine Länge.
  Period shiftBy(int count, Granularity unit) {
    if (unit == Granularity.custom) return shift(count);
    final moved = switch (unit) {
      Granularity.custom || Granularity.day => DateTime(start.year, start.month, start.day + count),
      Granularity.week => DateTime(start.year, start.month, start.day + 7 * count),
      Granularity.month => addMonths(start, count),
      Granularity.quarter => addMonths(start, 3 * count),
      Granularity.year => addMonths(start, 12 * count),
    };
    return granularity == Granularity.custom ? _customFrom(moved) : Period.containing(granularity, moved);
  }

  /// Lesbare Bezeichnung, z. B. „KW 46“, „November“, „Q4 2026“, bei Tagen „Heute“ und „Morgen“.
  /// Das Jahr entfällt, wenn es das heutige ist.
  String label(DateTime today) {
    final String text;
    final int year;
    switch (granularity) {
      case Granularity.day:
        final days = start.difference(dateOnly(today)).inDays;
        if (days == 0) return tr('today');
        if (days == 1) return tr('tomorrow');
        text = L10n.dayLabel(start);
        year = start.year;
      case Granularity.week:
        text = L10n.weekLabel(isoWeekNumber(start));
        year = isoWeekYear(start);
      case Granularity.month:
        text = L10n.months[start.month - 1];
        year = start.year;
      case Granularity.quarter:
        text = 'Q${(start.month - 1) ~/ 3 + 1}';
        year = start.year;
      case Granularity.year:
        return '${start.year}';
      case Granularity.custom:
        // „X-Block 6. Nov.“: am Namen allein ist ein Block nicht vom nächsten zu unterscheiden.
        text = '$name ${L10n.shortDate(start)}'.trim();
        year = start.year;
    }
    return year == today.year ? text : '$text $year';
  }

  @override
  bool operator ==(Object other) =>
      other is Period && other.granularity == granularity && other.start == start && other.until == until && other.rule == rule;

  @override
  int get hashCode => Object.hash(granularity, start, until, rule);
}

/// Ein eigener Zeitraum der Integration („X-Block“) mit den Zeiträumen, die seine Regel gefunden hat.
class CustomPeriod {
  const CustomPeriod({required this.id, required this.name, required this.instances});

  final String id;
  final String name;

  /// Gefundene Zeiträume, die noch nicht vorbei sind, in Reihenfolge.
  final List<Period> instances;

  factory CustomPeriod.fromJson(Map<String, dynamic> json) => CustomPeriod(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        instances: [for (final p in json['instances'] as List? ?? const []) Period.fromJson((p as Map).cast<String, dynamic>())],
      );

  /// Gefundene Zeiträume, die vor [today] noch nicht zu Ende waren.
  List<Period> upcoming(DateTime today) => [for (final p in instances) if (!p.end.isBefore(dateOnly(today))) p];
}

/// Die gefundenen Zeiträume der Regel von [period], die nicht vor [today] enden.
List<Period> customUpcoming(List<CustomPeriod> periods, String? rule, DateTime today) =>
    periods.where((p) => p.id == rule).firstOrNull?.upcoming(today) ?? const [];

/// Der gefundene Zeitraum vor ([step] -1) oder nach ([step] 1) [period] in seiner Regel, sonst null.
Period? customAdjacent(List<CustomPeriod> periods, Period period, int step, DateTime today) {
  final found = customUpcoming(periods, period.rule, today);
  return step > 0
      ? found.where((p) => p.start.isAfter(period.start)).firstOrNull
      : found.where((p) => p.start.isBefore(period.start)).lastOrNull;
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

  /// Der nächste Zeitraum nach [period], der nicht schon vor [today] zu Ende war (wie Recurrence.next_period).
  /// „Jeder X-Block“ ([Granularity.custom]) nimmt den nächsten, den die Regel gefunden hat ([periods]).
  Period nextPeriod(Period period, DateTime today, [List<CustomPeriod> periods = const []]) {
    final day0 = dateOnly(today);
    if (unit == Granularity.custom) {
      final found = customUpcoming(periods, period.rule, today).where((p) => p.start.isAfter(period.start)).firstOrNull;
      if (found != null) return found;
      // Noch nichts gefunden: direkt danach, mit gleicher Länge.
      var following = period.shift(1);
      while (following.end.isBefore(day0)) {
        following = following.shift(1);
      }
      return following;
    }
    final step = interval < 1 ? 1 : interval;
    if (weekdays.isNotEmpty && unit == Granularity.week && period.granularity == Granularity.day) {
      // Wochen zählen ab der Woche des bisherigen Tags, damit „alle zwei Wochen“ im Takt bleibt.
      final start = period.start;
      final anchor = DateTime(start.year, start.month, start.day - (start.weekday - 1));
      for (var offset = 1;; offset++) {
        final day = DateTime(start.year, start.month, start.day + offset);
        final weeks = (day.difference(anchor).inHours / 24).round() ~/ 7;
        if (weeks % step == 0 && weekdays.contains(day.weekday - 1) && !day.isBefore(day0)) return Period.day(day);
      }
    }
    var following = period.shiftBy(step, unit);
    while (following.end.isBefore(day0)) {
      final after = following.shiftBy(step, unit);
      // Eine feinere Einheit als der Zeitraum („täglich“ bei einer Woche) bewegt ihn nicht.
      if (!after.start.isAfter(following.start)) break;
      following = after;
    }
    return following;
  }
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
    this.members = const [],
  });

  final String id;
  final String name;
  final String? group;
  final String? color;
  final String? icon;
  final double position;
  final String sort;

  /// HA-Benutzer, für die die Liste ist; leer = alle. Nur für die Übersicht, kein Zugriffsschutz.
  final List<String> members;

  /// Ob die Liste in die Übersicht von [userId] gehört (ohne bekannten Benutzer: alle).
  bool isFor(String? userId) => members.isEmpty || userId == null || members.contains(userId);

  factory TaskList.fromJson(Map<String, dynamic> json) => TaskList(
        id: json['id'] as String,
        name: json['name'] as String,
        group: json['group'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        position: (json['position'] as num?)?.toDouble() ?? 0,
        sort: json['sort'] as String? ?? 'manual',
        members: [for (final id in json['members'] as List? ?? const []) id as String],
      );
}

/// Datei an einer Aufgabe; liegt in Home Assistant unter `thask_attachments/`.
class TaskAttachment {
  const TaskAttachment({required this.id, required this.name, this.size = 0, this.contentType = ''});

  final String id;
  final String name;
  final int size;
  final String contentType;

  factory TaskAttachment.fromJson(Map<String, dynamic> json) => TaskAttachment(
        id: json['id'] as String,
        name: json['name'] as String,
        size: (json['size'] as num?)?.toInt() ?? 0,
        contentType: json['content_type'] as String? ?? '',
      );

  /// Größe für Menschen: „830 B“, „12 KB“, „3,4 MB“.
  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).round()} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
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
    this.attachments = const [],
    this.preview = false,
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
  final List<TaskAttachment> attachments;

  /// Vorschau eines kommenden Vorkommens einer wiederkehrenden Aufgabe im Tagesplan: Es gibt sie noch nicht,
  /// sie entsteht erst beim Abhaken der jetzigen. Sie trägt deren Kennung.
  final bool preview;

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
        attachments: [
          for (final a in json['attachments'] as List? ?? const []) TaskAttachment.fromJson(a as Map<String, dynamic>),
        ],
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

  /// Die Fälligkeiten, die eine wiederkehrende Aufgabe nach der jetzigen bekommt, bis zu denen, die an [until]
  /// beginnen: was wiederholtes Abhaken anlegen würde. Leer ohne Wiederholung und für Erledigtes.
  List<Period> projectedPeriods(DateTime until, DateTime today, {List<CustomPeriod> periods = const [], int limit = 2000}) {
    if (recurrence == null || due == null || completed) return const [];
    final last = dateOnly(until);
    // „Jeder X-Block“: nur die Blöcke, die die Regel gefunden hat, keine geratenen.
    if (recurrence!.unit == Granularity.custom) {
      return [
        for (final p in customUpcoming(periods, due!.rule, today))
          if (p.start.isAfter(due!.start) && !p.start.isAfter(last)) p,
      ];
    }
    final result = <Period>[];
    var period = due!;
    while (result.length < limit) {
      final next = recurrence!.nextPeriod(period, today);
      if (!next.start.isAfter(period.start) || next.start.isAfter(last)) break;
      result.add(next);
      period = next;
    }
    return result;
  }

  /// Diese Aufgabe als Vorschau mit der Fälligkeit [due].
  Task previewAt(Period due) => Task(
        id: id,
        listId: listId,
        title: title,
        notes: notes,
        priority: priority,
        due: due,
        dueTime: dueTime,
        recurrence: recurrence,
        steps: [for (final s in steps) TaskStep(id: s.id, title: s.title)],
        categories: categories,
        position: position,
        created: created,
        attachments: attachments,
        preview: true,
      );
}

/// Alles, was an [day] fällig ist: Aufgaben, deren Zeitraum den Tag enthält, und Vorschauen wiederkehrender
/// Aufgaben, die dann fällig werden, aber noch nicht existieren (wie dayTasks in thask-common.js).
List<Task> dayTasks(Iterable<Task> tasks, DateTime day, DateTime today, [List<CustomPeriod> periods = const []]) {
  final d = dateOnly(day);
  return [
    for (final task in tasks) ...[
      if (task.due != null && task.due!.contains(d)) task,
      for (final due in task.projectedPeriods(d, today, periods: periods).where((p) => p.contains(d)).take(1))
        task.previewAt(due),
    ],
  ];
}

/// Reihenfolge innerhalb eines Tages: Uhrzeit, dann Priorität, dann die manuelle Reihenfolge.
List<Task> sortByTime(Iterable<Task> tasks) => _stable(
      tasks.toList()..sort((a, b) => a.position.compareTo(b.position)),
      (a, b) {
        final byTime = (a.dueTime ?? '99').compareTo(b.dueTime ?? '99');
        return byTime != 0 ? byTime : b.priority.compareTo(a.priority);
      },
    );

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
