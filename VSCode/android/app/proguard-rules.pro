# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugin.**

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# SharedPreferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# App MainActivity & MethodChannel handlers
-keep class com.gustlarsen.howpredictable.** { *; }

