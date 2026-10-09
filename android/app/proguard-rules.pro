# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Razorpay Keep Rules
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-keepclasseswithmembers class * {
    public void onPayment*(...);
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Agora RTC Engine Keep Rules
-keep class io.agora.** { *; }
-dontwarn io.agora.**
-keep class io.agora.rtc2.** { *; }

# Google Maps Keep Rules
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.maps.**

# Health Connect Keep Rules
-keep class androidx.health.connect.client.** { *; }
-dontwarn androidx.health.connect.client.**

# Socket.IO / OkHttp Keep Rules
-dontwarn io.socket.**
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class io.socket.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Firebase Keep Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Play Core / Split / Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

