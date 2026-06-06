import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")  
    // id("kotlin-android") 
    id("dev.flutter.flutter-gradle-plugin")  
}
 
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

dependencies { 
    implementation(platform("com.google.firebase:firebase-bom:34.12.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-database")  
}

android {
    namespace = "com.example.gps_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // kotlinOptions {
    //     jvmTarget = JavaVersion.VERSION_17.toString()
    // }

    defaultConfig { 
        applicationId = "com.example.gps_tracker" 
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
 
    }
     
    splits {
        abi {
            isEnable = false
            // reset()
            // include("arm64-v8a", "armeabi-v7a") doesnt support the split per abi in shorebird so 
            isUniversalApk = true 
        }
    }
    
    signingConfigs {
        create("release") {
            keyAlias = localProperties.getProperty("RELEASE_KEY_ALIAS") ?: ""
            keyPassword = localProperties.getProperty("RELEASE_KEY_PASSWORD") ?: ""
            storePassword = localProperties.getProperty("RELEASE_STORE_PASSWORD") ?: ""
            
            val keystorePath = localProperties.getProperty("RELEASE_STORE_FILE")
            if (!keystorePath.isNullOrEmpty()) {
                storeFile = file(keystorePath)
            }
        }
    }

    buildTypes {
        release { 
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
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