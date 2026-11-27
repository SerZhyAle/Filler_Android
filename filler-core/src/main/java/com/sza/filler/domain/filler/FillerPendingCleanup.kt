package com.sza.filler.domain.filler

import kotlinx.coroutines.flow.StateFlow

/**
 * Whether the Filler journal still lists a session whose files are not deleted yet (FastMediaSorter S4542,
 * ported unchanged from its release 48).
 *
 * - True from the moment a session enters the journal until its cleanup finishes, so it is also true
 *   while a run is in progress.
 * - False until the first read of the journal file completes; an unreadable journal reads as true,
 *   because it may hide files awaiting deletion.
 * - Read synchronously by the availability decision, which is why this is a [StateFlow] and not a
 *   suspend call.
 */
interface FillerPendingCleanup {
    val hasPending: StateFlow<Boolean>
}
