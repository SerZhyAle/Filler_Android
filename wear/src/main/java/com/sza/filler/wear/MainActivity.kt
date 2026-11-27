package com.sza.filler.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.text.format.DateUtils
import android.text.format.Formatter
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.sza.filler.domain.filler.FILLER_RESERVE_BYTES
import com.sza.filler.wear.run.FillerRunService
import com.sza.filler.wear.ui.WatchFillerOutcome
import com.sza.filler.wear.ui.WatchFillerState
import kotlinx.coroutines.launch

/**
 * The watch Filler screen and the launcher entry of the watch app (S0019), designed from the phone's FillerActivity
 * and FillerScreenManager for a small round screen: one column the rotary input scrolls, the reserve moved one of
 * the phone's seven stops at a time with two buttons, and the phone's confirmation dialog as a view of the same
 * column (S0017 research note section 7, row 5). Choosing another folder is not offered (row 2). The run itself is
 * held by [FillerRunService], so leaving this screen does not stop it; Stop does, and deletes what it wrote. The
 * About button of the start view opens the About view of the same column (ABOUT-PAGE, FILLER-0075).
 */
class MainActivity : ComponentActivity() {

    private val controller by lazy { (application as FillerWearApplication).controller }

    /** True while the confirmation is shown; it holds no operation state, so it is the screen's own. */
    private var confirming = false

    /** True while the About view is shown. */
    private var showingAbout = false

    private lateinit var scroll: ScrollView
    private lateinit var startGroup: View
    private lateinit var confirmGroup: View
    private lateinit var aboutGroup: View
    private lateinit var runGroup: View
    private lateinit var cleanupGroup: View
    private lateinit var location: TextView
    private lateinit var freeSpace: TextView
    private lateinit var reserve: TextView
    private lateinit var reserveLess: Button
    private lateinit var reserveMore: Button
    private lateinit var start: Button
    private lateinit var confirmMessage: TextView
    private lateinit var progress: ProgressBar
    private lateinit var progressText: TextView
    private lateinit var estimate: TextView
    private lateinit var result: TextView

