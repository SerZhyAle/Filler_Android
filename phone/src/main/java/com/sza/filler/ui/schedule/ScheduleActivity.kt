package com.sza.filler.ui.schedule

import android.Manifest
import android.app.TimePickerDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.format.DateFormat
import android.text.format.DateUtils
import android.text.format.Formatter
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.annotation.StringRes
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.isVisible
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.snackbar.Snackbar
import com.sza.filler.R
import com.sza.filler.data.schedule.FillHistoryEntry
import com.sza.filler.data.schedule.FillSchedule
import com.sza.filler.data.schedule.FillScheduleData
import com.sza.filler.data.schedule.FillScheduleSlots
import com.sza.filler.databinding.ActivityScheduleBinding
import com.sza.filler.databinding.ItemFillHistoryBinding
import com.sza.filler.databinding.ItemFillScheduleBinding
import com.sza.filler.domain.filler.FILLER_RESERVE_BYTES
import com.sza.filler.domain.filler.FillerPlace
import com.sza.filler.domain.filler.ScheduledFillOutcome
import com.sza.filler.domain.filler.ScheduledFillReason
import com.sza.filler.ui.help.HelpOpenManager
import com.sza.filler.ui.theme.ColorThemePrefs
import kotlinx.coroutines.launch
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

// This product's own (S0025, aligned with FastMediaSorter's ScheduledOperationsActivity controls in FILLER-0067):
// FastMediaSorter's schedule screens (ui/scheduledops/) serve every operation type; this screen lists the Filler's
// schedules as cards with Run now, Pause/Resume all, Clear history, and an API 33+ notification-permission recovery
// button while keeping inline editing, confirmFill validation, and the 24 dp square checkbox (BOOLEAN-OPTION 2.2).

/** The schedules of the scheduled fill and the history of their runs. */
class ScheduleActivity : AppCompatActivity() {

    private val viewModel: ScheduleViewModel by viewModels { ScheduleViewModel.Factory }

    private lateinit var binding: ActivityScheduleBinding

    private var requestedFromButton = false

