package com.sza.filler.ui.help

import androidx.annotation.DrawableRes
import androidx.annotation.IdRes
import androidx.annotation.StringRes
import com.sza.filler.R

/**
 * One entry of a help layer (contract `CONTEXT-HELP` rule 6): the element's anchor, the view it marks (null for a part
 * the screen does not draw itself, such as the confirmation it opens), its one-line label and its fuller text. Both
 * texts are the app's strings, so a renamed control is renamed in its help by the same edit (rule 13). [glyph] is the
 * drawable the control itself shows, drawn beside its name in the list (`ICON-SET` rule 8: the help shows the meaning's
 * glyph, never a substitute; FILLER-0059); null for an entry that names no glyph-bearing control.
 */
data class HelpLayerEntry(
    val anchor: String,
    @IdRes val viewId: Int?,
    @StringRes val label: Int,
    @StringRes val text: Int,
    @DrawableRes val glyph: Int? = null,
)

/** The layer entries of each help id of the map, in marker order (S0028, FILLER-0067). */
object HelpLayerContent {

    const val FILLER = "filler"

    private val filler = listOf(
        HelpLayerEntry("place", R.id.txtFillerLocation, R.string.filler_help_place_label, R.string.filler_help_place_text),
        HelpLayerEntry(
            "choose-folder",
            R.id.btnFillerChooseFolder,
            R.string.filler_choose_folder,
            R.string.filler_help_choose_folder_text,
            R.drawable.ic_action_choose_folder,
        ),
        HelpLayerEntry(
            "free-space",
            R.id.txtFillerFreeSpace,
            R.string.filler_help_free_space_label,
            R.string.filler_help_free_space_text,
        ),
        HelpLayerEntry(
            "reserve",
            R.id.sliderFillerReserve,
            R.string.filler_reserve_slider_description,
            R.string.filler_help_reserve_text,
        ),
        HelpLayerEntry(
            "start",
            R.id.btnFillerStart,
            R.string.filler_start,
            R.string.filler_help_start_text,
            R.drawable.ic_action_fill_space,
        ),
        HelpLayerEntry("confirmation", null, R.string.filler_help_confirmation_label, R.string.filler_help_confirmation_text),
        HelpLayerEntry("progress", R.id.txtFillerProgress, R.string.filler_help_progress_label, R.string.filler_help_progress_text),
        HelpLayerEntry(
            "keep-open",
            R.id.txtFillerKeepOpen,
            R.string.filler_help_keep_open_label,
            R.string.filler_help_keep_open_text,
        ),
        HelpLayerEntry(
            "stop",
            R.id.btnFillerCancel,
            R.string.filler_cancel,
            R.string.filler_help_stop_text,
            R.drawable.ic_action_cancel,
        ),
        HelpLayerEntry(
            "resume",
            R.id.btnFillerResume,
            R.string.filler_resume,
            R.string.filler_help_resume_text,
            R.drawable.ic_action_fill_space,
        ),
        HelpLayerEntry(
            "cleanup",
            R.id.btnFillerRetryCleanup,
            R.string.filler_retry_cleanup,
            R.string.filler_help_cleanup_text,
            R.drawable.ic_action_delete,
        ),
        HelpLayerEntry("result", R.id.txtFillerResult, R.string.filler_help_result_label, R.string.filler_help_result_text),
        HelpLayerEntry(
            "schedules",
            R.id.action_schedules,
            R.string.schedule_open,
            R.string.filler_help_schedules_text,
            R.drawable.ic_app_schedule,
        ),
        HelpLayerEntry(
            "theme",
            R.id.action_theme,
            R.string.filler_theme,
            R.string.filler_help_theme_text,
            R.drawable.ic_app_theme,
        ),
        HelpLayerEntry(
            "about",
            R.id.action_about,
            R.string.filler_about,
            R.string.filler_help_about_text,
            R.drawable.ic_app_info,
        ),
        HelpLayerEntry("help", R.id.action_help, R.string.help, R.string.filler_help_help_text, R.drawable.ic_app_help),
        HelpLayerEntry("watch", null, R.string.filler_help_watch_label, R.string.filler_help_watch_text),
    )

    const val SCHEDULE = "schedule"

    // The schedule screen of the scheduled fill (S0025, FILLER-0067).
    private val schedule = listOf(
        HelpLayerEntry("intro", R.id.txtScheduleIntro, R.string.schedule_help_intro_label, R.string.schedule_help_intro_text),
        HelpLayerEntry(
            "notifications",
            R.id.btnScheduleNotifications,
            R.string.schedule_notifications_enable,
            R.string.schedule_help_notifications_text,
            R.drawable.ic_system_notification,
        ),
        HelpLayerEntry("add", R.id.btnScheduleAdd, R.string.schedule_add, R.string.schedule_help_add_text, R.drawable.ic_action_add),
        HelpLayerEntry(
            "pause-all",
            R.id.btnSchedulePauseAll,
            R.string.schedule_pause_all,
            R.string.schedule_help_pause_all_text,
            R.drawable.ic_media_pause,
        ),
        HelpLayerEntry("editor", R.id.scheduleEditor, R.string.schedule_help_editor_label, R.string.schedule_help_editor_text),
        HelpLayerEntry("schedules", R.id.scheduleList, R.string.schedule_help_list_label, R.string.schedule_help_list_text),
        HelpLayerEntry("history", R.id.txtScheduleHistoryTitle, R.string.schedule_history_title, R.string.schedule_help_history_text),
        HelpLayerEntry(
            "clear-history",
            R.id.btnScheduleClearHistory,
            R.string.schedule_history_clear,
            R.string.schedule_help_clear_history_text,
            R.drawable.ic_action_clear_all,
        ),
        HelpLayerEntry("help", R.id.action_help, R.string.help, R.string.filler_help_help_text, R.drawable.ic_app_help),
    )

    fun entries(helpId: String): List<HelpLayerEntry> = when (helpId) {
        FILLER -> filler
        SCHEDULE -> schedule
        else -> emptyList()
    }
}
