package com.gustlarsen.howpredictable

import android.accounts.AccountManager
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.gustlarsen.howpredictable/vibrator"
        private const val PLAY_GAMES_CHANNEL = "com.gustlarsen.howpredictable/play_games"
        private const val RC_CHOOSE_ACCOUNT = 9001
    }

    private var pendingAccountResult: MethodChannel.Result? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAY_GAMES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "chooseAccount" -> {
                        launchAccountPicker(result)
                    }
                    "signOut" -> {
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun launchAccountPicker(result: MethodChannel.Result) {
        pendingAccountResult?.success(null)
        pendingAccountResult = result

        try {
            val gmsIntent = Intent("com.google.android.gms.common.account.CHOOSE_ACCOUNT").apply {
                setPackage("com.google.android.gms")
                putExtra("allowableAccountTypes", arrayOf("com.google"))
                putExtra("alwaysPromptForAccount", true)
            }
            startActivityForResult(gmsIntent, RC_CHOOSE_ACCOUNT)
            return
        } catch (_: Throwable) {
        }

        try {
            @Suppress("DEPRECATION")
            val fallbackIntent = AccountManager.newChooseAccountIntent(
                null,
                null,
                arrayOf("com.google"),
                true,
                null,
                null,
                null,
                null
            )
            startActivityForResult(fallbackIntent, RC_CHOOSE_ACCOUNT)
        } catch (_: Throwable) {
            val pending = pendingAccountResult
            pendingAccountResult = null
            pending?.success(null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == RC_CHOOSE_ACCOUNT) {
            val pending = pendingAccountResult
            pendingAccountResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val accountName = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                val accountType = data.getStringExtra(AccountManager.KEY_ACCOUNT_TYPE)
                if (!accountName.isNullOrBlank()) {
                    pending?.success(
                        mapOf(
                            "accountName" to accountName,
                            "accountType" to (accountType ?: "com.google")
                        )
                    )
                    return
                }
            }
            pending?.success(null)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
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

