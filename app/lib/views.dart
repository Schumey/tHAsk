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
        'day_view' => const DayPlanView(),
        _ when id.startsWith('list:') => ListRef(id.substring(5)),
        _ => const TodayView(),
      };

  /// Alle Ansichten für das Widget, in der Reihenfolge des Menüs: zuerst die intelligenten, dann die
  /// eigenen Listen. Der Tagesplan zeigt im Widget immer heute (siehe [WidgetDayPlan]).
  static List<ViewRef> all(ThaskStore store) => [
        const TodayView(),
        if (store.overdueMode == 'separate') const OverdueView(),
        for (final view in const [ThisWeekView(), ThisMonthView(), ImportantView(), PlannedView(), WidgetDayPlan()])
          if (!store.hiddenViews.contains(view.id)) view,
        for (final list in store.visibleLists) ListRef(list.id),
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

/// Ein Tag, in der Kopfzeile gewählt, mit Vorschauen wiederkehrender Aufgaben.
class DayPlanView extends ViewRef {
  const DayPlanView();
  @override
  String get id => 'day_view';
  @override
  String title(ThaskStore store) => tr('view_day_view');
  @override
  List<Task> tasks(ThaskStore store) => store.dayPlan;
}

/// Der Tagesplan von heute, für das Widget; dieselbe Kennung wie [DayPlanView], damit „Öffnen“ ihn zeigt.
class WidgetDayPlan extends ViewRef {
  const WidgetDayPlan();
  @override
  String get id => 'day_view';
  @override
  String title(ThaskStore store) => tr('view_day_view');
  @override
  List<Task> tasks(ThaskStore store) => store.dayPlanFor(store.today);
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
