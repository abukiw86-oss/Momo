# Basic Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
# Ignore missing Play Core classes referenced internally by the Flutter Engine
-dontwarn com.google.android.play.core.**

# If R8 still complains about specific missing dynamic feature classes, keep them safe:
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }