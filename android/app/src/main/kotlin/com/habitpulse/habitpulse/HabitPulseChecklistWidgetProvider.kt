package com.habitpulse.habitpulse

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/// "Today" checklist widget: one tappable row per due habit.
class HabitPulseChecklistWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val raw = widgetData.getString("checklist_json", null)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.habitpulse_checklist_widget)
            views.setOnClickPendingIntent(
                R.id.checklist_header,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("habitpulse://today"),
                ),
            )

            if (raw == null) {
                views.setTextViewText(R.id.checklist_subtitle, "Open HabitPulse")
                views.addView(
                    R.id.checklist_rows,
                    emptyRow(context, "No habits yet"),
                )
            } else {
                val json = JSONObject(raw)
                val total = json.optInt("total")
                val done = json.optInt("done")
                val date = json.optString("date")

                views.setTextViewText(
                    R.id.checklist_subtitle,
                    "$done of $total done",
                )

                val habits = json.optJSONArray("habits")
                if (habits == null || habits.length() == 0) {
                    views.addView(
                        R.id.checklist_rows,
                        emptyRow(context, "Nothing due today"),
                    )
                } else {
                    for (index in 0 until habits.length()) {
                        val habit = habits.getJSONObject(index)
                        val row = RemoteViews(
                            context.packageName,
                            R.layout.habitpulse_checklist_row,
                        )
                        row.setTextViewText(
                            R.id.row_name,
                            habit.optString("name"),
                        )
                        row.setImageViewResource(
                            R.id.row_check,
                            if (habit.optBoolean("done")) {
                                R.drawable.ic_widget_check
                            } else {
                                R.drawable.ic_widget_circle
                            },
                        )
                        val uri = Uri.parse(
                            "habitpulse://toggle?habitId=" +
                                habit.optString("id") +
                                "&date=" + date,
                        )
                        row.setOnClickPendingIntent(
                            R.id.row_root,
                            HomeWidgetBackgroundIntent.getBroadcast(context, uri),
                        )
                        views.addView(R.id.checklist_rows, row)
                    }

                    val more = json.optInt("more")
                    if (more > 0) {
                        views.addView(
                            R.id.checklist_rows,
                            emptyRow(context, "+$more more"),
                        )
                    }
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun emptyRow(context: Context, text: String): RemoteViews {
        val row = RemoteViews(
            context.packageName,
            R.layout.habitpulse_checklist_empty,
        )
        row.setTextViewText(R.id.empty_text, text)
        return row
    }
}
