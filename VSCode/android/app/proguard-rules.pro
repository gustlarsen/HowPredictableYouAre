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

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.errorprone.annotations.**

# Room & WorkManager (transitively pulled by Google Mobile Ads via work-runtime 2.7.0 / room-runtime 2.2.5)
# AGP 9 / R8 full mode strips <init>() when consumer rules omit member blocks,
# causing WorkDatabase_Impl instantiation to fail during InitializationProvider startup.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.InputMerger {
    <init>();
}


