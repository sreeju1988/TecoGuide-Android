# Ignore R8 warnings about missing classes to prevent compilation failures
-ignorewarnings

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WebView rules
-keep class android.webkit.** { *; }
-keep class com.baseflow.** { *; }

# Keep JavaScript interfaces intact (critical for web wrapper JS injection)
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
