import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名：本地读 android/key.properties（已 gitignore），CI 读环境变量。
// 两者都没有时回退 debug 签名，保证 `flutter build apk` 不会直接失败。
val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        FileInputStream(keystorePropsFile).use { load(it) }
    }
}
fun signingValue(prop: String, env: String): String? =
    keystoreProps.getProperty(prop)?.takeIf { it.isNotBlank() } ?: System.getenv(env)

android {
    namespace = "com.jigongjia.jigongjia"
    // flutter_secure_storage 编译于 SDK 36；本地已装 android-36，直接对齐避免警告
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jigongjia.gegejigong"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage（备份 token 走 Android Keystore）要求 API 23+，
        // 21/22 = Android 5.x，早已无人使用
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storePath = signingValue("storeFile", "JIGONG_STORE_FILE")
            if (storePath != null && File(storePath).exists()) {
                storeFile = File(storePath)
                storePassword = signingValue("storePassword", "JIGONG_STORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "JIGONG_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "JIGONG_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val releaseCfg = signingConfigs.getByName("release")
            // 有正式密钥就用正式密钥；否则回退 debug（CI 未配 secret 时仍能出包验证）
            signingConfig = if (releaseCfg.storeFile != null) releaseCfg else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
