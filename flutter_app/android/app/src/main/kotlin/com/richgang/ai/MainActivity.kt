package com.richgang.ai

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * Requests POST_NOTIFICATIONS on API 33+ BEFORE starting DreamCycleService.
 * If the permission is denied the service is NOT started: a foreground
 * service with an invisible notification is worse than no service.
 * Starting the service here (after permission resolution) is also the
 * belt-and-braces re-arm for the boot path on API 35+, where a direct
 * FGS start from BOOT_COMPLETED is blocked.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
        } else {
            startDreamService()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_NOTIF) return
        if (grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            startDreamService()
        } else {
            Log.w(TAG, "POST_NOTIFICATIONS denied - DreamCycleService NOT started")
        }
    }

    private fun startDreamService() {
        val svc = Intent(this, DreamCycleService::class.java)
        ContextCompat.startForegroundService(this, svc)
    }

    companion object {
        private const val TAG = "RGA.MainActivity"
        private const val REQ_NOTIF = 1001
    }
}
