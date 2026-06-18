# Keep Google ML Kit classes and prevent obfuscation
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep Google Play Services GMS classes
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
