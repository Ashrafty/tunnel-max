plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlinx-serialization")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tunnelmax.vpnclient"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.tunnelmax.vpnclient"
        minSdk = 21
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for large APK support
        multiDexEnabled = true
        
        // Set application name
        resValue("string", "app_name", "TunnelMax VPN")
    }

    signingConfigs {
        create("release") {
            // For production builds, these should be set via environment variables or gradle.properties
            keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "tunnelmax"
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: ""
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "keystore/release.keystore")
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: ""
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }
        
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            
            // Use release signing config if keystore exists, otherwise use debug
            signingConfig = if (file("keystore/release.keystore").exists()) {
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
}

flutter {
    source = "../.."
}

dependencies {
    // Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // JSON serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
    
    // Note: Singbox library will need to be added manually
    // implementation("io.github.sagernet:libcore:1.8.10")
}
