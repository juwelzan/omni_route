#include "include/omni_route/omni_route_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#define OMNI_ROUTE_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), omni_route_plugin_get_type(), \
                              OmniRoutePlugin))

struct _OmniRoutePlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(OmniRoutePlugin, omni_route_plugin, g_object_get_type())

static FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.release);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_device_info() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* os_version =
      g_strdup_printf("Linux %s (%s)", uname_data.release, uname_data.machine);
  const gchar* app_name = g_get_application_name();
  const gchar* prg_name = g_get_prgname();
  const gchar* const* langs = g_get_language_names();
  const gchar* locale = (langs != nullptr && langs[0] != nullptr) ? langs[0] : "";

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "platform", fl_value_new_string("linux"));
  fl_value_set_string_take(result, "osVersion", fl_value_new_string(os_version));
  fl_value_set_string_take(
      result, "appName",
      fl_value_new_string(app_name != nullptr ? app_name : ""));
  fl_value_set_string_take(
      result, "packageName",
      fl_value_new_string(prg_name != nullptr ? prg_name : ""));
  fl_value_set_string_take(result, "version", fl_value_new_string(""));
  fl_value_set_string_take(result, "buildNumber", fl_value_new_string(""));
  fl_value_set_string_take(result, "locale", fl_value_new_string(locale));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void omni_route_plugin_handle_method_call(OmniRoutePlugin* self,
                                                 FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "getDeviceInfo") == 0) {
    response = get_device_info();
  } else if (strcmp(method, "hideKeyboard") == 0) {
    g_autoptr(FlValue) ok = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(ok));
  } else if (strcmp(method, "keepScreenOn") == 0 ||
             strcmp(method, "clearNativeCache") == 0) {
    g_autoptr(FlValue) handled = fl_value_new_bool(FALSE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(handled));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void omni_route_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(omni_route_plugin_parent_class)->dispose(object);
}

static void omni_route_plugin_class_init(OmniRoutePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = omni_route_plugin_dispose;
}

static void omni_route_plugin_init(OmniRoutePlugin* self) {}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  OmniRoutePlugin* plugin = OMNI_ROUTE_PLUGIN(user_data);
  omni_route_plugin_handle_method_call(plugin, method_call);
}

void omni_route_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  OmniRoutePlugin* plugin = OMNI_ROUTE_PLUGIN(
      g_object_new(omni_route_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "dev.omniroute/omni_route",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
