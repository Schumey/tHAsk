package de.schumey.thask

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.LocalGlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import org.json.JSONObject

private val background = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF1C1B1F))
private val textPrimary = ColorProvider(day = Color(0xFF1C1B1F), night = Color(0xFFE6E1E5))
private val textSecondary = ColorProvider(day = Color(0xFF605D66), night = Color(0xFFC9C5CA))
private val accent = ColorProvider(day = Color(0xFF3F51B5), night = Color(0xFFB8C4FF))
private val danger = ColorProvider(day = Color(0xFFB3261E), night = Color(0xFFF2B8B5))
private val star = ColorProvider(day = Color(0xFFF9A825), night = Color(0xFFFFCA28))

private const val PREFS = "HomeWidgetPreferences"

internal val TaskIdKey = ActionParameters.Key<String>("task_id")

internal class WidgetTask(
    val id: String,
    val title: String,
    val due: String?,
    val overdue: Boolean,
    val important: Boolean,
)

internal class WidgetView(val id: String, val title: String, val tasks: List<WidgetTask>)

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
                        task.optBoolean("important"),
                    )
                },
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
                modifier = GlanceModifier.fillMaxWidth().padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = (view?.title ?: "tHAsk") + "  ▾",
                    style = TextStyle(color = accent, fontWeight = FontWeight.Bold, fontSize = 16.sp),
                    modifier = GlanceModifier.defaultWeight().clickable(actionRunCallback<CycleViewCallback>()),
                )
                Text(
                    text = "↻",
                    style = TextStyle(color = textSecondary, fontSize = 20.sp),
                    modifier = GlanceModifier.padding(horizontal = 10.dp)
                        .clickable(actionRunCallback<RefreshCallback>()),
                )
                Text(
                    text = "+",
                    style = TextStyle(color = accent, fontWeight = FontWeight.Bold, fontSize = 24.sp),
                    modifier = GlanceModifier.padding(horizontal = 8.dp).clickable(
                        actionStartActivity<MainActivity>(context, Uri.parse("thask://add?view=$viewId")),
                    ),
                )
            }
            if (views.isEmpty()) {
                Text(
                    text = "tHAsk öffnen und anmelden",
                    style = TextStyle(color = textSecondary, fontSize = 14.sp),
                    modifier = GlanceModifier.padding(12.dp).clickable(
                        actionStartActivity<MainActivity>(context, Uri.parse("thask://open")),
                    ),
                )
            } else if (tasks.isEmpty()) {
                Text(
                    text = "Keine Aufgaben",
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
            )
            Column(
                modifier = GlanceModifier.defaultWeight().clickable(
                    actionStartActivity<MainActivity>(context, Uri.parse("thask://open?view=$viewId")),
                ),
            ) {
                Text(text = task.title, style = TextStyle(color = textPrimary, fontSize = 14.sp), maxLines = 2)
                if (task.due != null) {
                    Text(
                        text = task.due,
                        style = TextStyle(color = if (task.overdue) danger else textSecondary, fontSize = 12.sp),
                    )
                }
            }
            if (task.important) {
                Spacer(modifier = GlanceModifier.width(4.dp))
                Text(text = "★", style = TextStyle(color = star, fontSize = 16.sp))
            }
        }
    }
}

/** Tippen auf den Titel wechselt zur nächsten Ansicht (gemerkt pro Widget). */
class CycleViewCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
        val views = parseViews(prefs.getString("views", null))
        if (views.isEmpty()) return
        val current = views.indexOfFirst { it.id == prefs.getString("view_$appWidgetId", null) }.coerceAtLeast(0)
        prefs.edit().putString("view_$appWidgetId", views[(current + 1) % views.size].id).apply()
        ThaskWidget().update(context, glanceId)
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
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("thask://complete?id=$taskId")).send()
    }
}

/** Aktuelle Daten von Home Assistant holen lassen. */
class RefreshCallback : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("thask://refresh")).send()
    }
}
