# Flutter and Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.common.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class com.google.api.** { *; }
-keep class com.google.** { *; }
-keep class org.jetbrains.annotations.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.** { *; }
-keep class androidx.** { *; }
-keep class com.facebook.** { *; }
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
# Keep annotations used by Razorpay
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }
# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
# Gson
-keep class com.google.gson.** { *; }
-keep class sun.misc.Unsafe { *; }
# Hive
-keep class com.hive.** { *; }
# Prevent stripping of model classes
-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}
-keep public class * implements java.io.Serializable {
    public static final long serialVersionUID;
}
# Keep all classes with reflection
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Keep all annotations
-keep @interface * 

# Keep all classes used by Firebase and Google Play
-keep class com.google.** { *; }
-keep class com.firebase.** { *; }
-keep class com.razorpay.** { *; }
-keep class java.lang.reflect.** { *; }
-dontwarn java.lang.reflect.**

# Keep all model classes (for Gson, Firebase, etc.)
-keep class * implements java.io.Serializable { *; }
-keep class * extends java.util.ListResourceBundle { *; }
-keepattributes *Annotation*,EnclosingMethod,InnerClasses,Signature,SourceFile,LineNumberTable

# Keep Play Core splitcompat and splitinstall classes
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**
