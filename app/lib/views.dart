import 'models.dart';
import 'store.dart';

/// Welche Ansicht gezeigt wird: eine intelligente Liste oder eine eigene.
sealed class ViewRef {
  const ViewRef();

  /// Stabile Kennung, auch für das Android-Widget.
  String get id;

  String title(ThaskStore store);

  List<Task> tasks(ThaskStore store);

  /// Die Ansicht zu einer Kennung; unbekannte Kennungen ergeben „Mein Tag“.
  static ViewRef fromId(String id) => switch (id) {
        'this_week' => const ThisWeekView(),
        'this_month' => const ThisMonthView(),
        'important' => const ImportantView(),
        'planned' => const PlannedView(),
        _ when id.startsWith('list:') => ListRef(id.substring(5)),
        _ => const MyDayView(),
      };

  /// Alle Ansichten, die es gerade gibt: zuerst die intelligenten, dann die eigenen Listen.
  static List<ViewRef> all(ThaskStore store) => [
        const MyDayView(),
        const ThisWeekView(),
        const ThisMonthView(),
        const ImportantView(),
        const PlannedView(),
        for (final list in store.lists) ListRef(list.id),
      ];
}

class MyDayView extends ViewRef {
  const MyDayView();
  @override
  String get id => 'my_day';
  @override
  String title(ThaskStore store) => 'Mein Tag';
  @override
  List<Task> tasks(ThaskStore store) => store.myDay;
}

class ThisWeekView extends ViewRef {
  const ThisWeekView();
  @override
  String get id => 'this_week';
  @override
  String title(ThaskStore store) => 'Diese Woche';
  @override
  List<Task> tasks(ThaskStore store) => store.thisWeek;
}

class ThisMonthView extends ViewRef {
  const ThisMonthView();
  @override
  String get id => 'this_month';
  @override
  String title(ThaskStore store) => 'Diesen Monat';
  @override
  List<Task> tasks(ThaskStore store) => store.thisMonth;
}

class ImportantView extends ViewRef {
  const ImportantView();
  @override
  String get id => 'important';
  @override
  String title(ThaskStore store) => 'Wichtig';
  @override
  List<Task> tasks(ThaskStore store) => store.important;
}

class PlannedView extends ViewRef {
  const PlannedView();
  @override
  String get id => 'planned';
  @override
  String title(ThaskStore store) => 'Geplant';
  @override
  List<Task> tasks(ThaskStore store) => store.planned;
}

class ListRef extends ViewRef {
  const ListRef(this.listId);
  final String listId;
  @override
  String get id => 'list:$listId';
  @override
  String title(ThaskStore store) => store.list(listId)?.name ?? 'Liste';
  @override
  List<Task> tasks(ThaskStore store) => store.tasksOf(listId);
}
