package com.preetam.focus

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Local per-day, per-app counters, sessions, limits and lecture lock. */
object ScrollStore {
    private const val PREFS = "scroll_prefs"
    const val SESSION_GAP_MS = 60_000L

    /** Apps the limits and the lecture lock apply to (feeds / short video). */
    val limited = setOf(
        "com.google.android.youtube", "com.instagram.android", "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill", "com.facebook.katana", "com.twitter.android",
        "com.snapchat.android", "com.reddit.frontpage", "com.linkedin.android",
        "com.pinterest", "com.instagram.barcelona", "in.mohalla.sharechat",
        "com.next.innovation.takatak",
    )

    private val fmt get() = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    fun today(): String = fmt.format(Date())
    fun dayOffset(n: Int): String {
        val c = Calendar.getInstance(); c.add(Calendar.DAY_OF_YEAR, -n)
        return fmt.format(c.time)
    }
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---- settings ----
    fun limit(c: Context) = prefs(c).getInt("limit", 0)           // swipes / day
    fun timeLimit(c: Context) = prefs(c).getInt("tlimit", 0)      // minutes / day
    fun lockEnabled(c: Context) = prefs(c).getBoolean("lock", true)
    fun setLimit(c: Context, v: Int) = prefs(c).edit().putInt("limit", v).apply()
    fun setTimeLimit(c: Context, v: Int) = prefs(c).edit().putInt("tlimit", v).apply()
    fun setLock(c: Context, v: Boolean) = prefs(c).edit().putBoolean("lock", v).apply()

    fun markStarted(c: Context) {
        if (!prefs(c).contains("since")) prefs(c).edit().putString("since", today()).apply()
    }
    fun since(c: Context): String = prefs(c).getString("since", today())!!

    fun setLast(c: Context, pkg: String, now: Long) =
        prefs(c).edit().putString("last", "$pkg|$now").apply()
    fun last(c: Context): String? = prefs(c).getString("last", null)

    // ---- recording ----
    @Synchronized
    fun add(c: Context, pkg: String, swipes: Int, px: Long, now: Long) {
        val p = prefs(c)
        val k = "day_" + today()
        val day = JSONObject(p.getString(k, "{}")!!)
        val o = day.optJSONObject(pkg) ?: JSONObject()
        o.put("n", o.optInt("n") + swipes)
        o.put("px", o.optLong("px") + px)
        day.put(pkg, o)

        // Sessions: bursts of activity in one app, split by 60s of inactivity.
        val sk = "sess_" + today()
        val arr = JSONArray(p.getString(sk, "[]")!!)
        val last = if (arr.length() > 0) arr.getJSONObject(arr.length() - 1) else null
        if (last != null && last.getString("pkg") == pkg && now - last.getLong("end") <= SESSION_GAP_MS) {
            last.put("end", now).put("n", last.getInt("n") + swipes)
        } else {
            arr.put(JSONObject().put("pkg", pkg).put("start", now).put("end", now).put("n", swipes))
        }
        p.edit().putString(k, day.toString()).putString(sk, arr.toString()).apply()
    }

    @Synchronized
    fun countBlock(c: Context, kind: String) {
        val k = "blk_" + kind + "_" + today()
        prefs(c).edit().putInt(k, prefs(c).getInt(k, 0) + 1).apply()
    }

    // ---- queries ----
    fun dayJson(c: Context, d: String) = JSONObject(prefs(c).getString("day_$d", "{}")!!)
    private fun sessions(c: Context, d: String) = JSONArray(prefs(c).getString("sess_$d", "[]")!!)

    fun limitedSwipes(c: Context, d: String = today()): Int {
        val day = dayJson(c, d); var t = 0
        for (k in day.keys()) if (k in limited) t += day.getJSONObject(k).optInt("n")
        return t
    }

    fun secsByPkg(c: Context, d: String): Map<String, Long> {
        val m = HashMap<String, Long>(); val a = sessions(c, d)
        for (i in 0 until a.length()) {
            val s = a.getJSONObject(i)
            m[s.getString("pkg")] = (m[s.getString("pkg")] ?: 0L) + (s.getLong("end") - s.getLong("start")) / 1000
        }
        return m
    }

    fun limitedSecs(c: Context, d: String = today()) =
        secsByPkg(c, d).filterKeys { it in limited }.values.sum()

    fun overLimit(c: Context): Boolean {
        val l = limit(c); val t = timeLimit(c)
        return (l > 0 && limitedSwipes(c) >= l) || (t > 0 && limitedSecs(c) >= t * 60L)
    }

    /** Current/next lecture from the PW schedule saved by the Flutter side. */
    fun currentLecture(c: Context, now: Long): JSONObject? {
        val raw = c.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.pwCourse", null) ?: return null
        val sched = try { JSONObject(raw).optJSONArray("schedule") } catch (e: Exception) { null } ?: return null
        val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        for (i in 0 until sched.length()) {
            val l = sched.getJSONObject(i)
            try {
                val s = f.parse(l.getString("start").take(19))!!.time
                val e = f.parse(l.getString("end").take(19))!!.time
                if (now in s until e) return JSONObject().put("topic", l.optString("topic"))
                    .put("subject", l.optString("subject")).put("end", e)
            } catch (ex: Exception) { }
        }
        return null
    }

    fun history(c: Context, days: Int): String {
        val out = JSONArray()
        for (i in 0 until days) {
            val d = dayOffset(i)
            val day = dayJson(c, d); var n = 0
            for (k in day.keys()) n += day.getJSONObject(k).optInt("n")
            out.put(JSONObject().put("date", d).put("swipes", n)
                .put("limitedSwipes", limitedSwipes(c, d))
                .put("limitedSecs", limitedSecs(c, d))
                .put("sessions", sessions(c, d).length())
                .put("lectureBlocks", prefs(c).getInt("blk_lecture_$d", 0))
                .put("limitBlocks", prefs(c).getInt("blk_limit_$d", 0)))
        }
        return out.toString()
    }
}
