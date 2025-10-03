@Suppress("DSL_SCOPE_VIOLATION")

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // FlutterFire / Google Services plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.tb_frontend"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
    applicationId = "com.example.tb_frontend"
    minSdk = 24
    targetSdk = 36
    versionCode = 1
    versionName = "1.0"
}


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.2.0")
}

