package com.richgang.ai

import android.app.ForegroundServiceStartNotAllowedException
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Second stage of the boot path: starts the specialUse FGS after boot.
 *
 * Failure handling (fixed in audit): startForegroundService can throw
 * ForegroundServiceStartNotAllowedException on API 31+ when background
 * start restrictions bite, and SecurityException if a permission regresses.
 * An uncaught throw fails the worker with a stack trace and no signal;
 * instead we log loudly and return Result.failure() — the boot path must
 * degrade visibly, never silently, and never crash-loop. The other re-arm
 * path (MainActivity.onCreate) still starts the service when the user
 * next opens the app.
 */
class DreamArmWorker(appCtx: Context, params: WorkerParameters) :
    Worker(appCtx, params) {

    override fun doWork(): Result {
        val svc = Intent(applicationContext, DreamCycleService::class.java)
        return try {
            ContextCompat.startForegroundService(applicationContext, svc)
            Result.success()
        } catch (t: Throwable) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                t is ForegroundServiceStartNotAllowedException
            ) {
                Log.e(TAG, "FGS start not allowed from background at boot", t)
            } else {
                Log.e(TAG, "failed to start DreamCycleService from boot worker", t)
            }
            Result.failure()
        }
    }

    companion object {
        private const val TAG = "RGA.DreamArm"
    }
}
