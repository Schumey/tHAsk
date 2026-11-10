package de.schumey.thask

import android.content.Context
import android.net.Uri
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.util.concurrent.TimeUnit

/**
 * Holt alle 15 Minuten (dem Minimum von Android) frische Daten, auch wenn das Widget nicht angetippt wird.
 * Das ist kein Push: Änderungen von anderen Geräten erscheinen mit bis zu 15 Minuten Verzögerung. Die App
 * selbst verbindet sich dafür kurz im Hintergrund (derselbe Weg wie beim Aktualisieren-Knopf).
 */
class WidgetRefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        // Merken wie der Knopf, damit das Schreiben der Daten (löst onUpdate aus) nicht sofort noch einen Lauf startet.
        applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putLong("last_refresh", System.currentTimeMillis()).apply()
        HomeWidgetBackgroundIntent.getBroadcast(applicationContext, Uri.parse("thask://refresh")).send()
        return Result.success()
    }

    companion object {
        private const val NAME = "thask_widget_refresh"

        /** Idempotent: ein schon geplanter Lauf bleibt bestehen. */
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(NAME)
        }
    }
}
