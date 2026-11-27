package com.sza.filler.buildlogic

import java.io.File
import java.util.Properties

/**
 * The upload key a release package is signed with (S0023 G2; owner decision of 2026-11-13: Play App Signing with
 * the product's own app signing key plus a separate upload key). Both apps of the product (`:phone` and `:wear`)
 * go to Google Play only, so both are signed with the upload key and Play re-signs them with the app signing key.
 * The app signing key is never read by the build: the owner imports it into Play App Signing in the console.
 *
 * One properties file holds the key: named by the environment variable [ENV], or else `keystore.properties` at the
 * repository root (ignored by git). `tools/release/new-release-keys.ps1` writes it next to the key, outside the
 * tree. Keys: `storeFile` (relative to the properties file's folder, or absolute), `storePassword`, `keyAlias`,
 * `keyPassword`. No file means no key: the release package is built unsigned and the module warns.
 */
object ReleaseSigning {
    const val ENV = "FILLER_KEYSTORE_PROPERTIES"
    const val ROOT_FILE = "keystore.properties"

    data class UploadKey(
        val source: File,
        val storeFile: File,
        val storePassword: String,
        val keyAlias: String,
        val keyPassword: String,
    )

    /** The properties file in use: the one [envValue] names (it must exist), else the root file if present. */
    fun locate(envValue: String?, rootDir: File): File? {
        if (!envValue.isNullOrBlank()) {
            val named = File(envValue)
            require(named.isFile) { "$ENV names $envValue, which is not a file." }
            return named
        }
        return File(rootDir, ROOT_FILE).takeIf { it.isFile }
    }

    /** Reads the upload key; a missing entry or a missing key store is an error, never a silent unsigned build. */
    fun read(file: File): UploadKey {
        val props = Properties().apply { file.inputStream().use { load(it) } }
        fun value(name: String): String =
            props.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }
                ?: throw IllegalArgumentException("$file has no '$name'.")
        val store = File(value("storeFile")).let { if (it.isAbsolute) it else File(file.absoluteFile.parentFile, it.path) }
        require(store.isFile) { "$file names the key store $store, which does not exist." }
        return UploadKey(file, store, value("storePassword"), value("keyAlias"), value("keyPassword"))
    }

    fun load(envValue: String?, rootDir: File): UploadKey? = locate(envValue, rootDir)?.let(::read)
}
