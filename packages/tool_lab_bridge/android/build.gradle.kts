group = "de.renier.tool_lab.bridge"
version = "1.0-SNAPSHOT"

// Follows Flutter's plugin template: KGP only on the classpath, never applied
// here. AGP 9 compiles Kotlin itself; with android.builtInKotlin=false
// Flutter's Gradle plugin applies KGP for us.
buildscript {
    val kotlinVersion = "2.4.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "de.renier.tool_lab.bridge"

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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
