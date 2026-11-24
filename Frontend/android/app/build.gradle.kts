plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    id("com.google.gms.google-services")
}

import java.util.Properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// Google Maps SDK for Android key. Resolved at build time from (in order):
//   1. a -P project property or ~/.gradle/gradle.properties / gradle.properties
//   2. GOOGLE_MAPS_API_KEY in android/local.properties (gitignored)
//   3. the GOOGLE_MAPS_API_KEY environment variable
// If none is set the APK ships with an empty key and the map renders blank.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}
val googleMapsApiKey: String =
    (project.findProperty("GOOGLE_MAPS_API_KEY") as String?)
        ?: localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: ""

// Fail fast on a keyless RELEASE build so a blank-map APK can never ship.
// Debug/`flutter run` is left alone so day-to-day development isn't blocked.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        val name = task.name
        name.contains("Release") && (
            name.startsWith("assemble") ||
            name.startsWith("bundle") ||
            name.startsWith("package")
        )
    }
    if (buildingRelease && googleMapsApiKey.isBlank()) {
        throw GradleException(
            "GOOGLE_MAPS_API_KEY is not set — the release build would ship with a blank Google Map. " +
            "Add 'GOOGLE_MAPS_API_KEY=<your Maps SDK for Android key>' to android/local.properties, " +
            "or pass -PGOOGLE_MAPS_API_KEY=<key> to the build."
        )
    }
}

android {
    namespace = "in.godigitalindia.portal"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
	isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "in.godigitalindia.portal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
    create("release") {
	keyAlias = keystoreProperties.getProperty("keyAlias")
	keyPassword = keystoreProperties.getProperty("keyPassword")
	storeFile = file(keystoreProperties.getProperty("storeFile"))
	storePassword = keystoreProperties.getProperty("storePassword")
    }
}

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            //signingConfig = signingConfigs.getByName("debug")
	    signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:35.1.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  // https://firebase.google.com/docs/android/setup#available-libraries
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
