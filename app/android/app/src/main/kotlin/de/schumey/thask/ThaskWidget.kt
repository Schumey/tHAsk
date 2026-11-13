package de.schumey.thask

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalGlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.CheckboxDefaults
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import org.json.JSONObject

// HA-Blau wie in der App; für Text auf Weiß eine dunklere Stufe, damit er lesbar bleibt.
private val background = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF1C1C1C))
private val textPrimary = ColorProvider(day = Color(0xFF1C1B1F), night = Color(0xFFE6E1E5))
private val textSecondary = ColorProvider(day = Color(0xFF5F6368), night = Color(0xFFBDC1C6))
private val accent = ColorProvider(day = Color(0xFF0277BD), night = Color(0xFF4FC3F7))
private val onAccent = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF00344F))
private val chipText = ColorProvider(day = Color(0xFF455A64), night = Color(0xFFC4C7C5))
private val chipTodayText = ColorProvider(day = Color(0xFF01579B), night = Color(0xFFB3E5FC))
private val danger = ColorProvider(day = Color(0xFFB3261E), night = Color(0xFFF2B8B5))
private val priorityLow = ColorProvider(day = Color(0xFF43A047), night = Color(0xFF66BB6A))
private val priorityMedium = ColorProvider(day = Color(0xFFF57C00), night = Color(0xFFFFA600))
private val priorityHigh = ColorProvider(day = Color(0xFFE53935), night = Color(0xFFEF5350))

internal const val PREFS = "HomeWidgetPreferences"

internal val TaskIdKey = ActionParameters.Key<String>("task_id")

internal class WidgetTask(
    val id: String,
    val title: String,
    val due: String?,
    val overdue: Boolean,
    /** 0 keine, 1 niedrig, 2 mittel, 3 hoch. */
    val priority: Int,
    /** Fällig bis heute. */
    val today: Boolean = false,
    /** Zeitraum (Woche, Monat …) statt eines festen Tags. */
    val fuzzy: Boolean = false,
    /** Kommendes Vorkommen einer wiederkehrenden Aufgabe im Tagesplan; Abhaken erledigt es vorab. */
    val preview: Boolean = false,
)

/** [count]: alle offenen Aufgaben der Ansicht; [tasks] ist auf die ersten begrenzt. */
internal class WidgetView(val id: String, val title: String, val tasks: List<WidgetTask>, val count: Int)

/** Liest die von der App geschriebenen Ansichten (`views`) aus den gemeinsamen Einstellungen. */
internal fun parseViews(json: String?): List<WidgetView> {
    if (json.isNullOrEmpty()) return emptyList()
    return try {
        val views = JSONObject(json).getJSONArray("views")
        (0 until views.length()).map { i ->
            val view = views.getJSONObject(i)
            val tasks = view.getJSONArray("tasks")
            WidgetView(
                view.getString("id"),
                view.getString("title"),
                (0 until tasks.length()).map { j ->
                    val task = tasks.getJSONObject(j)
                    WidgetTask(
                        task.getString("id"),
                        task.getString("title"),
                        if (task.isNull("due")) null else task.getString("due"),
                        task.optBoolean("overdue"),
                        // Ältere Daten kennen nur das Wichtig-Kennzeichen.
                        task.optInt("priority", if (task.optBoolean("important")) 3 else 0),
                        task.optBoolean("today"),
                        task.optBoolean("fuzzy"),
                        task.optBoolean("preview"),
                    )
                },
                view.optInt("count", tasks.length()),
            )
        }
    } catch (e: Exception) {
        emptyList()
    }
}

class ThaskWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Content(currentState()) }
    }

    @Composable
    private fun Content(state: HomeWidgetGlanceState) {
        val context = LocalContext.current
        val prefs = state.preferences
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(LocalGlanceId.current)
        val views = parseViews(prefs.getString("views", null))
        val view = views.firstOrNull { it.id == prefs.getString("view_$appWidgetId", null) } ?: views.firstOrNull()
        val hidden = (prefs.getString("pending_done", "") ?: "").split(',').filter { it.isNotEmpty() }.toSet()
        val tasks = view?.tasks?.filter { it.id !in hidden } ?: emptyList()
        val viewId = view?.id ?: "my_day"

        Column(
            modifier = GlanceModifier.fillMaxSize().background(background).cornerRadius(20.dp).padding(8.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth().padding(start = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Titel mit Anzahl; Tippen öffnet die Auswahl der Ansicht.
                Row(
                    modifier = GlanceModifier.defaultWeight().clickable(
                        actionStartActivity(
                            Intent(context, ViewPickerActivity::class.java)
                                // Eigene Daten pro Widget, sonst teilen sich alle Widgets denselben Aufruf.
                                .setData(Uri.parse("thask://pick?widget=$appWidgetId"))
                                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                        ),
                    ),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = view?.title ?: "tHAsk",
                        style = TextStyle(color = accent, fontWeight = FontWeight.Bold, fontSize = 16.sp),
                        maxLines = 1,
                    )
                    // Gerade abgehakte zählen nicht mehr mit.
                    val open = (view?.count ?: 0) - ((view?.tasks?.size ?: 0) - tasks.size)
                    if (open > 0) {
                        Text(
                            text = open.toString(),
                            style = TextStyle(color = textSecondary, fontSize = 13.sp),
                            modifier = GlanceModifier.padding(start = 4.dp),
                        )
                    }
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_expand),
                        contentDescription = context.getString(R.string.widget_pick_view),
                        colorFilter = ColorFilter.tint(accent),
                        modifier = GlanceModifier.size(20.dp),
                    )
                }
                // tHAsk in der Ansicht öffnen, die das Widget zeigt.
                Box(
                    modifier = GlanceModifier.size(40.dp).clickable(
                        actionStartActivity<MainActivity>(context, Uri.parse("thask://open?view=$viewId")),
                    ),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_open),
                        contentDescription = context.getString(R.string.widget_open),
                        colorFilter = ColorFilter.tint(textSecondary),
                        modifier = GlanceModifier.size(20.dp),
                    )
                }
                Box(
                    modifier = GlanceModifier.size(40.dp).clickable(actionRunCallback<RefreshCallback>()),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_refresh),
                        contentDescription = context.getString(R.string.widget_refresh),
                        colorFilter = ColorFilter.tint(textSecondary),
                        modifier = GlanceModifier.size(20.dp),
                    )
                }
                Box(
                    modifier = GlanceModifier.size(36.dp).cornerRadius(18.dp).background(accent).clickable(
                        actionStartActivity<MainActivity>(context, Uri.parse("thask://add?view=$viewId")),
                    ),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_add),
                        contentDescription = context.getString(R.string.widget_add),
                        colorFilter = ColorFilter.tint(onAccent),
                        modifier = GlanceModifier.size(22.dp),
                    )
                }
            }
            if (views.isEmpty()) {
                Text(
                    text = context.getString(R.string.widget_sign_in),
                    style = TextStyle(color = textSecondary, fontSize = 14.sp),
                    modifier = GlanceModifier.padding(12.dp).clickable(
                        actionStartActivity<MainActivity>(context, Uri.parse("thask://open")),
                    ),
                )
            } else if (tasks.isEmpty()) {
                Text(
                    text = context.getString(R.string.widget_empty),
                    style = TextStyle(color = textSecondary, fontSize = 14.sp),
                    modifier = GlanceModifier.padding(12.dp),
                )
            } else {
                LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
                    items(tasks, itemId = { it.id.hashCode().toLong() }) { task ->
                        TaskRow(context, task, viewId)
                    }
                }
            }
        }
    }

    @Composable
    private fun TaskRow(context: Context, task: WidgetTask, viewId: String) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CheckBox(
                checked = false,
                onCheckedChange = actionRunCallback<CompleteCallback>(actionParametersOf(TaskIdKey to task.id)),
                colors = CheckboxDefaults.colors(checkedColor = accent, uncheckedColor = textSecondary),
            )
            Column(
                modifier = GlanceModifier.defaultWeight().clickable(
                    actionStartActivity<MainActivity>(context, Uri.parse("thask://open?view=$viewId")),
                ),
            ) {
                // Vorschauen wie in der App zurückgenommen: kursiv und grau.
                Text(
                    text = task.title,
                    style = if (task.preview) {
                        TextStyle(color = textSecondary, fontSize = 14.sp, fontStyle = FontStyle.Italic)
                    } else {
                        TextStyle(color = textPrimary, fontSize = 14.sp)
                    },
                    maxLines = 2,
                )
                if (task.due != null) DueChip(task, task.due)
            }
            if (task.priority > 0) {
                // Ein bis drei Ausrufezeichen: die Stufe hängt nicht nur an der Farbe.
                Spacer(modifier = GlanceModifier.width(4.dp))
                Text(
                    text = "!".repeat(task.priority.coerceAtMost(3)),
                    style = TextStyle(
                        color = when (task.priority) {
                            1 -> priorityLow
                            2 -> priorityMedium
                            else -> priorityHigh
                        },
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                    ),
                )
            }
        }
    }
}

/**
 * Fälligkeit als Pille wie in der App: rot überfällig, blau bis heute, sonst grau. Zeiträume laufen rechts aus
 * (Verlauf im Hintergrundbild), ein fester Tag nicht.
 */
@Composable
private fun DueChip(task: WidgetTask, due: String) {
    val (chip, color) = when {
        task.overdue ->
            (if (task.fuzzy) R.drawable.widget_chip_overdue_fuzzy else R.drawable.widget_chip_overdue) to danger
        task.today ->
            (if (task.fuzzy) R.drawable.widget_chip_today_fuzzy else R.drawable.widget_chip_today) to chipTodayText
        else ->
            (if (task.fuzzy) R.drawable.widget_chip_neutral_fuzzy else R.drawable.widget_chip_neutral) to chipText
    }
    // Glance kennt keinen Außenabstand: die Box hält den Chip vom Titel fern.
    Box(modifier = GlanceModifier.padding(top = 2.dp)) {
        Text(
            text = due,
            style = TextStyle(color = color, fontSize = 12.sp, fontWeight = FontWeight.Medium),
            modifier = GlanceModifier.background(ImageProvider(chip))
                .padding(start = 8.dp, end = if (task.fuzzy) 18.dp else 8.dp, top = 1.dp, bottom = 1.dp),
        )
    }
}

/** Haken setzen: Aufgabe sofort ausblenden, die App-Logik erledigt sie im Hintergrund in Home Assistant. */
class CompleteCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val taskId = parameters[TaskIdKey] ?: return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = (prefs.getString("pending_done", "") ?: "").split(',').filter { it.isNotEmpty() } + taskId
        prefs.edit().putString("pending_done", pending.joinToString(",")).apply()
        ThaskWidget().update(context, glanceId)
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("thask://complete?id=${Uri.encode(taskId)}")).send()
    }
}

/** Aktuelle Daten von Home Assistant holen lassen. */
class RefreshCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("thask://refresh")).send()
    }
}
