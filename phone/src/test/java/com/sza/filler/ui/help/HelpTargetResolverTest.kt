package com.sza.filler.ui.help

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

// New in this app (S0041): the source has no test for the inherit walk. The map is built in code, so no Android class is read.
class HelpTargetResolverTest {

    private fun layer(id: String, help: String = "filler", anchor: String? = null) =
        HelpSurface(id, id, HelpForm.LAYER, help, anchor, null, null)

    private fun inherit(id: String, parent: String?, anchor: String? = null) =
        HelpSurface(id, id, HelpForm.INHERIT, null, anchor, parent, "reason")

    private fun none(id: String) = HelpSurface(id, id, HelpForm.NONE, null, null, null, "reason")

    private fun resolver(vararg rows: HelpSurface) = HelpTargetResolver(HelpMap(1, rows.toList()))

    @Test
    fun `a layer row resolves to its own help id and anchor`() {
        val target = resolver(layer("Main", anchor = "start")).resolve("Main")
        assertEquals(HelpTarget("filler", HelpForm.LAYER, "start"), target)
    }

    @Test
    fun `an inherit row opens the anchor its own row names`() {
        val target = resolver(layer("Main"), inherit("Watch", "Main", anchor = "watch")).resolve("Watch")
        assertEquals(HelpTarget("filler", HelpForm.LAYER, "watch"), target)
    }

    @Test
    fun `an inherit row anchor wins over the anchor of the row that holds the help`() {
        val target = resolver(layer("Main", anchor = "start"), inherit("Watch", "Main", anchor = "watch")).resolve("Watch")
        assertEquals("watch", target?.anchor)
    }

    @Test
    fun `an inherit row without an anchor opens the anchor of the row that holds the help`() {
        val target = resolver(layer("Main", anchor = "start"), inherit("Watch", "Main")).resolve("Watch")
        assertEquals("start", target?.anchor)
    }

    @Test
    fun `an inherit row without an anchor opens the top when the help row names none`() {
        val target = resolver(layer("Main"), inherit("Watch", "Main")).resolve("Watch")
        assertEquals(HelpTarget("filler", HelpForm.LAYER, null), target)
    }

    @Test
    fun `a blank anchor is no anchor`() {
        val target = resolver(layer("Main", anchor = "start"), inherit("Watch", "Main", anchor = " ")).resolve("Watch")
        assertEquals("start", target?.anchor)
    }

    @Test
    fun `the nearest inherit row that names an anchor wins along a chain`() {
        val rows = arrayOf(layer("Main"), inherit("Mid", "Main", anchor = "mid"), inherit("Leaf", "Mid"))
        assertEquals("mid", resolver(*rows).resolve("Leaf")?.anchor)
        val own = arrayOf(layer("Main"), inherit("Mid", "Main", anchor = "mid"), inherit("Leaf", "Mid", anchor = "leaf"))
        assertEquals("leaf", resolver(*own).resolve("Leaf")?.anchor)
    }

    @Test
    fun `an element anchor wins over every row anchor`() {
        val target = resolver(layer("Main", anchor = "start"), inherit("Watch", "Main", anchor = "watch")).resolve("Watch", "reserve")
        assertEquals("reserve", target?.anchor)
    }

    @Test
    fun `an inherit chain that ends in none has no help`() {
        val r = resolver(none("Dialog"), inherit("Watch", "Dialog", anchor = "watch"))
        assertNull(r.resolve("Watch"))
        assertFalse(r.hasHelp("Watch"))
    }

    @Test
    fun `an inherit cycle has no help`() {
        val r = resolver(inherit("A", "B", anchor = "a"), inherit("B", "A", anchor = "b"))
        assertNull(r.resolve("A"))
    }

    @Test
    fun `an inherit row with a missing parent has no help`() {
        assertNull(resolver(inherit("Watch", "Nowhere", anchor = "watch")).resolve("Watch"))
        assertNull(resolver(inherit("Watch", null, anchor = "watch")).resolve("Watch"))
    }

    @Test
    fun `an unknown surface has no help`() {
        assertNull(resolver(layer("Main")).resolve("Other"))
    }
}
