-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; } 
-dontwarn com.google.android.play.core.**
 
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
 
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
 
-keep class org.maplibre.** { *; }
-keep class com.mapbox.** { *; }
 
-keepclasseswithmembernames class * {
    native <methods>;
}
 
-keep class com.example.gps_tracker.models.** { *; }

-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

-optimizationpasses 10
-allowaccessmodification
-repackageclasses 'com.a'
-flattenpackagehierarchy
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose
-dontwarn