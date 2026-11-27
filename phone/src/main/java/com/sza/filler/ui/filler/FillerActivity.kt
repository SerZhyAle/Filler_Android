package com.sza.filler.ui.filler

import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.sza.filler.FillerApplication
import com.sza.filler.R
import com.sza.filler.databinding.ActivityFillerBinding
import com.sza.filler.databinding.DialogAboutBinding
import com.sza.filler.ui.help.HelpOpenManager
import com.sza.filler.ui.schedule.ScheduleActivity
import com.sza.filler.ui.theme.ColorThemePrefs
import kotlinx.coroutines.launch

// Ported from FastMediaSorter release 48 (ui/filler/FillerActivity.kt, S4521). Deliberate differences:
// - the app's only screen and its launcher entry, an AppCompatActivity: the source's base screen, Hilt, its
//   navigating toolbar and its help entry belong to FastMediaSorter. What the base screen did for this screen
//   is done here: edge-to-edge insets, the saved colour theme overlay (FILLER-0067), the lifecycle-bound
//   collection and the first focus on Start for a keyboard or D-pad. The source registers no help page for
//   this screen (help map form "none"); this app gives it a help layer (S0028: CONTEXT-HELP rule 4 allows no
//   "none" for a main window), opened by the "?" action of the toolbar and by F1 through HelpOpenManager, the
//   one entry of the help map;
// - the reserve slider listener (owner order of 2026-11-13, S0005), which forwards the user's moves only. The
//   slider and its listener live and die with this activity's views, so the source's removal in onDestroy
//   has nothing to guard here;
// - the entries of a bigger app are not carried (S0012): the programs menu, the quick-access panel with its
//   route guard, availability rule and accent colour, the launcher-desktop cell and the system shortcut give way
//   to the launcher icon, and the on/off switch of S4542 with its backup, exchange, preset and Enable-all
//   carriage has nothing to hide here. Leftover files stay reachable because this screen always is;
// - the Schedules action of the toolbar opens the scheduled fill (S0025), the Color theme action switches
//   between FastMediaSorter's light, dark and six custom accent themes (FILLER-0067), and a first start of this
//   screen queues the next slot of every saved schedule (idempotent; the boot receiver does the same after a
//   restart);
// - the About action of the toolbar opens this app's own About window (ABOUT-PAGE, FILLER-0075): the source's
//   About lives in the settings of the bigger app, which this app does not carry.

/** The Filler screen: view wiring only, the run lives in [FillerViewModel]. */
class FillerActivity : AppCompatActivity() {

    private val viewModel: FillerViewModel by viewModels { FillerViewModel.Factory }

    private lateinit var binding: ActivityFillerBinding

    private lateinit var screen: FillerScreenManager

    /** True until Start has taken the first focus once; a recreated screen keeps the focus the user left. */
    private var initialFocusPending = false

