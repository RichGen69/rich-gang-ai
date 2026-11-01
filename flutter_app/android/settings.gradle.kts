pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // KSP 2.3.x is decoupled from the Kotlin version prefix (KSP 2.3.0 release
    // notes: works with Kotlin 2.2+ and newer); 2.3.2 is a documented hotfix
    // in that line. AGP 9 + Kotlin 2.4 rule out KSP1/kapt here.
    id("com.google.devtools.ksp") version "2.3.2" apply false
}

include(":app")
