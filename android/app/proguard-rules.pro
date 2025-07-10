# Keep annotations used by Razorpay
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }

# Keep all Razorpay classes and avoid warnings
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
