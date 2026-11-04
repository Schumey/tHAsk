import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.schumey.thask"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "de.schumey.thask"
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

    // Schlüssel aus dem privaten Begleit-Repo (local/ im Repo oder tHAsk-local daneben).
    val companion = listOf("../../local", "../../../tHAsk-local")
        .map { rootProject.file("$it/android") }
        .firstOrNull { it.isDirectory }
    val releaseProps = companion?.resolve("release.properties")?.takeIf { it.exists() }?.let { file ->
        Properties().apply { file.inputStream().use { load(it) } }
    }

    signingConfigs {
        // Gemeinsamer Debug-Schlüssel, damit `adb install -r` von jedem PC aus ein Update ist.
        // Fehlt er, nimmt Gradle den Schlüssel des PCs.
        getByName("debug") {
            val shared = companion?.resolve("debug.keystore")?.takeIf { it.exists() }
            if (shared != null) storeFile = shared
        }
        // Schlüssel der veröffentlichten APKs (GitHub-Releases); Updates in der App gehen nur mit ihm.
        if (releaseProps != null) {
            create("release") {
                storeFile = companion.resolve(releaseProps.getProperty("storeFile"))
                storePassword = releaseProps.getProperty("storePassword")
                keyAlias = releaseProps.getProperty("keyAlias")
                keyPassword = releaseProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Ohne den Release-Schlüssel (Bau aus dem öffentlichen Quellcode) mit dem Debug-Schlüssel.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
        debug {
            // Debug-Builds mit demselben Schlüssel wie die Releases, damit `adb install -r` die installierte
            // Release-App ersetzt (und umgekehrt), ohne Anmeldung und vorgemerkte Änderungen zu verlieren.
            signingConfigs.findByName("release")?.let { signingConfig = it }
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
