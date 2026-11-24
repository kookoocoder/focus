package com.preetam.focus

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Screen time per app from Android's usage events, the same source Digital
 * Wellbeing reads. Needs the "Usage access" special permission.
 */
object Usage {
    private fun midnight(daysAgo: Int): Long = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, -daysAgo)
    }.timeInMillis

    private class Day {
        val ms = HashMap<String, Long>()
        val opens = HashMap<String, Int>()
        var unlocks = 0
    }

    private fun day(usm: UsageStatsManager, start: Long, end: Long, ignore: Set<String>): Day {
        val d = Day()
        val open = HashMap<String, Long>()
        var front: String? = null
        val ev = UsageEvents.Event()
        val events = usm.queryEvents(start, end)
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName
            when (ev.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (pkg in ignore) continue
                    open.putIfAbsent(pkg, ev.timeStamp)
                    if (front != pkg) d.opens[pkg] = (d.opens[pkg] ?: 0) + 1
                    front = pkg
                }
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                    open.remove(pkg)?.let { d.ms[pkg] = (d.ms[pkg] ?: 0) + (ev.timeStamp - it) }
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    for ((p, t) in open) d.ms[p] = (d.ms[p] ?: 0) + (ev.timeStamp - t)
                    open.clear()
                    front = null
                }
                UsageEvents.Event.KEYGUARD_HIDDEN -> d.unlocks++
            }
        }
        val stop = minOf(end, System.currentTimeMillis())
        for ((p, t) in open) d.ms[p] = (d.ms[p] ?: 0) + (stop - t)
        return d
    }

    /** JSON: `{days:[{date, secs, unlocks}], apps:[{pkg, name, category, today, week, opens}]}`. */
    fun report(c: Context, days: Int): String {
        val usm = c.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = c.packageManager
        val launchers = pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            .map { it.activityInfo.packageName }.toSet()
        val ignore = launchers + setOf("com.android.systemui", "android")
        val perDay = (0 until days).map { i -> day(usm, midnight(i), midnight(i - 1), ignore) }

        val week = HashMap<String, Long>()
        for (d in perDay) for ((p, ms) in d.ms) week[p] = (week[p] ?: 0) + ms
        val apps = JSONArray()
        for ((pkg, ms) in week.entries.sortedByDescending { it.value }) {
            if (ms < 60_000) continue
            val info = runCatching { pm.getApplicationInfo(pkg, 0) }.getOrNull()
            apps.put(JSONObject()
                .put("pkg", pkg)
                .put("name", info?.let { pm.getApplicationLabel(it).toString() } ?: pkg)
                .put("category", if (info != null && android.os.Build.VERSION.SDK_INT >= 26) info.category else -1)
                .put("today", (perDay[0].ms[pkg] ?: 0) / 1000)
                .put("week", ms / 1000)
                .put("opens", perDay[0].opens[pkg] ?: 0))
        }
        val dayList = JSONArray()
        for ((i, d) in perDay.withIndex()) {
            dayList.put(JSONObject()
                .put("date", java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(midnight(i)))
                .put("secs", d.ms.values.sum() / 1000)
                .put("unlocks", d.unlocks))
        }
        return JSONObject().put("days", dayList).put("apps", apps).toString()
    }
}
