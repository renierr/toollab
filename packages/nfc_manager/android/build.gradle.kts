group = "dev.flutter.plugins.nfcmanager"
version = "1.0-SNAPSHOT"

// No Kotlin Gradle Plugin here: AGP 9 compiles Kotlin itself, and with
// android.builtInKotlin=false Flutter's Gradle plugin applies KGP for us.
plugins {
    id("com.android.library")
}

android {
    namespace = "dev.flutter.plugins.nfcmanager"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }
}
