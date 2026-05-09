plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read GOOGLE_MAPS_API_KEY from .env.local (Flutter project root) for Google Maps.
// Falls back to the GOOGLE_MAPS_API_KEY system environment variable for CI/CD environments.
val envFile = rootProject.file("../.env.local")
var googleMapsApiKey = if (envFile.exists()) {
    envFile.readLines()
        .firstOrNull { it.trimStart().startsWith("GOOGLE_MAPS_API_KEY=") }
        ?.substringAfter("=", "")
        ?.trim()
        ?.replace(Regex("^[\"']|[\"']$"), "")
        ?: ""
} else ""

if (googleMapsApiKey.isEmpty()) {
    googleMapsApiKey = System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.exists()) {
    val keystoreProperties = java.util.Properties()
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
    android.signingConfigs.create("release") {
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
    }
}

android {
    namespace = "com.locationsafe.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.locationsafe.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.names.contains("release")) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
