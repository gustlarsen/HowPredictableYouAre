package com.gustlarsen.howpredictable

import android.app.ActivityManager
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
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.gustlarsen.howpredictable/vibrator"
        private const val VIEWPORT_CHANNEL = "com.gustlarsen.howpredictable/viewport"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val insetsSyncRunnable = Runnable { syncEdgeToEdgeInsets() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isDuplicateLauncherRoot()) {
            finish()
            return
        }
        cleanupStaleAppTasks()
        configureEdgeToEdgeWindow()
        scheduleInsetsSync()
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
                    scheduleInsetsSync()
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        scheduleInsetsSync()
    }

    override fun onPostResume() {
        super.onPostResume()
        scheduleInsetsSync()
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
        cleanupStaleAppTasks()
        scheduleInsetsSync()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        configureEdgeToEdgeWindow()
        scheduleInsetsSync()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            scheduleInsetsSync()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        scheduleInsetsSync()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(insetsSyncRunnable)
        super.onDestroy()
    }

    /**
     * Guards against Android stacking a duplicate launcher Activity onto an
     * existing task when launched from external entry points (e.g., Play Store).
     */
    private fun isDuplicateLauncherRoot(): Boolean {
        if (isTaskRoot) return false
        val launchIntent = intent ?: return false
        return launchIntent.action == Intent.ACTION_MAIN &&
            launchIntent.hasCategory(Intent.CATEGORY_LAUNCHER)
    }

    /**
     * Removes any orphaned Recents tasks belonging exclusively to this app
     * (such as a legacy pre-update task created with empty taskAffinity) after
     * a clean launch or singleTask handoff.
     */
    private fun cleanupStaleAppTasks() {
        try {
            val activityManager =
                getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return
            val currentTaskId = taskId
            if (currentTaskId == -1) return
            for (appTask in activityManager.appTasks) {
                val info = try {
                    appTask.taskInfo
                } catch (_: Throwable) {
                    null
                } ?: continue
                val existingTaskId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    info.taskId
                } else {
                    @Suppress("DEPRECATION")
                    info.id
                }
                if (existingTaskId != currentTaskId) {
                    appTask.finishAndRemoveTask()
                }
            }
        } catch (_: Throwable) {
            // Fail safely if ActivityManager task inspection is unavailable.
        }
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

    private fun scheduleInsetsSync() {
        mainHandler.removeCallbacks(insetsSyncRunnable)
        mainHandler.post(insetsSyncRunnable)
        // Re-apply WindowInsets after transient Play Core / system overlay transitions settle.
        mainHandler.postDelayed(insetsSyncRunnable, 120L)
        mainHandler.postDelayed(insetsSyncRunnable, 350L)
    }

    private fun syncEdgeToEdgeInsets() {
        if (isFinishing || isDestroyed) return
        val win = window ?: return
        val decor = win.decorView
        WindowCompat.setDecorFitsSystemWindows(win, false)
        ViewCompat.requestApplyInsets(decor)
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

