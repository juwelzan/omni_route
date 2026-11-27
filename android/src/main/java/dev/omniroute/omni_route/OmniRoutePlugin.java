package dev.omniroute.omni_route;

import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * Native Android backend for the OmniRoute all-in-one Flutter plugin.
 */
public class OmniRoutePlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  private static final String CHANNEL = "dev.omniroute/omni_route";

  private MethodChannel channel;
  @Nullable
  private Context applicationContext;
  @Nullable
  private Activity activity;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    applicationContext = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    applicationContext = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "getPlatformVersion":
        result.success("Android " + Build.VERSION.RELEASE);
        break;
      case "getDeviceInfo":
        result.success(readDeviceInfo());
        break;
      case "hideKeyboard":
        result.success(hideSoftKeyboard());
        break;
      case "keepScreenOn":
        Boolean enabled = call.argument("enabled");
        result.success(setKeepScreenOn(Boolean.TRUE.equals(enabled)));
        break;
      case "clearNativeCache":
        result.success(clearAppCache());
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @SuppressWarnings("deprecation")
  private Map<String, String> readDeviceInfo() {
    Map<String, String> info = new HashMap<>();
    info.put("platform", "android");
    info.put("osVersion", "Android " + Build.VERSION.RELEASE + " (SDK " + Build.VERSION.SDK_INT + ")");
    info.put("locale", Locale.getDefault().toLanguageTag());

    String appName = "";
    String packageName = "";
    String version = "";
    String buildNumber = "";

    Context ctx = applicationContext;
    if (ctx != null) {
      packageName = ctx.getPackageName();
      PackageManager pm = ctx.getPackageManager();
      ApplicationInfo appInfo = ctx.getApplicationInfo();
      CharSequence label = pm.getApplicationLabel(appInfo);
      if (label != null) {
        appName = label.toString();
      }
      try {
        PackageInfo pkgInfo;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
          pkgInfo = pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0));
        } else {
          pkgInfo = pm.getPackageInfo(packageName, 0);
        }
        if (pkgInfo.versionName != null) {
          version = pkgInfo.versionName;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
          buildNumber = String.valueOf(pkgInfo.getLongVersionCode());
        } else {
          buildNumber = String.valueOf(pkgInfo.versionCode);
        }
      } catch (PackageManager.NameNotFoundException ignored) {
        // Keep empty defaults if package metadata cannot be queried.
      }
    }

    info.put("appName", appName);
    info.put("packageName", packageName);
    info.put("version", version);
    info.put("buildNumber", buildNumber);
    return info;
  }

  private boolean hideSoftKeyboard() {
    Activity act = activity;
    if (act == null) return false;
    InputMethodManager imm = (InputMethodManager) act.getSystemService(Context.INPUT_METHOD_SERVICE);
    if (imm == null) return false;
    View focus = act.getCurrentFocus();
    if (focus == null) {
      focus = act.getWindow() != null ? act.getWindow().getDecorView() : null;
    }
    if (focus == null) return false;
    imm.hideSoftInputFromWindow(focus.getWindowToken(), 0);
    focus.clearFocus();
    return true;
  }

  private boolean setKeepScreenOn(boolean enabled) {
    Activity act = activity;
    if (act == null || act.getWindow() == null) return false;
    if (enabled) {
      act.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    } else {
      act.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }
    return true;
  }

  private boolean clearAppCache() {
    Context ctx = applicationContext;
    if (ctx == null) return false;
    File cacheDir = ctx.getCacheDir();
    if (cacheDir == null || !cacheDir.exists()) return false;
    File[] children = cacheDir.listFiles();
    if (children != null) {
      for (File child : children) {
        deleteRecursively(child);
      }
    }
    return true;
  }

  private void deleteRecursively(File target) {
    if (target.isDirectory()) {
      File[] files = target.listFiles();
      if (files != null) {
        for (File child : files) {
          deleteRecursively(child);
        }
      }
    }
    //noinspection ResultOfMethodCallIgnored
    target.delete();
  }
}
