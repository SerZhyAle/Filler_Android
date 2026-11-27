package com.sza.filler.data.filler

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/**
 * Atomic single-file store matching Android's `AtomicFile` `.new`/`.bak` recovery protocol while using
 * `Files.move(..., REPLACE_EXISTING)` so overwrites succeed on both Android and Windows Robolectric hosts.
 */
class AtomicStoreFile(private val baseFile: File) {
    private val newFile = File("${baseFile.path}.new")
    private val legacyBackupFile = File("${baseFile.path}.bak")

    fun readBytes(): ByteArray {
        if (legacyBackupFile.exists()) {
            moveReplacing(legacyBackupFile, baseFile)
        }
        if (newFile.exists() && baseFile.exists()) {
            newFile.delete()
        }
        return FileInputStream(baseFile).use { it.readBytes() }
    }

    fun writeBytes(bytes: ByteArray) {
        newFile.parentFile?.mkdirs()
        var complete = false
        try {
            FileOutputStream(newFile).use { out ->
                out.write(bytes)
                out.flush()
                runCatching { out.fd.sync() }
            }
            moveReplacing(newFile, baseFile)
            complete = true
        } finally {
            if (!complete) {
                newFile.delete()
            }
        }
    }

    private fun moveReplacing(source: File, target: File) {
        try {
            Files.move(
                source.toPath(),
                target.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE,
            )
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }
}
