package com.preetam.focus

import android.app.AppOpsManager
import android.content.ComponentName
import android.os.Process
import io.flutter.plugin.common.EventChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
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
                        openAccessibility()
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
        app = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus/app").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> result.success(version())
                    "install" -> result.success(install(call.argument<String>("path")!!))
                    "launchAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    "usageAccess" -> result.success(usageAccess())
                    "openUsageAccess" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "usage" -> result.success(Usage.report(this@MainActivity, call.argument<Int>("days") ?: 7))
                    "bubbleState" -> result.success(mapOf(
                        "on" to AssistantBubble.isOn(this@MainActivity),
                        "canDraw" to AssistantBubble.canDraw(this@MainActivity)))
                    "setBubble" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        when {
                            !on -> AssistantBubble.stop(this@MainActivity)
                            AssistantBubble.canDraw(this@MainActivity) -> AssistantBubble.start(this@MainActivity)
                            else -> startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")))
                        }
                        result.success(AssistantBubble.isOn(this@MainActivity) && AssistantBubble.canDraw(this@MainActivity))
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus/tts")
            .setMethodCallHandler { call, result ->
                val dir = call.argument<String>("dir") ?: ""
                when (call.method) {
                    "ready" -> result.success(PhononSpeaker.modelReady(dir))
                    "warm" -> { PhononSpeaker.warm(dir); result.success(null) }
                    "speak" -> result.success(PhononSpeaker.speak(dir, call.argument<String>("text") ?: ""))
                    "stop" -> { PhononSpeaker.stop(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "focus/tts/events")
            .setStreamHandler(PhononSpeaker)
    }

    private var app: MethodChannel? = null
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == AssistantBubble.ACTION_OPEN) pendingAction = "assistant"
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == AssistantBubble.ACTION_OPEN) app?.invokeMethod("openAssistant", null)
    }

    private fun usageAccess(): Boolean {
        val ops = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29)
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        else @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /// Opens Accessibility settings scrolled to (and on most OEMs highlighting)
    /// our service; Android 11 skins often bury it under "Downloaded apps".
    private fun openAccessibility() {
        val id = ComponentName(this, ScrollService::class.java).flattenToString()
        val args = Bundle().apply { putString(":settings:fragment_args_key", id) }
        val details = Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS")
            .putExtra(Intent.EXTRA_COMPONENT_NAME, id)
        val list = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            .putExtra(":settings:fragment_args_key", id)
            .putExtra(":settings:show_fragment_args", args)
        try {
            startActivity(if (Build.VERSION.SDK_INT >= 33) details else list)
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
    }

    private fun version(): Map<String, Any> {
        val p = packageManager.getPackageInfo(packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong()
        return mapOf("name" to (p.versionName ?: ""), "code" to code)
    }

    /// "permission" when the user still has to allow installs from this app
    /// (the settings screen is opened for them), else "started".
    private fun install(path: String): String {
        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            return "permission"
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
        startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
        return "started"
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
