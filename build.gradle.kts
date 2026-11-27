import com.sza.filler.buildlogic.VersionStamp
import java.time.LocalDateTime

// The Android Gradle Plugin is put on the classpath once, here, and applied by the module. AGP 9 carries
// its own Kotlin support, so no Kotlin plugin is declared: the Kotlin version follows AGP.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
}

// PACKAGE-VERSIONING rule 6: the clock is read once per invocation, here, and `:phone` and `:wear` both stamp
// from this one instant, so two apps built together cannot straddle a minute boundary. The root script is
// configured before its modules; the configuration cache stays off (gradle.properties) so it is never replayed.
extra["filler.buildInstant"] = VersionStamp.instantOfClock(LocalDateTime.now())

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
