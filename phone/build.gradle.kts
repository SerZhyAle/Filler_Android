import com.sza.filler.buildlogic.ReleaseSigning
import com.sza.filler.buildlogic.VersionStamp
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
}

// Frozen anchor (owner, 2026-11-13): the Play application id, shared by the phone app and the watch app
// (one listing, one id, one signing key). Never a suffix, never a rename once a package ships.
val publishedApplicationId = "com.sza.filler"

// PACKAGE-VERSIONING, Android profile. A pinned pair (both properties or neither) wins over the clock
// (rule 5); an invocation that pins nothing stamps itself from the one clock reading the root build took
// (rule 6). Nothing is typed by hand, so no checked-in sentinel exists to drift. This module is the phone
// family (band 0..5); `:wear` renders the same instant in the watch band.
val pinnedStamp = VersionStamp.fromPin(
    providers.gradleProperty("filler.versionName").orNull,
    providers.gradleProperty("filler.versionCode").orNull,
    VersionStamp.Family.PHONE,
)
val stamp = pinnedStamp
    ?: VersionStamp.fromInstant(rootProject.extra["filler.buildInstant"] as String, VersionStamp.Family.PHONE)

logger.lifecycle("[filler] :phone ${stamp.name} (${stamp.code})")

// S0023 G2: the release package is signed with the upload key (buildSrc ReleaseSigning: one properties file named
// by FILLER_KEYSTORE_PROPERTIES, or keystore.properties at the root, ignored by git). The app signing key is never
// in Gradle; Play App Signing holds it. No file: the release package is built unsigned, with a warning below.
val uploadKey = ReleaseSigning.load(providers.environmentVariable(ReleaseSigning.ENV).orNull, rootDir)

android {
    namespace = "com.sza.filler"
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        applicationId = publishedApplicationId
        minSdk = libs.versions.min.sdk.get().toInt()
        targetSdk = libs.versions.target.sdk.get().toInt()
        versionCode = stamp.code
        versionName = stamp.name
    }

    signingConfigs {
        uploadKey?.let { key ->
            create("upload") {
                storeFile = key.storeFile
                storePassword = key.storePassword
                keyAlias = key.keyAlias
                keyPassword = key.keyPassword
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Side-by-side install alongside Google Play release (FILLER-0074); matches :wear debug id for Wear Data Layer.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-DEBUG"
        }
        getByName("release") {
            // S0023 G7, the R8 decision: the release variant is unminified until a pre-flight proves a minified one
            // on the release variant (the generated view bindings, the journal and the ViewModel factory are not
            // proven under shrinking). Turning it on is its own ticket, judged by tools/release/preflight.ps1.
            isMinifyEnabled = false
            if (uploadKey != null) signingConfig = signingConfigs.getByName("upload")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        // The ported screen reads its views through a generated binding, as the source does (S0005).
        viewBinding = true
    }

    testOptions {
        unitTests {
            // Robolectric runs the storage adapter test against a real Context, its files and the journal (S0004).
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
    implementation(libs.androidx.activity.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.savedstate)
    implementation(libs.google.material)
    implementation(libs.androidx.work.runtime.ktx)
    implementation(project(":filler-core"))

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.robolectric)
}

gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter {
        it.path.startsWith(":phone:") && it.name in setOf("assembleRelease", "bundleRelease", "packageRelease")
    }
    // A release package carries the version of the release it ships (PACKAGE-VERSIONING rule 5; the release
    // is pinned to its tag), never a clock reading of whoever ran Gradle.
    if (releaseTasks.isNotEmpty() && pinnedStamp == null) {
        throw GradleException(
            "Release packaging is refused: no version is pinned. Pass both '-Pfiller.versionName=..' and " +
                "'-Pfiller.versionCode=..' (the release orchestrator does); :phone:assembleDebug needs no pin.",
        )
    }
    if (releaseTasks.isNotEmpty() && uploadKey == null) {
        logger.warn(
            "[filler] :phone release package is UNSIGNED: no upload key (set ${ReleaseSigning.ENV} to the " +
                "keystore.properties written by tools/release/new-release-keys.ps1).",
        )
    }
}
