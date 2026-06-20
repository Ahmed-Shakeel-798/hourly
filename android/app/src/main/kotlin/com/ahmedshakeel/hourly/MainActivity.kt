package com.ahmedshakeel.hourly

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.ahmedshakeel.hourly/apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        val icons = call.argument<Boolean>("icons") ?: true
                        result.success(getInstalledApps(icons))
                    }
                    "openNotificationSettings" -> {
                        result.success(openNotificationSettings(call.argument<String>("package")))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** User-facing (launchable) apps with their label, icon and system flag. */
    private fun getInstalledApps(includeIcons: Boolean): List<Map<String, Any?>> {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(launcher, 0)

        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, Any?>>()
        for (ri in resolved) {
            val ai = ri.activityInfo.applicationInfo
            val pkg = ai.packageName
            if (pkg == packageName) continue // skip Hourly itself
            if (!seen.add(pkg)) continue
            var icon: String? = null
            if (includeIcons) {
                try {
                    icon = encodeIcon(pm.getApplicationIcon(ai))
                } catch (_: Exception) {
                }
            }
            apps.add(
                mapOf(
                    "package" to pkg,
                    "name" to pm.getApplicationLabel(ai).toString(),
                    "system" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "icon" to icon,
                )
            )
        }
        return apps.sortedBy { (it["name"] as String).lowercase() }
    }

    /** Render any drawable (incl. adaptive icons) to a small base64 PNG. */
    private fun encodeIcon(drawable: Drawable): String {
        val size = 96
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }

    /** Deep-link straight to an app's system notification settings page. */
    private fun openNotificationSettings(pkg: String?): Boolean {
        if (pkg.isNullOrEmpty()) return false
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.fromParts("package", pkg, null))
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
