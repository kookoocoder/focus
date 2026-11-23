package com.preetam.focus

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import java.text.DateFormat
import java.util.Date
import kotlin.math.abs

class ScrollService : AccessibilityService() {
    private var lastPkg = ""
    private var lastCountAt = 0L
    private var lastBlockAt = 0L

    private val ignored = HashSet<String>()

    override fun onServiceConnected() {
        ScrollStore.markStarted(this)
        // Home launchers scroll constantly and aren't "apps you scroll in".
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        for (r in packageManager.queryIntentActivities(home, 0)) ignored.add(r.activityInfo.packageName)
    }

    override fun onAccessibilityEvent(e: AccessibilityEvent) {
        val pkg = e.packageName?.toString() ?: return
        if (pkg == packageName || pkg == "com.android.systemui" || pkg in ignored ||
            pkg.contains("inputmethod") || pkg.contains("keyboard")) return

        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            enforce(pkg)  // block opening a limited app during a lecture / after the limit
            return
        }
        val now = System.currentTimeMillis()
        // Pagers (Reels / Shorts) often report a page change as VIEW_SELECTED.
        val isScroll = e.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED
        val isPage = e.eventType == AccessibilityEvent.TYPE_VIEW_SELECTED && pkg in ScrollStore.limited &&
            e.className?.toString()?.contains("ViewPager") == true
        if (!isScroll && !isPage) return
        ScrollStore.setLast(this, pkg, now)
        val px = if (Build.VERSION.SDK_INT >= 28) abs(e.scrollDeltaY).toLong() else 0L
        // One swipe fires many events; count one swipe per 400ms burst.
        val newSwipe = pkg != lastPkg || now - lastCountAt > 400
        lastPkg = pkg
        lastCountAt = now
        ScrollStore.add(this, pkg, if (newSwipe) 1 else 0, px, now)
        enforce(pkg)
    }

    private fun enforce(pkg: String) {
        if (pkg !in ScrollStore.limited) return
        val now = System.currentTimeMillis()

        if (ScrollStore.lockEnabled(this)) {
            val lec = ScrollStore.currentLecture(this, now)
            if (lec != null) {
                block("lecture", "Lecture in progress until " +
                    DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(lec.getLong("end"))) +
                    ". Stay focused.")
                return
            }
        }
        if (ScrollStore.overLimit(this)) block("limit", "Daily scroll limit reached. Back to focus.")
    }

    private fun block(kind: String, msg: String) {
        performGlobalAction(GLOBAL_ACTION_HOME)
        val now = System.currentTimeMillis()
        if (now - lastBlockAt > 5000) {  // one attempt = one count
            lastBlockAt = now
            ScrollStore.countBlock(this, kind)
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
        }
    }

    override fun onInterrupt() {}
}
