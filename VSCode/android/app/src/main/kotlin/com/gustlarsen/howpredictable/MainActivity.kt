package com.gustlarsen.howpredictable

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.gustlarsen.howpredictable/vibrator"
        private const val VIEWPORT_CHANNEL = "com.gustlarsen.howpredictable/viewport"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val viewportSyncRunnable = Runnable { syncViewportAndInsets(allowSurfaceReset = true) }
    private var decorLayoutListener: View.OnLayoutChangeListener? = null
    private var isResettingSurface = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureEdgeToEdgeWindow()
        attachDecorLayoutSyncListener()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "vibrate") {
                    val durationMs = (call.argument<Number>("duration")?.toLong() ?: 100L)
                        .coerceAtLeast(1L)
                    vibrateDevice(durationMs)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIEWPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "syncViewport") {
                    scheduleViewportSync()
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        scheduleViewportSync()
    }

    override fun onPostResume() {
        super.onPostResume()
        scheduleViewportSync()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        scheduleViewportSync()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        configureEdgeToEdgeWindow()
        scheduleViewportSync()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            scheduleViewportSync()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        scheduleViewportSync()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(viewportSyncRunnable)
        decorLayoutListener?.let { listener ->
            window?.decorView?.removeOnLayoutChangeListener(listener)
        }
        decorLayoutListener = null
        super.onDestroy()
    }

    private fun configureEdgeToEdgeWindow() {
        val win = window ?: return
        WindowCompat.setDecorFitsSystemWindows(win, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val attrs = win.attributes
            val desiredMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else {
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
            if (attrs.layoutInDisplayCutoutMode != desiredMode) {
                attrs.layoutInDisplayCutoutMode = desiredMode
                win.attributes = attrs
            }
        }
    }

    private fun attachDecorLayoutSyncListener() {
        val decor = window?.decorView ?: return
        if (decorLayoutListener != null) return
        val listener = View.OnLayoutChangeListener { _, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
            val newW = right - left
            val newH = bottom - top
            val oldW = oldRight - oldLeft
            val oldH = oldBottom - oldTop
            if (newW > 0 && newH > 0 && (newW != oldW || newH != oldH)) {
                syncViewportAndInsets(allowSurfaceReset = false)
            }
        }
        decorLayoutListener = listener
        decor.addOnLayoutChangeListener(listener)
    }

    private fun scheduleViewportSync() {
        mainHandler.removeCallbacks(viewportSyncRunnable)
        mainHandler.post(viewportSyncRunnable)
        // Re-check after Play Core overlay transitions / Samsung Game Booster scaling settle
        mainHandler.postDelayed(viewportSyncRunnable, 120L)
        mainHandler.postDelayed(viewportSyncRunnable, 350L)
    }

    private fun syncViewportAndInsets(allowSurfaceReset: Boolean) {
        if (isFinishing || isDestroyed) return
        val win = window ?: return
        val decor = win.decorView
        WindowCompat.setDecorFitsSystemWindows(win, false)
        ViewCompat.requestApplyInsets(decor)

        val flutterView = findFlutterView(decor) ?: return
        val parentView = (flutterView.parent as? View) ?: decor
        val targetWidth = parentView.width
        val targetHeight = parentView.height

        val lp = flutterView.layoutParams
        if (lp != null &&
            (lp.width != ViewGroup.LayoutParams.MATCH_PARENT ||
                lp.height != ViewGroup.LayoutParams.MATCH_PARENT)
        ) {
            lp.width = ViewGroup.LayoutParams.MATCH_PARENT
            lp.height = ViewGroup.LayoutParams.MATCH_PARENT
            flutterView.layoutParams = lp
        }

        var needsRelayout = targetWidth > 0 &&
            targetHeight > 0 &&
            (flutterView.width != targetWidth || flutterView.height != targetHeight)

        var needsSurfaceReset = false
        val surfaceViews = mutableListOf<SurfaceView>()
        collectSurfaceViews(flutterView, surfaceViews)
        for (surfaceView in surfaceViews) {
            surfaceView.holder.setSizeFromLayout()
            val svLp = surfaceView.layoutParams
            if (svLp != null &&
                (svLp.width != ViewGroup.LayoutParams.MATCH_PARENT ||
                    svLp.height != ViewGroup.LayoutParams.MATCH_PARENT)
            ) {
                svLp.width = ViewGroup.LayoutParams.MATCH_PARENT
                svLp.height = ViewGroup.LayoutParams.MATCH_PARENT
                surfaceView.layoutParams = svLp
                needsRelayout = true
            }
            if (targetWidth > 0 && targetHeight > 0) {
                if (surfaceView.width != targetWidth || surfaceView.height != targetHeight) {
                    needsRelayout = true
                }
                val frame = surfaceView.holder.surfaceFrame
                if (frame.width() > 0 &&
                    frame.height() > 0 &&
                    (frame.width() != targetWidth || frame.height() != targetHeight)
                ) {
                    needsRelayout = true
                    needsSurfaceReset = true
                }
            }
        }

        if (needsRelayout) {
            for (surfaceView in surfaceViews) {
                surfaceView.requestLayout()
            }
            flutterView.requestLayout()
            decor.requestLayout()
        }

        if (allowSurfaceReset && needsSurfaceReset && !isResettingSurface) {
            isResettingSurface = true
            for (surfaceView in surfaceViews) {
                if (surfaceView.visibility == View.VISIBLE) {
                    surfaceView.visibility = View.INVISIBLE
                    surfaceView.post {
                        if (!isFinishing && !isDestroyed) {
                            surfaceView.visibility = View.VISIBLE
                            surfaceView.requestLayout()
                            ViewCompat.requestApplyInsets(flutterView)
                        }
                        isResettingSurface = false
                    }
                } else {
                    isResettingSurface = false
                }
            }
            if (surfaceViews.isEmpty()) {
                isResettingSurface = false
            }
        }

        ViewCompat.requestApplyInsets(flutterView)
    }

    private fun findFlutterView(root: View): FlutterView? {
        if (root is FlutterView) return root
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                val found = findFlutterView(root.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun collectSurfaceViews(root: View, out: MutableList<SurfaceView>) {
        if (root is SurfaceView) {
            out.add(root)
        }
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                collectSurfaceViews(root.getChildAt(i), out)
            }
        }
    }

    private fun vibrateDevice(durationMs: Long) {
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vibratorManager?.defaultVibrator
                ?: @Suppress("DEPRECATION") (getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

        if (vibrator != null && vibrator.hasVibrator()) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(
                        VibrationEffect.createOneShot(
                            durationMs,
                            VibrationEffect.DEFAULT_AMPLITUDE
                        )
                    )
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(durationMs)
                }
                return
            } catch (_: Throwable) {
                try {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(durationMs)
                    return
                } catch (_: Throwable) {
                }
            }
        }

        @Suppress("DEPRECATION")
        window?.decorView?.performHapticFeedback(
            HapticFeedbackConstants.LONG_PRESS,
            HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING or
                HapticFeedbackConstants.FLAG_IGNORE_VIEW_SETTING
        )
    }
}

