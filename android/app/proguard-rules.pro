# Keep TensorFlow Lite GPU Delegate classes
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# (Optional) Prevent stripping of anything TensorFlow uses via reflection
-keepclassmembers class * {
    @org.tensorflow.lite.Interpreter.Options *;
}
