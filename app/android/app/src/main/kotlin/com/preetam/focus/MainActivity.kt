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
        val day = JSONObject(ScrollStore.todayJson(this))
        val out = JSONArray()
        for (pkg in day.keys()) {
            val o = day.getJSONObject(pkg)
            val label = try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
            } catch (e: Exception) { pkg }
            out.put(JSONObject().put("pkg", pkg).put("name", label)
                .put("n", o.optInt("n")).put("px", o.optLong("px"))
                .put("limited", pkg in ScrollStore.limited))
        }
        return out.toString()
    }
}
