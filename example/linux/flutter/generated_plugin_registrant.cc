//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <omni_route/omni_route_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) omni_route_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "OmniRoutePlugin");
  omni_route_plugin_register_with_registrar(omni_route_registrar);
}
