import com.sza.filler.buildlogic.VersionStamp
import java.time.LocalDateTime
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
}

// Provisional, not an anchor: the published application id is the owner's open decision. Every release
// packaging task is refused while this id ends in ".provisional"; choosing the real id lifts the guard.
val provisionalApplicationId = "com.sza.filler.provisional"

// PACKAGE-VERSIONING, Android profile. A pinned pair (both properties or neither) wins over the clock
// (rule 5); an invocation that pins nothing stamps itself from one clock reading, taken here once
// (rule 6). Nothing is typed by hand, so no checked-in sentinel exists to drift.
val stamp = VersionStamp.fromPin(
    providers.gradleProperty("filler.versionName").orNull,
    providers.gradleProperty("filler.versionCode").orNull,
) ?: VersionStamp.fromClock(LocalDateTime.now())

logger.lifecycle("[filler] :phone ${stamp.name} (${stamp.code})")

android {
    namespace = "com.sza.filler"
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        applicationId = provisionalApplicationId
        minSdk = libs.versions.min.sdk.get().toInt()
        targetSdk = libs.versions.target.sdk.get().toInt()
        versionCode = stamp.code
        versionName = stamp.name
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    implementation(libs.androidx.appcompat)
    implementation(libs.google.material)
}

gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter {
        it.path.startsWith(":phone:") && it.name in setOf("assembleRelease", "bundleRelease", "packageRelease")
    }
    if (releaseTasks.isNotEmpty() && provisionalApplicationId.endsWith(".provisional")) {
        throw GradleException(
            "Release packaging is refused: the application id $provisionalApplicationId is provisional. " +
                "Build :phone:assembleDebug instead; the published id, signing and distribution are " +
                "decided by the release ticket.",
        )
    }
}
