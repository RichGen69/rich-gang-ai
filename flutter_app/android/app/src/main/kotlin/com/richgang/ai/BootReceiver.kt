package com.richgang.ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager

/**
 * CORRECTED for API 35+: a direct foreground-service start from
 * BOOT_COMPLETED is blocked, so this receiver only enqueues expedited
 * work; DreamArmWorker performs the actual start.
 *
 * The manifest declares ONLY BOOT_COMPLETED for this receiver.
 * LOCKED_BOOT_COMPLETED is deliberately NOT declared: it buys nothing
 * here and would require directBootAware on receiver and service plus
 * device testing that has not been done.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        WorkManager.getInstance(ctx).enqueue(
            OneTimeWorkRequestBuilder<DreamArmWorker>()
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
        )
    }
}
