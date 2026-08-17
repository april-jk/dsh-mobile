import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

fun signingValue(property: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(property)?.takeIf { it.isNotBlank() }

fun stableAndroidVersionCode(versionName: String): Int {
    val parts = versionName.split(".").map { it.toLongOrNull() }
    if (parts.size != 3 || parts.any { it == null || it !in 0L..999L }) {
        throw GradleException(
            "Android versionName must be MAJOR.MINOR.PATCH with each part between 0 and 999: " +
                versionName,
        )
    }

    val versionCode = parts[0]!! * 1_000_000 + parts[1]!! * 1_000 + parts[2]!!
    if (versionCode !in 1..Int.MAX_VALUE.toLong()) {
        throw GradleException("Android versionCode is outside the supported range: $versionCode")
    }
    return versionCode.toInt()
}

val releaseStoreFile = signingValue("storeFile", "DSH_ANDROID_STORE_FILE")
val releaseStorePassword = signingValue("storePassword", "DSH_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "DSH_ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "DSH_ANDROID_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

android {
    namespace = "io.github.apriljk.dshremote"
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
        applicationId = "io.github.apriljk.dshremote"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Derive a stable code from versionName so standalone and Suite builds cannot
        // accidentally downgrade each other by supplying different build numbers.
        versionCode = stableAndroidVersionCode(flutter.versionName)
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

if (
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } &&
    !releaseSigningConfigured
) {
    throw GradleException(
        "Release signing is not configured. Copy android/key.properties.example to " +
            "android/key.properties or provide the DSH_ANDROID_* environment variables.",
    )
}

flutter {
    source = "../.."
}