    // help-surface: SystemFolderPicker
    private val folderPicker = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        uri?.let { viewModel.onFolderPicked(it.toString()) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        ColorThemePrefs.applyThemeOverlay(this)
        binding = ActivityFillerBinding.inflate(layoutInflater)
        setContentView(binding.root)
        applySystemBarInsets()
        installHelpAction()
        screen = FillerScreenManager(this, binding)
        initialFocusPending = savedInstanceState == null
        if (savedInstanceState == null) {
            val app = application as FillerApplication
            app.applicationScope.launch { app.queueSchedules() }
        }
        binding.btnFillerChooseFolder.setOnClickListener { folderPicker.launch(null) }
        binding.btnFillerStart.setOnClickListener { screen.confirmStart(viewModel.state.value, viewModel::start) }
        binding.btnFillerCancel.setOnClickListener { viewModel.cancel() }
        binding.btnFillerResume.setOnClickListener { viewModel.resume() }
        binding.btnFillerRetryCleanup.setOnClickListener { viewModel.retryCleanup() }
        binding.sliderFillerReserve.addOnChangeListener { _, stop, fromUser ->
            if (fromUser) FillerUiState.RESERVE_CHOICES_BYTES.getOrNull(stop.toInt())?.let(viewModel::chooseReserve)
        }
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.state.collect { state ->
                    screen.render(state)
                    focusStartOnce(state)
                }
            }
        }
    }

    /** F1 on a hardware keyboard opens the same help as the toolbar action, at the focused element's entry. */
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_F1 && HelpOpenManager.open(this, HELP_SURFACE_ID, currentFocus)) return true
        return super.onKeyDown(keyCode, event)
    }

    /** The help action stands only where the map gives this screen help; its tooltip names the key where one exists. */
    private fun installHelpAction() {
        binding.toolbar.inflateMenu(R.menu.menu_filler_schedule)
        binding.toolbar.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                R.id.action_schedules -> {
                    startActivity(Intent(this, ScheduleActivity::class.java))
                    true
                }
                R.id.action_theme -> {
                    showThemePicker()
                    true
                }
                R.id.action_about -> {
                    showAbout()
                    true
                }
                R.id.action_help -> HelpOpenManager.open(this, HELP_SURFACE_ID)
                else -> false
            }
        }
        if (!HelpOpenManager.hasHelp(this, HELP_SURFACE_ID)) return
        binding.toolbar.inflateMenu(R.menu.menu_filler_help)
        val hasKeyboard = resources.configuration.keyboard != Configuration.KEYBOARD_NOKEYS
        binding.toolbar.menu.findItem(R.id.action_help)?.let { item ->
            item.tooltipText = getString(if (hasKeyboard) R.string.help_with_key else R.string.help)
        }
    }

    private fun showThemePicker() {
        val currentMode = ColorThemePrefs.getMode(this)
        val currentIndex = ColorThemePrefs.ALL_MODES.indexOf(currentMode).coerceAtLeast(0)
        // help-surface: FillerThemeDialog
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.filler_theme)
            .setSingleChoiceItems(R.array.color_theme_options, currentIndex) { dialog, which ->
                val chosen = ColorThemePrefs.ALL_MODES.getOrElse(which) { ColorThemePrefs.DEFAULT }
                dialog.dismiss()
                if (chosen != currentMode) {
                    ColorThemePrefs.setMode(this, chosen)
                    Log.d("Probe", "FILLER-0067: color theme switched to $chosen")
                    ColorThemePrefs.applyMode(chosen)
                    recreate()
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    /**
     * The About window: the description, the version this install was built with, the author block, and the way to
     * the screen's help. Showing it contacts nothing; the site opens only when its address is tapped.
     */
    private fun showAbout() {
        Log.d("Probe", "FILLER-0075: phone About opened")
        Log.d("Probe", "FILLER-0076: phone About with the watch app mention opened")
        // help-surface: FillerAboutDialog
        val builder = MaterialAlertDialogBuilder(this)
        val about = DialogAboutBinding.inflate(LayoutInflater.from(builder.context))
        // The overload with flag objects needs API 33.
        @Suppress("DEPRECATION")
        val version = packageManager.getPackageInfo(packageName, 0).versionName.orEmpty()
        about.txtAboutVersion.text = getString(R.string.filler_about_version, version)
        about.txtAboutAuthor.text =
            getString(R.string.filler_about_author, getString(R.string.filler_about_author_name))
        builder
            .setTitle(R.string.filler_about)
            .setView(about.root)
            .setNeutralButton(R.string.help) { _, _ -> HelpOpenManager.open(this, HELP_SURFACE_ID) }
            .setPositiveButton(android.R.string.ok, null)
            .show()
    }

    /** Start is the obvious next action once the default place is measured; a disabled button cannot hold focus. */
    private fun focusStartOnce(state: FillerUiState) {
        if (initialFocusPending && state.canStart) {
            initialFocusPending = false
            binding.btnFillerStart.requestFocus()
        }
    }

    private fun applySystemBarInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
    }

    private companion object {
        /** The row of this screen in the help map (assets/help/help-map.json). */
        const val HELP_SURFACE_ID = "FillerActivity"
    }
}