    private val closeConfirmation = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            confirming = false
            render(controller.state.value)
        }
    }

    private val closeAbout = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            showAbout(false)
        }
    }

    /** The run starts whatever the answer: the permission only lets its progress line be shown. */
    // help-surface: SystemNotificationPermission
    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) {
        controller.start()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        bindViews()
        confirming = savedInstanceState?.getBoolean(KEY_CONFIRMING) ?: false
        onBackPressedDispatcher.addCallback(this, closeConfirmation)
        showingAbout = savedInstanceState?.getBoolean(KEY_ABOUT) ?: false
        onBackPressedDispatcher.addCallback(this, closeAbout)
        fillAbout()
        findViewById<Button>(R.id.btnFillerAbout).setOnClickListener {
            Log.d("Probe", "FILLER-0075: watch About opened")
            Log.d("Probe", "FILLER-0076: watch About with the phone app mention opened")
            showAbout(true)
        }
        findViewById<Button>(R.id.btnFillerAboutClose).setOnClickListener { showAbout(false) }
        start.setOnClickListener {
            if (controller.state.value.canStart) {
                confirming = true
                render(controller.state.value)
                scroll.scrollTo(0, 0)
            }
        }
        findViewById<Button>(R.id.btnFillerConfirm).setOnClickListener {
            confirming = false
            if (needsNotificationPermission()) {
                notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                controller.start()
            }
        }
        findViewById<Button>(R.id.btnFillerConfirmCancel).setOnClickListener {
            confirming = false
            render(controller.state.value)
        }
        reserveLess.setOnClickListener { controller.stepReserve(-1) }
        reserveMore.setOnClickListener {
            Log.d("Probe", "FILLER-0077: watch reserve raise button tapped")
            controller.stepReserve(1)
        }
        findViewById<Button>(R.id.btnFillerCancel).setOnClickListener { controller.cancel() }
        findViewById<Button>(R.id.btnFillerRetryCleanup).setOnClickListener { controller.retryCleanup() }
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                controller.state.collect { render(it) }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        controller.refresh()
    }

    /** The scrolling column takes the focus, so the rotary input scrolls it. */
    override fun onResume() {
        super.onResume()
        scroll.requestFocus()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(KEY_CONFIRMING, confirming)
        outState.putBoolean(KEY_ABOUT, showingAbout)
    }

    /** The version is the one this install was built with, and the author's name is the same in every locale. */
    private fun fillAbout() {
        // The overload with flag objects needs API 33.
        @Suppress("DEPRECATION")
        val version = packageManager.getPackageInfo(packageName, 0).versionName.orEmpty()
        findViewById<TextView>(R.id.txtFillerAboutVersion).text = getString(R.string.filler_about_version, version)
        findViewById<TextView>(R.id.txtFillerAboutAuthor).text =
            getString(R.string.filler_about_author, getString(R.string.filler_about_author_name))
    }

    /** Opens or closes the About view; showing it contacts nothing. */
    private fun showAbout(shown: Boolean) {
        showingAbout = shown
        render(controller.state.value)
        scroll.scrollTo(0, 0)
    }

    private fun bindViews() {
        scroll = findViewById(R.id.scrollFiller)
        startGroup = findViewById(R.id.fillerStartGroup)
        confirmGroup = findViewById(R.id.fillerConfirmGroup)
        aboutGroup = findViewById(R.id.fillerAboutGroup)
        runGroup = findViewById(R.id.fillerRunGroup)
        cleanupGroup = findViewById(R.id.fillerCleanupGroup)
        location = findViewById(R.id.txtFillerLocation)
        freeSpace = findViewById(R.id.txtFillerFreeSpace)
        reserve = findViewById(R.id.txtFillerReserve)
        reserveLess = findViewById(R.id.btnFillerReserveLess)
        reserveMore = findViewById(R.id.btnFillerReserveMore)
        start = findViewById(R.id.btnFillerStart)
        confirmMessage = findViewById(R.id.txtFillerConfirmMessage)
        progress = findViewById(R.id.progressFiller)
        progressText = findViewById(R.id.txtFillerProgress)
        estimate = findViewById(R.id.txtFillerEstimate)
        result = findViewById(R.id.txtFillerResult)
    }

    private fun render(state: WatchFillerState) {
        if (state.running) {
            confirming = false
            showingAbout = false
        }
        val showConfirm = confirming
        // The start view and what stands under it give way to a run, the confirmation or the About view.
        val idle = !state.running && !showConfirm && !showingAbout
        closeConfirmation.isEnabled = showConfirm
        closeAbout.isEnabled = showingAbout
        startGroup.visible(idle)
        confirmGroup.visible(showConfirm)
        aboutGroup.visible(showingAbout)
        runGroup.visible(state.running)
        cleanupGroup.visible(state.pending && idle)

        val place = state.place
        location.text = place?.let { getString(R.string.filler_location, it.volumeName) }
            ?: getString(R.string.filler_no_place)
        freeSpace.visible(place != null)
        freeSpace.text = state.availableBytes?.let { getString(R.string.filler_free_space, size(it)) }
            ?: getString(R.string.filler_free_space_unknown)
        reserve.text = getString(R.string.filler_reserve, size(state.reserveBytes))
        reserveLess.isEnabled = state.canLowerReserve
        reserveMore.isEnabled = state.canRaiseReserve
        start.isEnabled = state.canStart

        if (showConfirm) confirmMessage.text = confirmationText(state)
        if (state.running) renderRun(state)

        val message = state.outcome?.let(::messageFor)
        result.visible(message != null && idle)
        message?.let { result.text = getString(it, size(state.writtenBytes)) }
    }

    /** The phone's confirmation content: amount, place and reserve, and the paragraph for a lowered reserve. */
    private fun confirmationText(state: WatchFillerState): String {
        val planned = (state.availableBytes ?: 0) - state.reserveBytes
        val message = getString(R.string.filler_confirm_message, size(planned), size(state.reserveBytes))
        val loweredNote = if (state.reserveBytes < FILLER_RESERVE_BYTES) {
            getString(R.string.filler_confirm_reserve_lowered, size(FILLER_RESERVE_BYTES))
        } else {
            null
        }
        return listOfNotNull(message, loweredNote).joinToString("\n\n")
    }

    private fun renderRun(state: WatchFillerState) {
        val planned = state.plannedBytes.coerceAtLeast(1)
        progress.progress = (state.writtenBytes * PROGRESS_SCALE / planned).toInt().coerceIn(0, PROGRESS_SCALE)
        progressText.text = getString(R.string.filler_progress, size(state.writtenBytes), size(state.plannedBytes))
        estimate.text = state.remainingMillis?.let {
            getString(
                R.string.filler_estimate,
                state.percentDone,
                DateUtils.formatElapsedTime(FillerRunService.secondsFor(it)),
            )
        } ?: getString(R.string.filler_estimate_calculating, state.percentDone)
    }

    private fun needsNotificationPermission(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
        PackageManager.PERMISSION_GRANTED

    @StringRes
    private fun messageFor(outcome: WatchFillerOutcome): Int = when (outcome) {
        WatchFillerOutcome.DONE -> R.string.filler_result_done
        WatchFillerOutcome.CANCELLED -> R.string.filler_result_cancelled
        WatchFillerOutcome.FAILED -> R.string.filler_result_failed
        WatchFillerOutcome.CLEANUP_INCOMPLETE -> R.string.filler_result_cleanup_incomplete
        WatchFillerOutcome.CLEANUP_DONE -> R.string.filler_result_cleanup_done
        WatchFillerOutcome.NO_PLACE -> R.string.filler_result_no_place
        WatchFillerOutcome.NO_ACCESS -> R.string.filler_result_no_access
        WatchFillerOutcome.MEASUREMENT_UNAVAILABLE -> R.string.filler_result_measurement_unavailable
        WatchFillerOutcome.INSUFFICIENT_SPACE -> R.string.filler_result_insufficient_space
        WatchFillerOutcome.BUSY -> R.string.filler_result_busy
        WatchFillerOutcome.NOT_STARTED -> R.string.filler_result_not_started
    }

    private fun size(bytes: Long): String = Formatter.formatShortFileSize(this, bytes)

    private fun View.visible(shown: Boolean) {
        visibility = if (shown) View.VISIBLE else View.GONE
    }

    private companion object {
        const val KEY_CONFIRMING = "filler_confirming"
        const val KEY_ABOUT = "filler_about"
        const val PROGRESS_SCALE = 1000
    }
}
