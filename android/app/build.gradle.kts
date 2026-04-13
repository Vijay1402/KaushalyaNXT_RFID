plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Firebase
}

android {
    namespace = "com.example.kaushalyanxt_rfid"
    compileSdk = 36   // ✅ FIXED (IMPORTANT)

    defaultConfig {
        applicationId = "com.example.kaushalyanxt_rfid"
        minSdk = flutter.minSdkVersion
        targetSdk = 36   // ✅ Match compile SDK
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
    release {
        isMinifyEnabled = true      // ✅ required
        isShrinkResources = true    // ✅ allowed now
        signingConfig = signingConfigs.getByName("debug")
    }
}

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0")) // ✅ Firebase BOM
    implementation("com.google.firebase:firebase-analytics")
}
