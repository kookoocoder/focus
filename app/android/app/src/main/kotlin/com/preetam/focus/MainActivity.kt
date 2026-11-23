package com.preetam.focus

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus/scroll")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(isServiceEnabled())
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "getLimit" -> result.success(ScrollStore.limit(this))
                    "setLimit" -> {
                        ScrollStore.setLimit(this, call.argument<Int>("limit") ?: 0)
                        result.success(null)
                    }
                    "getTimeLimit" -> result.success(ScrollStore.timeLimit(this))
                    "setTimeLimit" -> {
                        ScrollStore.setTimeLimit(this, call.argument<Int>("minutes") ?: 0)
                        result.success(null)
                    }
                    "getLock" -> result.success(ScrollStore.lockEnabled(this))
                    "setLock" -> {
                        ScrollStore.setLock(this, call.argument<Boolean>("on") ?: true)
                        result.success(null)
                    }
                    "lecture" -> result.success(
                        ScrollStore.currentLecture(this, System.currentTimeMillis())?.toString())
                    "history" -> result.success(
                        JSONObject().put("since", ScrollStore.since(this))
                            .put("days", JSONArray(ScrollStore.history(this, 30))).toString())
                    "last" -> result.success(ScrollStore.last(this)?.let {
                        val (pkg, t) = it.split("|")
                        val label = try {
                            packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
                        } catch (e: Exception) { pkg }
                        "$label ($pkg) ${(System.currentTimeMillis() - t.toLong()) / 1000}s ago"
                    })
                    "stats" -> result.success(stats())
                    else -> result.notImplemented()
                }
            }
    }

    private fun isServiceEnabled(): Boolean {
        val id = ComponentName(this, ScrollService::class.java).flattenToString()
        val s = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return s?.split(':')?.any { it.equals(id, true) } == true
    }

    private fun stats(): String {
        val day = JSONObject(ScrollStore.dayJson(this, ScrollStore.today()).toString())
        val out = JSONArray()
        val secs = ScrollStore.secsByPkg(this, ScrollStore.today())
        for (pkg in day.keys()) {
            val o = day.getJSONObject(pkg)
            val label = try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
            } catch (e: Exception) { pkg }
            out.put(JSONObject().put("pkg", pkg).put("name", label)
                .put("n", o.optInt("n")).put("px", o.optLong("px"))
                .put("secs", secs[pkg] ?: 0L)
                .put("limited", pkg in ScrollStore.limited))
        }
        return out.toString()
    }
}
