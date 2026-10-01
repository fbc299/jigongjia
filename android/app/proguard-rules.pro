# Flutter 相关 keep 规则（避免 R8 混淆/裁剪破坏 Flutter 运行时）
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# sqflite / 数据库反射相关
-keep class com.jigongjia.jigongjia.** { *; }

# 保留插件注册类的反射入口
-keep class * extends io.flutter.plugin.common.MethodChannel$MethodCallHandler
-keep class * extends io.flutter.plugin.common.PluginRegistry$Registrar

# 本 app 未使用 Play Store 延迟组件，这些类缺失不影响运行
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**