package de.schumey.thask

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Bundle
import androidx.glance.appwidget.GlanceAppWidgetManager
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch

/** Tippen auf den Titel des Widgets: Liste der Ansichten zur Auswahl (gemerkt pro Widget). */
class ViewPickerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val views = parseViews(prefs.getString("views", null))
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID || views.isEmpty()) {
            finish()
            return
        }
        val current = views.indexOfFirst { it.id == prefs.getString("view_$appWidgetId", null) }.coerceAtLeast(0)
        val labels = views.map { if (it.count > 0) "${it.title} (${it.count})" else it.title }.toTypedArray()
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle(getString(R.string.widget_view))
            .setSingleChoiceItems(labels, current) { dialog, which ->
                prefs.edit().putString("view_$appWidgetId", views[which].id).apply()
                dialog.dismiss()
                MainScope().launch {
                    val glanceId = GlanceAppWidgetManager(applicationContext).getGlanceIdBy(appWidgetId)
                    ThaskWidget().update(applicationContext, glanceId)
                }
            }
            .setOnDismissListener { finish() }
            .show()
    }
}
