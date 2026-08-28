# Add project specific ProGuard rules here.

# Keep Room generated entities/DAOs (Room 2.x already ships consumer rules,
# but keep entity field names to be safe when reflection-based serialization is used).
-keep class com.tick.app.model.** { *; }
-keep class com.tick.app.data.** { *; }

# OkHttp / Okio
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Kotlin coroutines inline
-dontwarn kotlinx.coroutines.**