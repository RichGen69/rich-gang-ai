package com.richgang.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import org.json.JSONObject

/**
 * Foreground service (specialUse) that owns the Rust daemon handle for
 * dream-cycle ticks. Requires in app/build.gradle(.kts):
 *   implementation("androidx.work:work-runtime-ktx:2.12.0")
 *
 * Order is load-bearing: startForeground() is called BEFORE nativeBoot().
 * The JNI methods are static (companion object, @JvmStatic) to match the
 * Rust side, which takes JClass - not JObject.
 */
class DreamCycleService : Service() {

    companion object {
        init { System.loadLibrary("daemon") }

        private const val TAG = "RGA.DreamCycle"
        private const val CHANNEL_ID = "rga_dream_cycle"
        private const val NOTIF_ID = 0x524741 // "RGA"
        private const val TICK_MS = 15L * 60L * 1000L

        @JvmStatic external fun nativeBoot(config: String): Long
        @JvmStatic external fun nativeTick(handle: Long): Long
        @JvmStatic external fun nativeQuery(handle: Long, persona: String, input: String): String?
        @JvmStatic external fun nativeStop(handle: Long)
    }

    private var handle: Long = 0L
    private var worker: Thread? = null
    @Volatile private var running: Boolean = false

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        // startForeground MUST precede nativeBoot.
        // FOREGROUND_SERVICE_TYPE_SPECIAL_USE is an API 34 constant and
        // gets its own branch; the API 29 typed overload must not see it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIF_ID, buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIF_ID, buildNotification())
        }

        handle = try {
            nativeBoot(loadSharedDaemonConfig())
        } catch (t: Throwable) {
            Log.e(TAG, "nativeBoot failed", t)
            0L
        }
        if (handle == 0L || handle == -1L) {
            Log.e(TAG, "daemon did not start (handle=$handle) - ticks will be skipped")
            handle = 0L
        } else {
            Log.i(TAG, "online")
        }

        running = true
        worker = Thread(::loop, "rga-dream-cycle").also { it.start() }
    }

    /**
     * The shared daemon config source: the same bundled
     * `assets/daemon_config.json` the Dart/UI handle boots from,
     * so both handles agree on the personas roster (the F-02
     * divergence — this service used to boot "{}" with default
     * personas while the UI handle used the asset).
     *
     * Canonical-owner rule (P6): the Dart handle owns all
     * file-backed daemon state. This handle is tick-only, so the
     * stateful keys are stripped from its copy — it must never
     * become a second writer to the SQLite store or the mmap
     * ring, and it does not need a second copy of the scene fact
     * table or the topology graph to tick dream cycles.
     *
     * A config that cannot be read or parsed is logged and falls
     * back to "{}" for THIS handle only; the failure is visible
     * in logcat, never silent.
     */
    private fun loadSharedDaemonConfig(): String {
        return try {
            val raw = assets.open("daemon_config.json")
                .bufferedReader().use { it.readText() }
            if (raw.isBlank()) return "{}"
            val json = JSONObject(raw)
            json.remove("store_path")
            json.remove("ring_path")
            json.remove("causal_links")
            json.remove("facts")
            json.toString()
        } catch (t: Throwable) {
            Log.e(TAG, "shared daemon config unavailable; " +
                "this handle boots with an empty config", t)
            "{}"
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        worker?.interrupt()
        worker = null
        if (handle != 0L) {
            try { nativeStop(handle) } catch (t: Throwable) {
                Log.e(TAG, "nativeStop failed", t)
            }
            handle = 0L
        }
        Log.i(TAG, "offline")
        super.onDestroy()
    }

    private fun loop() {
        while (running) {
            try {
                if (handle != 0L) {
                    val n = nativeTick(handle)
                    Log.i(TAG, "tick=$n")
                }
                Thread.sleep(TICK_MS)
            } catch (_: InterruptedException) {
                return
            } catch (t: Throwable) {
                Log.e(TAG, "tick failed", t)
            }
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "Dream Cycles", NotificationManager.IMPORTANCE_MIN,
            ).apply {
                setShowBadge(false)
                description = "Local memory consolidation"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CHANNEL_ID)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setContentTitle("Rich Gang AI")
            .setContentText("Daemon running - dream cycle armed")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .build()
    }
}
