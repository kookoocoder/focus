package com.preetam.focus

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.Shader
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.abs

/**
 * Floating orb drawn over other apps. Tap it to open the Focus assistant from
 * anywhere on the phone; drag it to move it, drop it on the bottom edge to hide it.
 */
class AssistantBubble : Service() {
    companion object {
        const val ACTION_OPEN = "com.preetam.focus.ASSISTANT"
        private const val PREFS = "bubble"

        fun canDraw(c: Context) = Settings.canDrawOverlays(c)

        fun start(c: Context) {
            c.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("on", true).apply()
            c.startForegroundService(Intent(c, AssistantBubble::class.java))
        }

        fun stop(c: Context) {
            c.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("on", false).apply()
            c.stopService(Intent(c, AssistantBubble::class.java))
        }

        fun isOn(c: Context) = c.getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean("on", false)

        fun openIntent(c: Context) = Intent(c, MainActivity::class.java)
            .setAction(ACTION_OPEN)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    private lateinit var wm: WindowManager
    private var view: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("bubble", "Assistant bubble", NotificationManager.IMPORTANCE_MIN))
        val tap = PendingIntent.getActivity(this, 7, openIntent(this), PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(this, "bubble")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Assistant bubble is on")
            .setContentText("Tap to talk to Focus")
            .setContentIntent(tap)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(8, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(8, n)
        }
        if (canDraw(this)) show()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_STICKY

    override fun onDestroy() {
        view?.let { runCatching { wm.removeView(it) } }
        view = null
        super.onDestroy()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun show() {
        val size = (56 * resources.displayMetrics.density).toInt()
        val lp = WindowManager.LayoutParams(
            size, size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = resources.displayMetrics.widthPixels - size - 24
            y = resources.displayMetrics.heightPixels / 3
        }
        val orb = OrbView(this)
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        orb.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; moved = false
                    v.animate().scaleX(.9f).scaleY(.9f).setDuration(120).start()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    if (abs(dx) > 12 || abs(dy) > 12) moved = true
                    lp.x = startX + dx.toInt(); lp.y = startY + dy.toInt()
                    wm.updateViewLayout(v, lp)
                }
                MotionEvent.ACTION_UP -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(160).start()
                    val w = resources.displayMetrics.widthPixels
                    val h = resources.displayMetrics.heightPixels
                    if (!moved) {
                        startActivity(openIntent(this))
                    } else if (lp.y > h - size * 2) {
                        stop(this)
                    } else {
                        lp.x = if (lp.x + size / 2 < w / 2) 16 else w - size - 16
                        wm.updateViewLayout(v, lp)
                    }
                }
            }
            true
        }
        wm.addView(orb, lp)
        view = orb
    }

    private class OrbView(c: Context) : View(c) {
        private val p = Paint(Paint.ANTI_ALIAS_FLAG)
        override fun onDraw(canvas: Canvas) {
            val r = width / 2f
            p.shader = RadialGradient(r * .7f, r * .6f, r * 1.2f,
                intArrayOf(Color.parseColor("#E0E7FF"), Color.parseColor("#6366F1"), Color.parseColor("#111116")),
                floatArrayOf(0f, .55f, 1f), Shader.TileMode.CLAMP)
            canvas.drawCircle(r, r, r - 2, p)
            p.shader = null
            p.style = Paint.Style.STROKE
            p.strokeWidth = 2f
            p.color = Color.argb(60, 255, 255, 255)
            canvas.drawCircle(r, r, r - 3, p)
            p.style = Paint.Style.FILL
        }
    }
}
