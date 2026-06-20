# Keep Google ML Kit classes and prevent obfuscation
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep Google Play Services GMS classes
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep local Google ML Kit GenAI Prompt plugin classes
-keep class com.google_mlkit_genai_prompt.** { *; }
-dontwarn com.google_mlkit_genai_prompt.**
