import Foundation

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import AppKit
  import FlutterMacOS
#endif

public class OmniRoutePlugin: NSObject, FlutterPlugin {
  private static let channelName = "dev.omniroute/omni_route"

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = OmniRoutePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      #if os(iOS)
        result("iOS \(UIDevice.current.systemVersion)")
      #else
        result("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
      #endif

    case "getDeviceInfo":
      result(readDeviceInfo())

    case "hideKeyboard":
      #if os(iOS)
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder),
          to: nil,
          from: nil,
          for: nil
        )
        result(true)
      #else
        NSApplication.shared.keyWindow?.makeFirstResponder(nil)
        result(true)
      #endif

    case "keepScreenOn":
      let args = call.arguments as? [String: Any]
      let enabled = (args?["enabled"] as? Bool) ?? false
      #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = enabled
        result(true)
      #else
        _ = enabled
        result(false)
      #endif

    case "clearNativeCache":
      result(clearTempDirectory())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readDeviceInfo() -> [String: String] {
    let infoDict = Bundle.main.infoDictionary ?? [:]
    let appName =
      (infoDict["CFBundleDisplayName"] as? String)
      ?? (infoDict["CFBundleName"] as? String)
      ?? ""
    let packageName = Bundle.main.bundleIdentifier ?? ""
    let version = (infoDict["CFBundleShortVersionString"] as? String) ?? ""
    let buildNumber = (infoDict["CFBundleVersion"] as? String) ?? ""
    let locale = Locale.autoupdatingCurrent.identifier

    #if os(iOS)
      let platform = "ios"
      let osVersion = "iOS \(UIDevice.current.systemVersion)"
    #else
      let platform = "macos"
      let osVersion = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    #endif

    return [
      "platform": platform,
      "osVersion": osVersion,
      "appName": appName,
      "packageName": packageName,
      "version": version,
      "buildNumber": buildNumber,
      "locale": locale,
    ]
  }

  private func clearTempDirectory() -> Bool {
    let fm = FileManager.default
    let tempUrl = fm.temporaryDirectory
    guard let entries = try? fm.contentsOfDirectory(at: tempUrl, includingPropertiesForKeys: nil) else {
      return false
    }
    for item in entries {
      try? fm.removeItem(at: item)
    }
    return true
  }
}
