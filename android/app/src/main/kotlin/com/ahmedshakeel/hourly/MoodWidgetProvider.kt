package com.ahmedshakeel.hourly

import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.widget.RemoteViews
import java.util.Calendar

/// Home-screen widget showing an ASCII face that shifts happy -> annoyed based
/// on today's screen time. Computes usage natively from [UsageStatsManager] so
/// it stays fresh even when the Flutter app isn't running.
class MoodWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        /** Refresh every placed instance — called from [onUpdate] and the app. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MoodWidgetProvider::class.java)
            )
            for (id in ids) updateWidget(context, manager, id)
        }

        private fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.mood_widget)

            if (hasUsageAccess(context)) {
                val millis = todayScreenTimeMillis(context)
                val mood = moodFor(millis)
                views.setTextViewText(R.id.widget_face, mood.face)
                views.setTextViewText(R.id.widget_time, formatDurationMs(millis))
                views.setTextViewText(R.id.widget_label, mood.label)
            } else {
                views.setTextViewText(R.id.widget_face, Mood.SETUP.face)
                views.setTextViewText(R.id.widget_time, "—")
                views.setTextViewText(R.id.widget_label, Mood.SETUP.label)
            }

            views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
            manager.updateAppWidget(widgetId, views)
        }

        /** Tapping the widget opens the app. */
        private fun launchAppIntent(context: Context): PendingIntent? {
            val launch = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
            return PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        /** Whether the "Usage access" special permission is granted. */
        private fun hasUsageAccess(context: Context): Boolean {
            return try {
                val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOps.unsafeCheckOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        context.packageName,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        context.packageName,
                    )
                }
                mode == AppOpsManager.MODE_ALLOWED
            } catch (_: Exception) {
                false
            }
        }

        private fun todayScreenTimeMillis(context: Context): Long {
            val usm =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val startOfDay = startOfDayMillis(now)
            // Look back so a session already in progress at midnight is captured;
            // it's clipped to [startOfDay, now] inside dailyForegroundMillis.
            val queryStart = startOfDay - 12 * 3_600_000L

            val events = usm.queryEvents(queryStart, now)
            val list = ArrayList<UsageEvent>()
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                list.add(UsageEvent(event.eventType, event.timeStamp, event.packageName))
            }
            return dailyForegroundMillis(list, startOfDay, now)
        }

        private fun startOfDayMillis(now: Long): Long {
            val cal = Calendar.getInstance()
            cal.timeInMillis = now
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.timeInMillis
        }
    }
}
