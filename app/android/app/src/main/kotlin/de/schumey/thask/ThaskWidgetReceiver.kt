package de.schumey.thask

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ThaskWidgetReceiver : HomeWidgetGlanceWidgetReceiver<ThaskWidget>() {
    override val glanceAppWidget = ThaskWidget()

    /**
     * Das System ruft dies regelmäßig (alle 30 Minuten) und beim Hinzufügen auf. Dann lassen wir die App im
     * Hintergrund frische Daten holen. Die Wartezeit verhindert eine Schleife: Das Schreiben der neuen Daten löst
     * selbst wieder ein Update aus.
     */
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        if (now - prefs.getLong("last_refresh", 0L) < REFRESH_INTERVAL_MS) return
        prefs.edit().putLong("last_refresh", now).apply()
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("thask://refresh")).send()
    }

    private companion object {
        const val REFRESH_INTERVAL_MS = 10 * 60 * 1000L
    }
}
