package com.example.unified_calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.view.View

/**
 * Widget Android — Liste des 7 prochains RDV.
 * Les données sont fournies par home_widget via SharedPreferences.
 */
class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val MAX_EVENTS = 7

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )

            val views = RemoteViews(context.packageName, R.layout.calendar_widget)

            // Intent pour ouvrir l'appli au tap
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_events_container, pendingIntent)

            // Lire les 7 événements individuels
            val eventCount = prefs.getLong("flutter.event_count", 0).toInt()

            val titleIds = arrayOf(
                R.id.event_0_title, R.id.event_1_title, R.id.event_2_title,
                R.id.event_3_title, R.id.event_4_title, R.id.event_5_title,
                R.id.event_6_title
            )
            val timeIds = arrayOf(
                R.id.event_0_time, R.id.event_1_time, R.id.event_2_time,
                R.id.event_3_time, R.id.event_4_time, R.id.event_5_time,
                R.id.event_6_time
            )

            for (i in 0 until MAX_EVENTS) {
                val title = prefs.getString("flutter.event_${i}_title", "") ?: ""
                val time = prefs.getString("flutter.event_${i}_time", "") ?: ""

                if (i < titleIds.size && i < timeIds.size) {
                    if (title.isNotEmpty()) {
                        views.setTextViewText(titleIds[i], title)
                        views.setTextViewText(timeIds[i], time)
                        views.setViewVisibility(titleIds[i], View.VISIBLE)
                        views.setViewVisibility(timeIds[i], View.VISIBLE)
                    } else {
                        views.setViewVisibility(titleIds[i], View.GONE)
                        views.setViewVisibility(timeIds[i], View.GONE)
                    }
                }
            }

            if (eventCount == 0) {
                views.setTextViewText(titleIds[0], "Aucun événement à venir")
                views.setViewVisibility(titleIds[0], View.VISIBLE)
                views.setViewVisibility(timeIds[0], View.GONE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
