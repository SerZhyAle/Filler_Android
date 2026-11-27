package com.sza.filler.buildlogic

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class ReleaseSigningTest {
    @get:Rule
    val temp = TemporaryFolder()

    private fun keyFolder(lines: List<String>): File {
        val dir = temp.newFolder("keys")
        File(dir, "filler-upload.jks").writeText("not a real key store")
        return File(dir, "keystore.properties").apply { writeText(lines.joinToString("\n")) }
    }

    private val complete = listOf(
        "storeFile=filler-upload.jks",
        "storePassword=secret1",
        "keyAlias=filler-upload",
        "keyPassword=secret2",
    )

    @Test
    fun noEnvironmentAndNoRootFileIsNoKey() {
        assertNull(ReleaseSigning.load(null, temp.root))
        assertNull(ReleaseSigning.load("", temp.root))
    }

    @Test
    fun environmentNamesTheFileAndTheStoreResolvesBesideIt() {
        val props = keyFolder(complete)
        val key = ReleaseSigning.load(props.path, temp.root)!!
        assertEquals(File(props.parentFile, "filler-upload.jks").canonicalPath, key.storeFile.canonicalPath)
        assertEquals("secret1", key.storePassword)
        assertEquals("filler-upload", key.keyAlias)
        assertEquals("secret2", key.keyPassword)
    }

    @Test
    fun rootFileIsFoundWithoutTheEnvironment() {
        val props = keyFolder(complete)
        props.copyTo(File(temp.root, ReleaseSigning.ROOT_FILE))
        File(props.parentFile, "filler-upload.jks").copyTo(File(temp.root, "filler-upload.jks"))
        assertEquals("filler-upload", ReleaseSigning.load(null, temp.root)!!.keyAlias)
    }

    @Test
    fun aNamedFileThatIsMissingIsRefused() {
        assertThrows(IllegalArgumentException::class.java) {
            ReleaseSigning.load(File(temp.root, "absent.properties").path, temp.root)
        }
    }

    @Test
    fun aMissingEntryOrStoreIsRefused() {
        val noAlias = keyFolder(complete.filterNot { it.startsWith("keyAlias=") })
        assertThrows(IllegalArgumentException::class.java) { ReleaseSigning.read(noAlias) }
        File(noAlias.parentFile, "keystore.properties").writeText(
            complete.map { if (it.startsWith("storeFile=")) "storeFile=elsewhere.jks" else it }.joinToString("\n"),
        )
        assertThrows(IllegalArgumentException::class.java) { ReleaseSigning.read(noAlias) }
    }
}
