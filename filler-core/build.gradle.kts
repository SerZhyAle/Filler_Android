import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The pure Filler logic shared by every surface (S0003, S0013): the engine, its contracts and the session
// journal, ported from FastMediaSorter release 48. The storage adapters and the screens stay per surface.
plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.sza.filler.core"
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        minSdk = libs.versions.min.sdk.get().toInt()
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests {
            // Robolectric runs the journal test against a real Context, AtomicFile and org.json.
            isIncludeAndroidResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    api(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.robolectric)
}
