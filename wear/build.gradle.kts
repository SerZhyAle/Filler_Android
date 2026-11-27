import com.sza.filler.buildlogic.ReleaseSigning
import com.sza.filler.buildlogic.VersionStamp
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
}

// Frozen anchor (owner, 2026-11-13; S0013 answer B, S0007): the watch app installs under the SAME application
// id as the phone app - one listing, one id, one signing key, and the Wear Data Layer routes by it. It must
// stay identical to `:phone`'s `publishedApplicationId`. Never a suffix, never a rename once a package ships.
val publishedApplicationId = "com.sza.filler"

// PACKAGE-VERSIONING, Android profile. The same rules as `:phone`, in the watch family's band (6..9, a 15
// minute slot, registered in the rule 3 table since 0.8): a pinned pair (both properties or neither) wins over
// the clock (rule 5), and an invocation that pins nothing stamps itself from the one clock reading the root
// build took (rule 6). The versionName is byte-identical to the phone's for one instant (rule 1).
val pinnedStamp = VersionStamp.fromPin(
    providers.gradleProperty("filler.versionName").orNull,
    providers.gradleProperty("filler.versionCode").orNull,
    VersionStamp.Family.WATCH,
)
val stamp = pinnedStamp
    ?: VersionStamp.fromInstant(rootProject.extra["filler.buildInstant"] as String, VersionStamp.Family.WATCH)

logger.lifecycle("[filler] :wear ${stamp.name} (${stamp.code})")

// S0023 G2: signed exactly as `:phone` is - the same upload key from the same properties file - because the two
// apps share one application id and Play serves both under one app signing key (buildSrc ReleaseSigning).
val uploadKey = ReleaseSigning.load(providers.environmentVariable(ReleaseSigning.ENV).orNull, rootDir)

android {
    // The code namespace differs from the phone's: both modules generate an R class and must not collide.
    // Only the install identity (applicationId) has to match the phone.
    namespace = "com.sza.filler.wear"
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        applicationId = publishedApplicationId
        minSdk = libs.versions.wear.min.sdk.get().toInt()
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
            // Side-by-side install alongside Google Play release (FILLER-0074); matches :phone debug id for Wear Data Layer.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-DEBUG"
        }
        getByName("release") {
            // S0023 G7, the R8 decision: unminified, as `:phone`, until a pre-flight proves a minified release variant.
            isMinifyEnabled = false
            if (uploadKey != null) signingConfig = signingConfigs.getByName("upload")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests {
            // Robolectric runs the adapter and controller tests against a real Context, its files and the journal (S0029).
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
    // The one place of the shared pure Filler logic (S0003, S0013 criterion 4): the engine, the session journal
    // and the estimator are consumed from here by `:phone` and `:wear` alike, never copied. The watch storage
    // adapter, the run host and the screen over it are this module's own (S0019).
    implementation(project(":filler-core"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.wear.ongoing)

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
}

gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter {
        it.path.startsWith(":wear:") && it.name in setOf("assembleRelease", "bundleRelease", "packageRelease")
    }
    // A release package carries the version of the release it ships (PACKAGE-VERSIONING rule 5; the release
    // is pinned to its tag), never a clock reading of whoever ran Gradle.
    if (releaseTasks.isNotEmpty() && pinnedStamp == null) {
        throw GradleException(
            "Release packaging is refused: no version is pinned. Pass both '-Pfiller.versionName=..' and " +
                "'-Pfiller.versionCode=..' (the release orchestrator does); :wear:assembleDebug needs no pin.",
        )
    }
    if (releaseTasks.isNotEmpty() && uploadKey == null) {
        logger.warn(
            "[filler] :wear release package is UNSIGNED: no upload key (set ${ReleaseSigning.ENV} to the " +
                "keystore.properties written by tools/release/new-release-keys.ps1).",
        )
    }
}
