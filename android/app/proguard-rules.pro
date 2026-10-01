# Flutter and Android Release Proguard Optimization Rules for AptiQu

# Flutter Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In SDK
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Flutter Secure Storage (EncryptedSharedPreferences & Keystore)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }

# Native and JNI bindings
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve Reflection Attributes
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses,SourceFile,LineNumberTable

# Flutter Play Store Deferred Components (optional split-install classes)
-dontwarn com.google.android.play.core.**

