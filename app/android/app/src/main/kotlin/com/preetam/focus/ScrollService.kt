package com.preetam.focus

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import kotlin.math.abs

class ScrollService : AccessibilityService() {
    private var lastPkg = ""
    private var lastCountAt = 0L
    private var lastToastAt = 0L

    override fun onAccessibilityEvent(e: AccessibilityEvent) {
        val pkg = e.packageName?.toString() ?: return
        if (pkg == packageName || pkg == "com.android.systemui") return

        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            enforce(pkg)  // block re-opening a limited app after the limit
            return
        }
        if (e.eventType != AccessibilityEvent.TYPE_VIEW_SCROLLED) return

        val now = System.currentTimeMillis()
        val px = if (Build.VERSION.SDK_INT >= 28) abs(e.scrollDeltaY).toLong() else 0L
        // One swipe fires many events; count one swipe per 400ms burst.
        val newSwipe = pkg != lastPkg || now - lastCountAt > 400
        lastPkg = pkg
        lastCountAt = now
        ScrollStore.add(this, pkg, if (newSwipe) 1 else 0, px)
        enforce(pkg)
    }

    private fun enforce(pkg: String) {
        val limit = ScrollStore.limit(this)
        if (limit <= 0 || pkg !in ScrollStore.limited) return
        if (ScrollStore.totalLimited(this) < limit) return
        performGlobalAction(GLOBAL_ACTION_HOME)
        val now = System.currentTimeMillis()
        if (now - lastToastAt > 3000) {
            lastToastAt = now
            Toast.makeText(this, "Daily scroll limit reached. Back to focus.", Toast.LENGTH_LONG).show()
        }
    }

    override fun onInterrupt() {}
}
