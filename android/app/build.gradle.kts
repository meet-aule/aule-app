import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadPropertiesFile = rootProject.file("key.properties")
val uploadProperties = Properties().apply {
    if (uploadPropertiesFile.isFile) uploadPropertiesFile.inputStream().use { load(it) }
}
val missingUploadFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .filter { uploadProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.meetaule.aule"
    // permission_handler_android compiles against Android 17.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.meetaule.aule"
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

    if (uploadPropertiesFile.isFile && missingUploadFields.isEmpty()) {
        signingConfigs.create("upload") {
            storeFile = rootProject.file(uploadProperties.getProperty("storeFile"))
            storePassword = uploadProperties.getProperty("storePassword")
            keyAlias = uploadProperties.getProperty("keyAlias")
            keyPassword = uploadProperties.getProperty("keyPassword")
        }
    }
    buildTypes.getByName("release").signingConfig = signingConfigs.findByName("upload")
}

// An incomplete local signing setup should fail a release without blocking debug builds.
if (uploadPropertiesFile.isFile && missingUploadFields.isNotEmpty()) {
    tasks.matching { it.name == "preReleaseBuild" }.configureEach {
        doFirst {
            throw GradleException("Incomplete Android upload signing settings: ${missingUploadFields.joinToString()}")
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
