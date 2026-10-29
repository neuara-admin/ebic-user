import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ebic.user.ebic_user"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ebic.user.ebic_user"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect (health package) requires API 26+.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                storeFile = if (storeFilePath != null) file(storeFilePath) else null
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += listOf(
                "META-INF/*.kotlin_module",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*"
            )
        }
        jniLibs {
            excludes += listOf(
                "lib/*/libagora_lip_sync_extension.so",
                "lib/*/libagora_clear_vision_extension.so",
                "lib/*/libagora_spatial_audio_extension.so",
                "lib/*/libagora_ai_noise_suppression_extension.so",
                "lib/*/libagora_face_capture_extension.so",
                "lib/*/libagora_segmentation_extension.so",
                "lib/*/libagora_ai_echo_cancellation_extension.so",
                "lib/*/libagora_audio_beauty_extension.so",
                "lib/*/libagora_content_inspect_extension.so",
                "lib/*/libagora_video_quality_analyzer_extension.so",
                "lib/*/libagora_video_av1_encoder_extension.so",
                "lib/*/libagora_face_detection_extension.so",
                "lib/*/libagora_screen_capture_extension.so"
            )
        }
    }
}

flutter {
    source = "../.."
}