    // help-surface: SystemFolderPicker
    private val folderPicker = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        uri?.let { viewModel.onFolderPicked(it.toString()) }
    }

    // The notification of a running scheduled fill is visible only with this permission on Android 13 and later; a
    // refusal changes nothing else - the fill still runs and its history is written.
    // help-surface: SystemNotificationPermission
    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val openSettings = !granted && requestedFromButton && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
        requestedFromButton = false
        updateNotificationPermissionButton()
        if (openSettings) openNotificationSettings()
    }

    private val timeFormat: DateTimeFormatter = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        ColorThemePrefs.applyThemeOverlay(this)
        binding = ActivityScheduleBinding.inflate(layoutInflater)
        setContentView(binding.root)
        applySystemBarInsets()
        installToolbar()
        binding.txtScheduleIntro.text = getString(R.string.schedule_intro, size(FILLER_RESERVE_BYTES))
        binding.btnScheduleNotifications.setOnClickListener { requestNotificationsFromButton() }
        binding.btnScheduleAdd.setOnClickListener { viewModel.startNew() }
        binding.btnSchedulePauseAll.setOnClickListener { viewModel.togglePauseAll() }
        binding.btnScheduleClearHistory.setOnClickListener { confirmClearHistory() }
        binding.btnScheduleChooseFolder.setOnClickListener { folderPicker.launch(null) }
        binding.btnScheduleTime.setOnClickListener { pickTime() }
        binding.btnScheduleRepeat.setOnClickListener { pickInterval() }
        binding.btnScheduleCancel.setOnClickListener { viewModel.cancelDraft() }
        binding.btnScheduleSave.setOnClickListener { confirmSave() }
        updateNotificationPermissionButton()
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch { viewModel.data.collect(::renderData) }
                launch { viewModel.draft.collect(::renderDraft) }
                launch {
                    viewModel.notUsable.collect { shown ->
                        if (shown) {
                            Snackbar.make(binding.root, R.string.schedule_not_usable, Snackbar.LENGTH_LONG).show()
                            viewModel.notUsableShown()
                        }
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        updateNotificationPermissionButton()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_F1 && HelpOpenManager.open(this, HELP_SURFACE_ID, currentFocus)) return true
        return super.onKeyDown(keyCode, event)
    }

    private fun installToolbar() {
        binding.toolbar.setUpNavigation(this)
        Log.d("Probe", "FILLER-0078: schedule toolbar title=${binding.toolbar.title}")
        if (!HelpOpenManager.hasHelp(this, HELP_SURFACE_ID)) return
        binding.toolbar.inflateMenu(R.menu.menu_filler_help)
        val hasKeyboard = resources.configuration.keyboard != Configuration.KEYBOARD_NOKEYS
        binding.toolbar.menu.findItem(R.id.action_help)?.let { item ->
            item.tooltipText = getString(if (hasKeyboard) R.string.help_with_key else R.string.help)
        }
        binding.toolbar.setOnMenuItemClickListener { item ->
            item.itemId == R.id.action_help && HelpOpenManager.open(this, HELP_SURFACE_ID)
        }
    }

    private fun updateNotificationPermissionButton() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            binding.btnScheduleNotifications.isVisible = false
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        binding.btnScheduleNotifications.isVisible = !granted
    }

    private fun requestNotificationsFromButton() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        requestedFromButton = true
        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            val fallback = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
            try {
                startActivity(fallback)
            } catch (e: ActivityNotFoundException) {
                Log.w(LOG_TAG, "No system notification settings activity available", e)
            }
        }
    }

    private fun renderData(data: FillScheduleData) {
        binding.txtScheduleEmpty.isVisible = data.schedules.isEmpty()
        binding.btnSchedulePauseAll.isVisible = data.schedules.isNotEmpty()
        binding.btnSchedulePauseAll.setText(
            if (data.paused) R.string.schedule_resume_all else R.string.schedule_pause_all,
        )
        binding.btnSchedulePauseAll.setIconResource(
            if (data.paused) R.drawable.ic_action_run else R.drawable.ic_media_pause,
        )
        binding.scheduleList.removeAllViews()
        val now = System.currentTimeMillis()
        data.schedules.forEach { schedule -> binding.scheduleList.addView(scheduleRow(schedule, data.paused, now)) }
        binding.txtScheduleHistoryEmpty.isVisible = data.history.isEmpty()
        binding.btnScheduleClearHistory.isVisible = data.history.isNotEmpty()
        binding.historyList.removeAllViews()
        data.history.forEach { entry -> binding.historyList.addView(historyRow(entry)) }
    }

    private fun scheduleRow(schedule: FillSchedule, allPaused: Boolean, now: Long) =
        ItemFillScheduleBinding.inflate(LayoutInflater.from(this), binding.scheduleList, false).apply {
            txtSchedulePlace.text = getString(R.string.filler_location, schedule.folderName, schedule.volumeName)
            txtScheduleWhen.text = getString(
                R.string.schedule_item_when,
                getString(intervalText(schedule.intervalDays)),
                time(schedule.minuteOfDay),
            )
            txtScheduleStatus.text = when {
                !schedule.enabled -> getString(R.string.schedule_item_off)
                allPaused -> getString(R.string.schedule_item_paused)
                else -> getString(R.string.schedule_item_next, dateTime(FillScheduleSlots.nextSlot(schedule, now)))
            }
            checkScheduleEnabled.isChecked = schedule.enabled
            checkScheduleEnabled.setOnCheckedChangeListener { _, checked -> viewModel.setEnabled(schedule, checked) }
            // BOOLEAN-OPTION section 3 rule 4 (S0045): Space toggles the focused enabled checkbox and focusing alone
            // changes nothing. The framework's CheckBox answers Enter and D-pad centre on its own; Space is wired here
            // so the press never reaches the hosting scroll, and a press that turns into a scroll (isCanceled) does not
            // toggle.
            checkScheduleEnabled.setOnKeyListener { view, keyCode, event ->
                if (keyCode != KeyEvent.KEYCODE_SPACE) false else {
                    if (event.action == KeyEvent.ACTION_UP && !event.isCanceled) view.performClick()
                    true
                }
            }
            btnScheduleRunNow.setOnClickListener {
                viewModel.runNow(schedule)
                Snackbar.make(
                    binding.root,
                    getString(R.string.schedule_run_now_started, schedule.folderName),
                    Snackbar.LENGTH_SHORT,
                ).show()
            }
            btnScheduleEdit.setOnClickListener { viewModel.edit(schedule) }
            btnScheduleDelete.setOnClickListener { confirmDelete(schedule) }
        }.root

    private fun historyRow(entry: FillHistoryEntry) =
        ItemFillHistoryBinding.inflate(LayoutInflater.from(this), binding.historyList, false).apply {
            txtHistoryHead.text = getString(
                R.string.schedule_history_head,
                dateTime(entry.startedAt),
                getString(R.string.filler_location, entry.folderName, entry.volumeName),
            )
            txtHistoryResult.text = if (entry.outcome == ScheduledFillOutcome.OK) {
                getString(R.string.filler_result_done, size(entry.writtenBytes))
            } else {
                getString(reasonText(entry.reason))
            }
            val lateMinutes = (entry.startedAt - entry.dueAt) / MILLIS_PER_MINUTE
            txtHistoryLate.isVisible = entry.dueAt > 0 && entry.startedAt - entry.dueAt > FillScheduleSlots.LATE_AFTER_MILLIS
            if (txtHistoryLate.isVisible) txtHistoryLate.text = getString(R.string.schedule_history_late, lateMinutes.toInt())
        }.root

    private fun renderDraft(draft: ScheduleDraft?) {
        binding.scheduleEditor.isVisible = draft != null
        binding.btnScheduleAdd.isVisible = draft == null
        if (draft == null) return
        binding.txtScheduleEditorTitle.setText(
            if (draft.editingId == null) R.string.schedule_editor_new else R.string.schedule_editor_change,
        )
        binding.txtScheduleEditorPlace.text = draft.place?.let {
            getString(R.string.filler_location, it.folderName, it.volumeName)
        } ?: getString(R.string.filler_no_folder)
        binding.btnScheduleTime.text = getString(R.string.schedule_editor_time, time(draft.minuteOfDay))
        binding.btnScheduleRepeat.text = getString(R.string.schedule_editor_repeat, getString(intervalText(draft.intervalDays)))
        binding.btnScheduleSave.isEnabled = draft.place != null
    }

    private fun pickTime() {
        val draft = viewModel.draft.value ?: return
        // help-surface: SystemTimePicker
        TimePickerDialog(
            this,
            { _, hour, minute -> viewModel.setTime(hour * 60 + minute) },
            draft.minuteOfDay / 60,
            draft.minuteOfDay % 60,
            DateFormat.is24HourFormat(this),
        ).show()
    }

    private fun pickInterval() {
        val draft = viewModel.draft.value ?: return
        val choices = FillScheduleSlots.INTERVAL_CHOICES
        // help-surface: ScheduleRepeatDialog
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.schedule_editor_repeat_title)
            .setSingleChoiceItems(
                choices.map { getString(intervalText(it)) }.toTypedArray(),
                choices.indexOf(draft.intervalDays),
            ) { dialog, which ->
                viewModel.setInterval(choices[which])
                dialog.dismiss()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    /** The source's confirmFill: refused unless the place is usable now, then a confirmation naming the reserve. */
    private fun confirmSave() {
        lifecycleScope.launch {
            val place = viewModel.usableDraftPlace() ?: return@launch
            // help-surface: ScheduleConfirmDialog
            MaterialAlertDialogBuilder(this@ScheduleActivity)
                .setTitle(R.string.scheduled_ops_fill_confirm_title)
                .setMessage(confirmMessage(place))
                .setPositiveButton(R.string.schedule_editor_save) { _, _ ->
                    viewModel.commit(place)
                    askForNotifications()
                }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
        }
    }

    private fun confirmMessage(place: FillerPlace): String =
        getString(R.string.scheduled_ops_fill_confirm_message, place.folderName, place.volumeName, size(FILLER_RESERVE_BYTES)) +
            "\n\n" + getString(R.string.schedule_confirm_cap)

    private fun confirmDelete(schedule: FillSchedule) {
        // help-surface: ScheduleDeleteDialog
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.schedule_delete_title)
            .setMessage(getString(R.string.schedule_delete_message, schedule.folderName, schedule.volumeName))
            .setPositiveButton(R.string.schedule_delete) { _, _ -> viewModel.delete(schedule) }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun confirmClearHistory() {
        // help-surface: ScheduleClearHistoryDialog
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.schedule_history_clear_title)
            .setMessage(R.string.schedule_history_clear_message)
            .setPositiveButton(R.string.schedule_history_clear) { _, _ -> viewModel.clearHistory() }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestedFromButton = false
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private fun applySystemBarInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
    }

    private fun size(bytes: Long): String = Formatter.formatShortFileSize(this, bytes)

    private fun time(minuteOfDay: Int): String = LocalTime.of(minuteOfDay / 60, minuteOfDay % 60).format(timeFormat)

    private fun dateTime(millis: Long): String = DateUtils.formatDateTime(
        this,
        millis,
        DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_SHOW_TIME or DateUtils.FORMAT_SHOW_WEEKDAY or
            DateUtils.FORMAT_ABBREV_WEEKDAY,
    )

    private companion object {
        /** The row of this screen in the help map (assets/help/help-map.json). */
        const val HELP_SURFACE_ID = "ScheduleActivity"

        const val LOG_TAG = "ScheduleActivity"

        const val MILLIS_PER_MINUTE = 60_000L

        @StringRes
        fun intervalText(days: Int): Int = when (days) {
            1 -> R.string.schedule_interval_1
            2 -> R.string.schedule_interval_2
            3 -> R.string.schedule_interval_3
            7 -> R.string.schedule_interval_7
            14 -> R.string.schedule_interval_14
            else -> R.string.schedule_interval_30
        }

        @StringRes
        fun reasonText(reason: ScheduledFillReason?): Int = when (reason) {
            ScheduledFillReason.FILL_BUSY -> R.string.scheduled_op_reason_fill_busy
            ScheduledFillReason.FILL_NOT_LOCAL -> R.string.scheduled_op_reason_fill_not_local
            ScheduledFillReason.FILL_STORAGE_UNAVAILABLE -> R.string.scheduled_op_reason_fill_storage_unavailable
            ScheduledFillReason.FILL_MEASUREMENT_UNAVAILABLE -> R.string.scheduled_op_reason_fill_measurement_unavailable
            ScheduledFillReason.FILL_NO_FREE_SPACE -> R.string.scheduled_op_reason_fill_no_free_space
            ScheduledFillReason.FILL_WRITE_FAILED -> R.string.scheduled_op_reason_fill_write_failed
            ScheduledFillReason.FILL_CLEANUP_PENDING -> R.string.scheduled_op_reason_fill_cleanup_pending
            ScheduledFillReason.FILL_DAILY_CAP -> R.string.scheduled_op_reason_fill_daily_cap
            ScheduledFillReason.FILL_STOPPED -> R.string.scheduled_op_reason_fill_stopped
            null -> R.string.scheduled_op_reason_unknown
        }
    }
}
