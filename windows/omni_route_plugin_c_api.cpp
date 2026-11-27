#include "include/omni_route/omni_route_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "omni_route_plugin.h"

void OmniRoutePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  omni_route::OmniRoutePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
