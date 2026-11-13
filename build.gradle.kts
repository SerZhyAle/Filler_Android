// The Android Gradle Plugin is put on the classpath once, here, and applied by the module. AGP 9 carries
// its own Kotlin support, so no Kotlin plugin is declared: the Kotlin version follows AGP.
plugins {
    alias(libs.plugins.android.application) apply false
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
