package com.islamicapp.app.islamic_app_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

class PrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                    val rawCity = widgetData.getString("widget_city", "هەولێر") ?: "هەولێر"
                    val city = if (rawCity.startsWith("📍")) rawCity.removePrefix("📍").trim() else rawCity
                    val appTitle = widgetData.getString("widget_app_title", "✨ کاتەکانی بانگ") ?: "✨ کاتەکانی بانگ"

                    val fajr = widgetData.getString("widget_fajr", "--:--") ?: "--:--"
                    val dhuhr = widgetData.getString("widget_dhuhr", "--:--") ?: "--:--"
                    val asr = widgetData.getString("widget_asr", "--:--") ?: "--:--"
                    val maghrib = widgetData.getString("widget_maghrib", "--:--") ?: "--:--"
                    val isha = widgetData.getString("widget_isha", "--:--") ?: "--:--"

                    val fajrName = widgetData.getString("widget_fajr_name", "🌅 بەیانی") ?: "🌅 بەیانی"
                    val dhuhrName = widgetData.getString("widget_dhuhr_name", "🌤️ نیوەڕۆ") ?: "🌤️ نیوەڕۆ"
                    val asrName = widgetData.getString("widget_asr_name", "🌥️ عەسر") ?: "🌥️ عەسر"
                    val maghribName = widgetData.getString("widget_maghrib_name", "🌆 مەغریب") ?: "🌆 مەغریب"
                    val ishaName = widgetData.getString("widget_isha_name", "🌙 عیشا") ?: "🌙 عیشا"

                    // Dynamic real-time calculation of Next Prayer and Remaining time
                    val prayerList = listOf(
                        Triple("Fajr", fajrName, fajr),
                        Triple("Dhuhr", dhuhrName, dhuhr),
                        Triple("Asr", asrName, asr),
                        Triple("Maghrib", maghribName, maghrib),
                        Triple("Isha", ishaName, isha)
                    )

                    val now = Calendar.getInstance()
                    val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

                    var nextKey = ""
                    var nextDisplayName = ""
                    var nextPrayerTime = ""
                    var diffMinutes = -1

                    for (item in prayerList) {
                        val m = parseMinutes(item.third)
                        if (m != null && m > currentMinutes) {
                            nextKey = item.first
                            nextDisplayName = item.second
                            nextPrayerTime = item.third
                            diffMinutes = m - currentMinutes
                            break
                        }
                    }

                    // If all prayers today have passed, the next prayer is Fajr tomorrow
                    if (diffMinutes == -1 && parseMinutes(fajr) != null) {
                        nextKey = "Fajr"
                        nextDisplayName = "$fajrName (سبەی)"
                        nextPrayerTime = fajr
                        val fm = parseMinutes(fajr)
                        if (fm != null) {
                            diffMinutes = (24 * 60 + fm) - currentMinutes
                        }
                    }

                    // Fallback to widgetData if dynamic parsing was unavailable
                    if (nextKey.isEmpty()) {
                        nextKey = widgetData.getString("widget_next_name", "Fajr") ?: "Fajr"
                    }
                    if (nextPrayerTime.isEmpty() || nextPrayerTime == "--:--") {
                        nextPrayerTime = widgetData.getString("widget_next_time", "--:--") ?: "--:--"
                    }

                    val remainingText = when {
                        diffMinutes in 0..1 -> "کاتی بانگ هاتووە 📢"
                        diffMinutes in 2..59 -> "ماوە $diffMinutes خولەک"
                        diffMinutes >= 60 -> {
                            val hours = diffMinutes / 60
                            val mins = diffMinutes % 60
                            if (mins > 0) "ماوە $hours کاتژمێر و $mins خولەک" else "ماوە $hours کاتژمێر"
                        }
                        else -> widgetData.getString("widget_remaining", "ماوە بۆ بانگ") ?: "ماوە بۆ بانگ"
                    }

                    val nextPrayerHeading = if (nextDisplayName.isNotEmpty()) {
                        "نوێژی داهاتوو: $nextDisplayName"
                    } else {
                        widgetData.getString("widget_next_prayer", "نوێژی داهاتوو") ?: "نوێژی داهاتوو"
                    }

                    setTextViewText(R.id.widget_city, "📍 $city")
                    setTextViewText(R.id.widget_app_title, appTitle)
                    setTextViewText(R.id.widget_next_prayer, nextPrayerHeading)
                    setTextViewText(R.id.widget_next_time, nextPrayerTime)
                    setTextViewText(R.id.widget_remaining, "⏱️ $remainingText")

                    // Fajr
                    val isFajr = nextKey == "Fajr"
                    setTextViewText(R.id.widget_fajr_inactive_title, fajrName)
                    setTextViewText(R.id.widget_fajr_active_title, fajrName)
                    setTextViewText(R.id.widget_fajr_inactive_time, fajr)
                    setTextViewText(R.id.widget_fajr_active_time, fajr)
                    setViewVisibility(R.id.widget_fajr_active_box, if (isFajr) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.widget_fajr_inactive_box, if (isFajr) View.GONE else View.VISIBLE)

                    // Dhuhr
                    val isDhuhr = nextKey == "Dhuhr"
                    setTextViewText(R.id.widget_dhuhr_inactive_title, dhuhrName)
                    setTextViewText(R.id.widget_dhuhr_active_title, dhuhrName)
                    setTextViewText(R.id.widget_dhuhr_inactive_time, dhuhr)
                    setTextViewText(R.id.widget_dhuhr_active_time, dhuhr)
                    setViewVisibility(R.id.widget_dhuhr_active_box, if (isDhuhr) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.widget_dhuhr_inactive_box, if (isDhuhr) View.GONE else View.VISIBLE)

                    // Asr
                    val isAsr = nextKey == "Asr"
                    setTextViewText(R.id.widget_asr_inactive_title, asrName)
                    setTextViewText(R.id.widget_asr_active_title, asrName)
                    setTextViewText(R.id.widget_asr_inactive_time, asr)
                    setTextViewText(R.id.widget_asr_active_time, asr)
                    setViewVisibility(R.id.widget_asr_active_box, if (isAsr) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.widget_asr_inactive_box, if (isAsr) View.GONE else View.VISIBLE)

                    // Maghrib
                    val isMaghrib = nextKey == "Maghrib"
                    setTextViewText(R.id.widget_maghrib_inactive_title, maghribName)
                    setTextViewText(R.id.widget_maghrib_active_title, maghribName)
                    setTextViewText(R.id.widget_maghrib_inactive_time, maghrib)
                    setTextViewText(R.id.widget_maghrib_active_time, maghrib)
                    setViewVisibility(R.id.widget_maghrib_active_box, if (isMaghrib) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.widget_maghrib_inactive_box, if (isMaghrib) View.GONE else View.VISIBLE)

                    // Isha
                    val isIsha = nextKey == "Isha"
                    setTextViewText(R.id.widget_isha_inactive_title, ishaName)
                    setTextViewText(R.id.widget_isha_active_title, ishaName)
                    setTextViewText(R.id.widget_isha_inactive_time, isha)
                    setTextViewText(R.id.widget_isha_active_time, isha)
                    setViewVisibility(R.id.widget_isha_active_box, if (isIsha) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.widget_isha_inactive_box, if (isIsha) View.GONE else View.VISIBLE)

                    // Launch MainActivity when widget is clicked
                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun parseMinutes(timeStr: String): Int? {
        val parts = timeStr.trim().split(":")
        if (parts.size >= 2) {
            val h = parts[0].trim().filter { it.isDigit() }.toIntOrNull()
            val m = parts[1].trim().filter { it.isDigit() }.take(2).toIntOrNull()
            if (h != null && m != null) {
                return h * 60 + m
            }
        }
        return null
    }
}
