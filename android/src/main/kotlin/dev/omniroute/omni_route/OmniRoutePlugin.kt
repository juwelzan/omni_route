package dev.omniroute.omni_route

import android.app.Activity
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Locale

/** Native Android backend (Kotlin) for the OmniRoute all-in-one Flutter plugin. */
class OmniRoutePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private var channel: MethodChannel? = null
  private var applicationContext: Context? = null
  private var activity: Activity? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
      it.setMethodCallHandler(this)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
    applicationContext = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
      "getDeviceInfo" -> result.success(readDeviceInfo())
      "hideKeyboard" -> result.success(hideSoftKeyboard())
      "keepScreenOn" -> {
        val enabled = call.argument<Boolean>("enabled") == true
        result.success(setKeepScreenOn(enabled))
      }
      "clearNativeCache" -> result.success(clearAppCache())
      else -> result.notImplemented()
    }
  }

  private fun readDeviceInfo(): Map<String, String> {
    val ctx = applicationContext
    var appName = ""
    var packageName = ""
    var version = ""
    var buildNumber = ""

    if (ctx != null) {
      packageName = ctx.packageName
      val pm = ctx.packageManager
      appName = pm.getApplicationLabel(ctx.applicationInfo).toString()
      val pkgInfo = fetchPackageInfo(pm, packageName)
      if (pkgInfo != null) {
        version = pkgInfo.versionName ?: ""
        buildNumber = versionCodeOf(pkgInfo)
      }
    }

    return mapOf(
      "platform" to "android",
      "osVersion" to "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
      "appName" to appName,
      "packageName" to packageName,
      "version" to version,
      "buildNumber" to buildNumber,
      "locale" to Locale.getDefault().toLanguageTag(),
    )
  }

  @Suppress("DEPRECATION")
  private fun fetchPackageInfo(pm: PackageManager, packageName: String): PackageInfo? =
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
      } else {
        pm.getPackageInfo(packageName, 0)
      }
    } catch (_: PackageManager.NameNotFoundException) {
      null
    }

  @Suppress("DEPRECATION")
  private fun versionCodeOf(pkgInfo: PackageInfo): String =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      pkgInfo.longVersionCode.toString()
    } else {
      pkgInfo.versionCode.toString()
    }

  private fun hideSoftKeyboard(): Boolean {
    val act = activity ?: return false
    val imm = act.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager ?: return false
    val focus = act.currentFocus ?: act.window?.decorView ?: return false
    imm.hideSoftInputFromWindow(focus.windowToken, 0)
    focus.clearFocus()
    return true
  }

  private fun setKeepScreenOn(enabled: Boolean): Boolean {
    val window = activity?.window ?: return false
    if (enabled) {
      window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    } else {
      window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    return true
  }

  private fun clearAppCache(): Boolean {
    val cacheDir = applicationContext?.cacheDir ?: return false
    if (!cacheDir.exists()) return false
    cacheDir.listFiles()?.forEach { child ->
      runCatching { child.deleteRecursively() }
    }
    return true
  }

  companion object {
    private const val CHANNEL = "dev.omniroute/omni_route"
  }
}
