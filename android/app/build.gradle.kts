import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Релизная подпись для публикации в Google Play (fastlane, .github/workflows/release.yml).
// android/key.properties не коммитится (.gitignore); CI генерирует его из секретов
// перед вызовом fastlane. Без него release-сборка использует debug-ключи, как раньше
// (`flutter build apk/appbundle --release` и CI build.yml продолжают работать без секретов).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "net.nativemind.comics.editor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "net.nativemind.comics.editor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // sdd-comics-editor-v2.9-android-ios: решение Q3
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // TODO: до первой публикации в Google Play добавить android/key.properties
            // (см. .github/workflows/release.yml) — до тех пор release-сборка подписана
            // debug-ключами, чтобы `flutter build/run --release` и CI build.yml работали.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release")
                             else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation(kotlin("test"))
}
