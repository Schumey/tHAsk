import 'l10n.dart';
import 'models.dart';
import 'store.dart';

/// Welche Ansicht gezeigt wird: eine intelligente Liste oder eine eigene.
sealed class ViewRef {
  const ViewRef();

  /// Stabile Kennung, auch für das Android-Widget.
  String get id;

  String title(ThaskStore store);

  List<Task> tasks(ThaskStore store);

  /// Die Ansicht zu einer Kennung; unbekannte Kennungen ergeben „Heute“.
  static ViewRef fromId(String id) => switch (id) {
        'this_week' => const ThisWeekView(),
        'this_month' => const ThisMonthView(),
        'important' => const ImportantView(),
        'planned' => const PlannedView(),
        'overdue' => const OverdueView(),
        _ when id.startsWith('list:') => ListRef(id.substring(5)),
        _ => const TodayView(),
      };

  /// Alle Ansichten, die es gerade gibt: zuerst die intelligenten, dann die eigenen Listen.
  static List<ViewRef> all(ThaskStore store) => [
        const TodayView(),
        if (store.overdueMode == 'separate') const OverdueView(),
        const ThisWeekView(),
        const ThisMonthView(),
        const ImportantView(),
        const PlannedView(),
        for (final list in store.lists) ListRef(list.id),
      ];
}

class TodayView extends ViewRef {
  const TodayView();
  // Kennung des früheren „Mein Tag“, damit eingerichtete Widgets ihre Ansicht behalten.
  @override
  String get id => 'my_day';
  @override
  String title(ThaskStore store) => tr('view_today');
  @override
  List<Task> tasks(ThaskStore store) => store.dueToday;
}

/// Nur mit der Option „Überfällige in einer eigenen Ansicht“.
class OverdueView extends ViewRef {
  const OverdueView();
  @override
  String get id => 'overdue';
  @override
  String title(ThaskStore store) => tr('view_overdue');
  @override
  List<Task> tasks(ThaskStore store) => store.overdue;
}

class ThisWeekView extends ViewRef {
  const ThisWeekView();
  @override
  String get id => 'this_week';
  @override
  String title(ThaskStore store) => tr('view_this_week');
  @override
  List<Task> tasks(ThaskStore store) => store.thisWeek;
}

class ThisMonthView extends ViewRef {
  const ThisMonthView();
  @override
  String get id => 'this_month';
  @override
  String title(ThaskStore store) => tr('view_this_month');
  @override
  List<Task> tasks(ThaskStore store) => store.thisMonth;
}

class ImportantView extends ViewRef {
  const ImportantView();
  @override
  String get id => 'important';
  @override
  String title(ThaskStore store) => tr('view_important');
  @override
  List<Task> tasks(ThaskStore store) => store.important;
}

class PlannedView extends ViewRef {
  const PlannedView();
  @override
  String get id => 'planned';
  @override
  String title(ThaskStore store) => tr('view_planned');
  @override
  List<Task> tasks(ThaskStore store) => store.planned;
}

class ListRef extends ViewRef {
  const ListRef(this.listId);
  final String listId;
  @override
  String get id => 'list:$listId';
  @override
  String title(ThaskStore store) => store.list(listId)?.name ?? tr('list');
  @override
  List<Task> tasks(ThaskStore store) => store.tasksOf(listId);
}
