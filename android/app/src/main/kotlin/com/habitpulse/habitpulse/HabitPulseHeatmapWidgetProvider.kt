package com.habitpulse.habitpulse

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Heatmap widget: the card is rendered by Flutter and shown as an image.
class HabitPulseHeatmapWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val imagePath = widgetData.getString("heatmap_image", null)
        val habitId = widgetData.getString("heatmap_habit_id", null)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(
                context.packageName,
                R.layout.habitpulse_heatmap_widget,
            )

            val bitmap = imagePath?.let { BitmapFactory.decodeFile(it) }
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.heatmap_image, bitmap)
                views.setViewVisibility(R.id.heatmap_image, View.VISIBLE)
                views.setViewVisibility(R.id.heatmap_empty, View.GONE)
            } else {
                views.setViewVisibility(R.id.heatmap_image, View.GONE)
                views.setViewVisibility(R.id.heatmap_empty, View.VISIBLE)
            }

            val uri = Uri.parse(
                "habitpulse://habit?habitId=" + (habitId ?: ""),
            )
            views.setOnClickPendingIntent(
                R.id.heatmap_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    uri,
                ),
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
