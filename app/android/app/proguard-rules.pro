# JNA, used by PhononTTS to load libptts_ffi.so.
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class com.preetam.focus.PhononTTS** { *; }
-dontwarn java.awt.**
