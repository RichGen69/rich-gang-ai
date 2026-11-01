import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Version declared in ../settings.gradle.kts (apply false there).
    id("com.google.devtools.ksp")
}

// Production release signing.
//
// Source of truth, in priority order:
//   1. flutter_app/android/keystore.properties (local only; git-ignored)
//   2. RGAI_KEYSTORE_PATH / RGAI_KEYSTORE_PASSWORD /
//      RGAI_KEY_ALIAS / RGAI_KEY_PASSWORD environment variables
//
// Passwords must never be committed, pasted into chat, or written into
// docs. If a release task is requested and the production signing
// material is absent or incomplete, configuration fails explicitly.
// Debug builds do not depend on this configuration.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { input ->
        keystoreProperties.load(input)
    }
}

fun signingValue(propertyName: String, environmentName: String): String? {
    val propertyValue = keystoreProperties.getProperty(propertyName)?.trim()
    if (!propertyValue.isNullOrEmpty()) return propertyValue
    val environmentValue = System.getenv(environmentName)?.trim()
    return environmentValue?.takeIf { it.isNotEmpty() }
}

val releaseStoreFilePath = signingValue("storeFile", "RGAI_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "RGAI_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "RGAI_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "RGAI_KEY_PASSWORD")
val releaseStoreFile = releaseStoreFilePath?.let { path ->
    val file = java.io.File(path)
    if (file.isAbsolute) file else rootProject.file(path)
}
val missingReleaseSigning = mutableListOf<String>().apply {
    if (releaseStoreFile == null) add("storeFile / RGAI_KEYSTORE_PATH")
    if (releaseStorePassword == null) add("storePassword / RGAI_KEYSTORE_PASSWORD")
    if (releaseKeyAlias == null) add("keyAlias / RGAI_KEY_ALIAS")
    if (releaseKeyPassword == null) add("keyPassword / RGAI_KEY_PASSWORD")
    if (releaseStoreFile != null && !releaseStoreFile.exists()) {
        add("an existing keystore file at ${releaseStoreFile.path}")
    }
}
val releaseSigningConfigured = missingReleaseSigning.isEmpty()
val requestedTaskNames = gradle.startParameter.taskNames.joinToString(" ")
val releaseTaskRequested = requestedTaskNames.contains("release", ignoreCase = true)

gradle.taskGraph.whenReady {
    if (releaseTaskRequested && !releaseSigningConfigured) {
        throw GradleException(
            "signing_not_configured: Production release signing is not configured. " +
                "Missing: ${missingReleaseSigning.joinToString(", ")}. " +
                "Create flutter_app/android/keystore.properties locally (it is git-ignored) " +
                "or set the RGAI_KEYSTORE_* environment variables. The release build will " +
                "not fall back to the Android debug key."
        )
    }
}

android {
    namespace = "com.richgang.ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    defaultConfig {
        // Matches the Kotlin package and the JNI symbol prefix
        // (Java_com_richgang_ai_DreamCycleService_*) exported by libdaemon.so.
        applicationId = "com.richgang.ai"
        ndk {
            // libdaemon.so is built for arm64-v8a only (personal build).
            abiFilters += "arm64-v8a"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
            // If production signing is absent, the task-graph check above
            // rejects release/bundle tasks before execution. There is no
            // debug-key fallback.
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

// ISOLATED ONLY (2026-10-30): Room FTS5 module under
// com.richgang.ai.data. NOT wired into DreamCycleService, any chat view,
// or the Rust rusqlite store. Room vs. Rust rusqlite as the single source
// of truth is still an open decision — do not wire this in until it is made.
val roomVersion = "2.8.4"

dependencies {
    // Boot re-arm path (BootReceiver -> DreamArmWorker -> DreamCycleService).
    implementation("androidx.work:work-runtime-ktx:2.12.0")

    // Isolated Room FTS5 persistence (see data/ package). room-ktx carries
    // the coroutine support the suspend DAO needs; room-compiler runs via KSP.
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")

    // JVM-only unit tests for the pure-Kotlin FTS query helper (no Android
    // runtime, no Room database instance needed for those tests).
    testImplementation("junit:junit:4.13.2")
}
