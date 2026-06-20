plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.helixiora.endpointsecurity"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    val releaseKeystorePath = providers.gradleProperty("HELIXIORA_ANDROID_KEYSTORE")
        .orElse(providers.environmentVariable("HELIXIORA_ANDROID_KEYSTORE"))
        .orNull
    val releaseKeystorePassword = providers.gradleProperty("HELIXIORA_ANDROID_KEYSTORE_PASSWORD")
        .orElse(providers.environmentVariable("HELIXIORA_ANDROID_KEYSTORE_PASSWORD"))
        .orNull
    val releaseKeyAlias = providers.gradleProperty("HELIXIORA_ANDROID_KEY_ALIAS")
        .orElse(providers.environmentVariable("HELIXIORA_ANDROID_KEY_ALIAS"))
        .orNull
    val releaseKeyPassword = providers.gradleProperty("HELIXIORA_ANDROID_KEY_PASSWORD")
        .orElse(providers.environmentVariable("HELIXIORA_ANDROID_KEY_PASSWORD"))
        .orNull
    val hasReleaseSigning =
        !releaseKeystorePath.isNullOrBlank() &&
            !releaseKeystorePassword.isNullOrBlank() &&
            !releaseKeyAlias.isNullOrBlank() &&
            !releaseKeyPassword.isNullOrBlank()

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.helixiora.endpointsecurity"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
