package com.preetam.focus

import android.content.Context
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Local per-day, per-app scroll counters and the daily limit. */
object ScrollStore {
    private const val PREFS = "scroll_prefs"
    private const val LIMIT = "limit"

    /** Apps the daily limit applies to (feeds / short video). */
    val limited = setOf(
        "com.google.android.youtube", "com.instagram.android", "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill", "com.facebook.katana", "com.twitter.android",
        "com.snapchat.android", "com.reddit.frontpage", "com.linkedin.android",
        "com.pinterest", "com.instagram.barcelona", "in.mohalla.sharechat",
        "com.next.innovation.takatak",
    )

    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun limit(c: Context) = prefs(c).getInt(LIMIT, 0)
    fun setLimit(c: Context, v: Int) = prefs(c).edit().putInt(LIMIT, v).apply()

    private fun key() = "day_" + today()

    @Synchronized
    fun add(c: Context, pkg: String, swipes: Int, px: Long) {
        val p = prefs(c)
        val day = JSONObject(p.getString(key(), "{}")!!)
        val o = day.optJSONObject(pkg) ?: JSONObject()
        o.put("n", o.optInt("n") + swipes)
        o.put("px", o.optLong("px") + px)
        day.put(pkg, o)
        p.edit().putString(key(), day.toString()).apply()
    }

    fun totalLimited(c: Context): Int {
        val day = JSONObject(prefs(c).getString(key(), "{}")!!)
        var t = 0
        for (k in day.keys()) if (k in limited) t += day.getJSONObject(k).optInt("n")
        return t
    }

    fun todayJson(c: Context): String = prefs(c).getString(key(), "{}")!!
}
