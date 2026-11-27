#include "omni_route_plugin.h"

#include <windows.h>
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

namespace omni_route {

namespace {

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return "";
  int len = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                static_cast<int>(wide.size()), nullptr, 0,
                                nullptr, nullptr);
  if (len <= 0) return "";
  std::string out(static_cast<size_t>(len), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                      static_cast<int>(wide.size()), out.data(), len, nullptr,
                      nullptr);
  return out;
}

std::string WindowsVersionString() {
  if (IsWindows10OrGreater()) return "Windows 10+";
  if (IsWindows8OrGreater()) return "Windows 8+";
  return "Windows";
}

std::string CurrentLocaleString() {
  wchar_t buf[LOCALE_NAME_MAX_LENGTH] = {0};
  int chars = GetUserDefaultLocaleName(buf, LOCALE_NAME_MAX_LENGTH);
  if (chars <= 1) return "";
  return WideToUtf8(std::wstring(buf));
}

}  // namespace

// static
void OmniRoutePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "dev.omniroute/omni_route",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<OmniRoutePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

OmniRoutePlugin::OmniRoutePlugin() {}

OmniRoutePlugin::~OmniRoutePlugin() {}

void OmniRoutePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = method_call.method_name();
  if (method == "getPlatformVersion") {
    result->Success(flutter::EncodableValue(WindowsVersionString()));
  } else if (method == "getDeviceInfo") {
    flutter::EncodableMap info;
    info[flutter::EncodableValue("platform")] = flutter::EncodableValue("windows");
    info[flutter::EncodableValue("osVersion")] =
        flutter::EncodableValue(WindowsVersionString());
    info[flutter::EncodableValue("appName")] = flutter::EncodableValue("");
    info[flutter::EncodableValue("packageName")] = flutter::EncodableValue("");
    info[flutter::EncodableValue("version")] = flutter::EncodableValue("");
    info[flutter::EncodableValue("buildNumber")] = flutter::EncodableValue("");
    info[flutter::EncodableValue("locale")] =
        flutter::EncodableValue(CurrentLocaleString());
    result->Success(flutter::EncodableValue(info));
  } else if (method == "hideKeyboard") {
    result->Success(flutter::EncodableValue(true));
  } else if (method == "keepScreenOn" || method == "clearNativeCache") {
    result->Success(flutter::EncodableValue(false));
  } else {
    result->NotImplemented();
  }
}

}  // namespace omni_route
