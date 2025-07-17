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
        
        // Configure NDK build
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
        
        // Configure CMake for native library compilation
        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17", "-frtti", "-fexceptions")
                abiFilters += listOf("arm64-v8a", "armeabi-v7a")
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DANDROID_PLATFORM=android-21"
                )
            }
        }
        
        // Configure sing-box native library packaging
        // The sing-box binary is included as a native library (libsing-box.so)
        // and loaded via JNI for direct integration
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
    
    // Configure native library packaging for sing-box
    packaging {
        jniLibs {
            // Ensure sing-box libraries are included for all supported ABIs
            pickFirsts += listOf(
                "**/libsing-box.so"
            )
        }
    }
    
    // Configure source sets to include native libraries
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
    
    // Configure external native build
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

flutter {
    source = "../.."
}

// Task to verify build configuration
tasks.register("verifyBuildConfiguration") {
    doLast {
        println("Verifying build configuration...")
        
        // Verify CMakeLists.txt exists
        val cmakeFile = file("src/main/cpp/CMakeLists.txt")
        if (cmakeFile.exists()) {
            println("✓ Found CMakeLists.txt for native build")
        } else {
            println("✗ Missing CMakeLists.txt")
            throw GradleException("CMakeLists.txt is missing")
        }
        
        // Verify JNI source files exist
        val jniSourceFile = file("src/main/cpp/sing_box_jni.c")
        if (jniSourceFile.exists()) {
            println("✓ Found JNI source file")
        } else {
            println("✗ Missing JNI source file")
            throw GradleException("JNI source file is missing")
        }
        
        println("Build configuration verified!")
    }
}

// Run verification before building
tasks.named("preBuild") {
    dependsOn("verifyBuildConfiguration")
}

dependencies {
    // Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // JSON serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
    
    // Note: sing-box integration is done via JNI with native libraries
    // The libsing-box.so files are included in src/main/jniLibs/
}
