import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Yandex MapKit kaliti repoda saqlanmaydi. Manba tartibi:
 *   1. `android/local.properties` → `yandex.mapkit.key=...`  (git'ga kirmaydi)
 *   2. `-Pyandex.mapkit.key=...` gradle parametri (CI uchun)
 *   3. `YANDEX_MAPKIT_KEY` muhit o'zgaruvchisi
 * Topilmasa bo'sh qoladi — ilova ishlaydi, faqat xarita chizilmaydi.
 */
val yandexMapkitKey: String = run {
    val local = Properties().apply {
        rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
    }

    (local.getProperty("yandex.mapkit.key")
        ?: project.findProperty("yandex.mapkit.key") as String?
        ?: System.getenv("YANDEX_MAPKIT_KEY")
        ?: "").trim()
}

android {
    buildFeatures {
        buildConfig = true
    }

    ndkVersion = "27.0.12077973"
    namespace = "com.example.mening_ilovam"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mening_ilovam"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Yandex MapKit minSdk 26 (Android 8.0+) talab qiladi.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        buildConfigField("String", "YANDEX_MAPKIT_KEY", "\"$yandexMapkitKey\"")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Yandex MapKit native SDK — yandex_mapkit plugin uni `implementation`
    // (yashirin) qilib e'lon qiladi, shuning uchun MainApplication'dan
    // MapKitFactory.setApiKey(...) chaqirish uchun app modulida ham kerak.
    // Versiya va variant plugin ishlatadigani bilan bir xil bo'lishi shart:
    // yandex_mapkit 4.3.0 → 4.39.1, variant `android/gradle.properties`dagi
    // `yandexMapkit.variant` (full — geocoding va routing uchun kerak).
    implementation("com.yandex.android:maps.mobile:4.39.1-full")
}
