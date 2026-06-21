#include <moonbit.h>
#include <stdint.h>
#include <string.h>

typedef moonbit_bytes_t (*LepusaLinuxBytesCallback)(void *, moonbit_bytes_t);

#if defined(__linux__)
#include <ctype.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

typedef struct {
  char *name;
  pid_t pid;
} LepusaLinuxServiceProcess;

static LepusaLinuxServiceProcess lepusa_linux_service_processes[64];
static volatile sig_atomic_t lepusa_linux_service_signal_handlers_installed = 0;

typedef int (*LepusaGtkInitCheck)(int *, char ***);
typedef void *(*LepusaGtkSettingsGetDefault)(void);
typedef void *(*LepusaGtkWindowNew)(int);
typedef void (*LepusaGtkWindowSetTitle)(void *, const char *);
typedef void (*LepusaGtkWindowSetDefaultSize)(void *, int, int);
typedef void (*LepusaGtkWindowSetResizable)(void *, int);
typedef void (*LepusaGtkContainerAdd)(void *, void *);
typedef void *(*LepusaGtkBoxNew)(int, int);
typedef void (*LepusaGtkBoxPackStart)(void *, void *, int, int, unsigned int);
typedef void (*LepusaGtkBoxReorderChild)(void *, void *, int);
typedef void (*LepusaGtkWidgetShowAll)(void *);
typedef void (*LepusaGtkWidgetHide)(void *);
typedef void (*LepusaGtkWidgetDestroy)(void *);
typedef void (*LepusaGtkWidgetSetSensitive)(void *, int);
typedef void (*LepusaGtkWindowPresent)(void *);
typedef void (*LepusaGtkWindowIconify)(void *);
typedef void (*LepusaGtkWindowMaximize)(void *);
typedef void (*LepusaGtkWindowUnmaximize)(void *);
typedef void (*LepusaGtkWindowResize)(void *, int, int);
typedef void (*LepusaGtkWindowMove)(void *, int, int);
typedef void (*LepusaGtkWindowFullscreen)(void *);
typedef void (*LepusaGtkWindowUnfullscreen)(void *);
typedef void *(*LepusaGtkStatusIconNew)(void);
typedef void (*LepusaGtkStatusIconSetFromFile)(void *, const char *);
typedef void (*LepusaGtkStatusIconSetTooltipText)(void *, const char *);
typedef void (*LepusaGtkStatusIconSetVisible)(void *, int);
typedef void *(*LepusaGtkMenuNew)(void);
typedef void *(*LepusaGtkMenuBarNew)(void);
typedef void *(*LepusaGtkMenuItemNewWithLabel)(const char *);
typedef void (*LepusaGtkMenuItemSetSubmenu)(void *, void *);
typedef void *(*LepusaGtkCheckMenuItemNewWithLabel)(const char *);
typedef void *(*LepusaGtkSeparatorMenuItemNew)(void);
typedef void (*LepusaGtkCheckMenuItemSetActive)(void *, int);
typedef void (*LepusaGtkMenuShellAppend)(void *, void *);
typedef void (*LepusaGtkMenuPopupAtPointer)(void *, void *);
typedef void (*LepusaGtkMain)(void);
typedef void (*LepusaGtkMainQuit)(void);
typedef void (*LepusaGFree)(void *);
typedef void (*LepusaGObjectSet)(void *, const char *, ...);
typedef void (*LepusaGObjectUnref)(void *);
typedef void *(*LepusaGMemoryInputStreamNewFromData)(
  const void *,
  long,
  void *
);
typedef unsigned long (*LepusaGSignalConnectData)(
  void *,
  const char *,
  void *,
  void *,
  void *,
  int
);
typedef void *(*LepusaWebKitUserContentManagerNew)(void);
typedef int (*LepusaWebKitUserContentManagerRegisterScriptMessageHandler)(
  void *,
  const char *
);
typedef void *(*LepusaWebKitUserScriptNew)(
  const char *,
  int,
  int,
  const char * const *,
  const char * const *
);
typedef void (*LepusaWebKitUserContentManagerAddScript)(void *, void *);
typedef void *(*LepusaWebKitWebViewNewWithUserContentManager)(void *);
typedef void (*LepusaWebKitWebViewLoadUri)(void *, const char *);
typedef void *(*LepusaWebKitWebViewGetContext)(void *);
typedef void (*LepusaWebKitWebContextRegisterUriScheme)(
  void *,
  const char *,
  void *,
  void *,
  void *
);
typedef void (*LepusaWebKitWebViewRunJavascript)(
  void *,
  const char *,
  void *,
  void *,
  void *
);
typedef void *(*LepusaWebKitJavascriptResultGetJsValue)(void *);
typedef const char *(*LepusaWebKitUriSchemeRequestGetUri)(void *);
typedef void (*LepusaWebKitUriSchemeRequestFinish)(
  void *,
  void *,
  int64_t,
  const char *
);
typedef char *(*LepusaJscValueToString)(void *);

typedef struct {
  void *glib;
  void *gio;
  void *gtk;
  void *gobject;
  void *jsc;
  void *webkit;
  LepusaGtkInitCheck gtk_init_check;
  LepusaGtkSettingsGetDefault gtk_settings_get_default;
  LepusaGtkWindowNew gtk_window_new;
  LepusaGtkWindowSetTitle gtk_window_set_title;
  LepusaGtkWindowSetDefaultSize gtk_window_set_default_size;
  LepusaGtkWindowSetResizable gtk_window_set_resizable;
  LepusaGtkContainerAdd gtk_container_add;
  LepusaGtkBoxNew gtk_box_new;
  LepusaGtkBoxPackStart gtk_box_pack_start;
  LepusaGtkBoxReorderChild gtk_box_reorder_child;
  LepusaGtkWidgetShowAll gtk_widget_show_all;
  LepusaGtkWidgetHide gtk_widget_hide;
  LepusaGtkWidgetDestroy gtk_widget_destroy;
  LepusaGtkWidgetSetSensitive gtk_widget_set_sensitive;
  LepusaGtkWindowPresent gtk_window_present;
  LepusaGtkWindowIconify gtk_window_iconify;
  LepusaGtkWindowMaximize gtk_window_maximize;
  LepusaGtkWindowUnmaximize gtk_window_unmaximize;
  LepusaGtkWindowResize gtk_window_resize;
  LepusaGtkWindowMove gtk_window_move;
  LepusaGtkWindowFullscreen gtk_window_fullscreen;
  LepusaGtkWindowUnfullscreen gtk_window_unfullscreen;
  LepusaGtkStatusIconNew gtk_status_icon_new;
  LepusaGtkStatusIconSetFromFile gtk_status_icon_set_from_file;
  LepusaGtkStatusIconSetTooltipText gtk_status_icon_set_tooltip_text;
  LepusaGtkStatusIconSetVisible gtk_status_icon_set_visible;
  LepusaGtkMenuNew gtk_menu_new;
  LepusaGtkMenuBarNew gtk_menu_bar_new;
  LepusaGtkMenuItemNewWithLabel gtk_menu_item_new_with_label;
  LepusaGtkMenuItemSetSubmenu gtk_menu_item_set_submenu;
  LepusaGtkCheckMenuItemNewWithLabel gtk_check_menu_item_new_with_label;
  LepusaGtkSeparatorMenuItemNew gtk_separator_menu_item_new;
  LepusaGtkCheckMenuItemSetActive gtk_check_menu_item_set_active;
  LepusaGtkMenuShellAppend gtk_menu_shell_append;
  LepusaGtkMenuPopupAtPointer gtk_menu_popup_at_pointer;
  LepusaGtkMain gtk_main;
  LepusaGtkMainQuit gtk_main_quit;
  LepusaGFree g_free;
  LepusaGObjectSet g_object_set;
  LepusaGObjectUnref g_object_unref;
  LepusaGMemoryInputStreamNewFromData g_memory_input_stream_new_from_data;
  LepusaGSignalConnectData g_signal_connect_data;
  LepusaWebKitUserContentManagerNew webkit_user_content_manager_new;
  LepusaWebKitUserContentManagerRegisterScriptMessageHandler webkit_user_content_manager_register_script_message_handler;
  LepusaWebKitUserScriptNew webkit_user_script_new;
  LepusaWebKitUserContentManagerAddScript webkit_user_content_manager_add_script;
  LepusaWebKitWebViewNewWithUserContentManager webkit_web_view_new_with_user_content_manager;
  LepusaWebKitWebViewLoadUri webkit_web_view_load_uri;
  LepusaWebKitWebViewGetContext webkit_web_view_get_context;
  LepusaWebKitWebContextRegisterUriScheme webkit_web_context_register_uri_scheme;
  LepusaWebKitWebViewRunJavascript webkit_web_view_run_javascript;
  LepusaWebKitJavascriptResultGetJsValue webkit_javascript_result_get_js_value;
  LepusaWebKitUriSchemeRequestGetUri webkit_uri_scheme_request_get_uri;
  LepusaWebKitUriSchemeRequestFinish webkit_uri_scheme_request_finish;
  LepusaJscValueToString jsc_value_to_string;
} LepusaLinuxWebKit;

typedef struct {
  char label[128];
  void *window;
  void *box;
  void *menu_bar;
  int has_window_menu;
  void *webview;
} LepusaLinuxWindowSlot;

typedef struct {
  char window_label[128];
  char callback[256];
} LepusaLinuxBridgeDrainRequest;

typedef struct {
  void *window;
  void *webview;
  LepusaLinuxWindowSlot windows[32];
  int window_count;
  int live_windows;
  LepusaLinuxBridgeDrainRequest drain_requests[32];
  int drain_request_count;
  void *tray_icon;
  void *tray_menu;
  char *app_menu_payload;
  int32_t app_menu_payload_len;
  LepusaLinuxWebKit *api;
  LepusaLinuxBytesCallback call_dispatch;
  void *dispatch;
  LepusaLinuxBytesCallback call_resolve_asset;
  void *resolve_asset;
} LepusaLinuxBridgeContext;

static int lepusa_linux_load_symbol(
  void *library,
  const char *name,
  void **out
) {
  *out = dlsym(library, name);
  return *out != NULL;
}

static int lepusa_linux_load_webkit(LepusaLinuxWebKit *api) {
  memset(api, 0, sizeof(*api));
  const char *webkit_libraries[] = {
    "libwebkit2gtk-4.1.so.0",
    "libwebkit2gtk-4.0.so.37"
  };
  const char *jsc_libraries[] = {
    "libjavascriptcoregtk-4.1.so.0",
    "libjavascriptcoregtk-4.0.so.18"
  };
  api->glib = dlopen("libglib-2.0.so.0", RTLD_LAZY | RTLD_LOCAL);
  if (api->glib == NULL) {
    return 0;
  }
  api->gio = dlopen("libgio-2.0.so.0", RTLD_LAZY | RTLD_LOCAL);
  if (api->gio == NULL) {
    dlclose(api->glib);
    return 0;
  }
  api->gtk = dlopen("libgtk-3.so.0", RTLD_LAZY | RTLD_LOCAL);
  if (api->gtk == NULL) {
    dlclose(api->gio);
    dlclose(api->glib);
    return 0;
  }
  api->gobject = dlopen("libgobject-2.0.so.0", RTLD_LAZY | RTLD_LOCAL);
  if (api->gobject == NULL) {
    dlclose(api->gtk);
    dlclose(api->gio);
    dlclose(api->glib);
    return 0;
  }
  for (int i = 0; i < 2 && api->webkit == NULL; i++) {
    api->webkit = dlopen(webkit_libraries[i], RTLD_LAZY | RTLD_LOCAL);
  }
  if (api->webkit == NULL) {
    dlclose(api->gobject);
    dlclose(api->gtk);
    dlclose(api->gio);
    dlclose(api->glib);
    return 0;
  }
  for (int i = 0; i < 2 && api->jsc == NULL; i++) {
    api->jsc = dlopen(jsc_libraries[i], RTLD_LAZY | RTLD_LOCAL);
  }
  if (api->jsc == NULL) {
    dlclose(api->webkit);
    dlclose(api->gobject);
    dlclose(api->gtk);
    dlclose(api->gio);
    dlclose(api->glib);
    return 0;
  }
  int ok = 1;
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_init_check", (void **)&api->gtk_init_check);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_settings_get_default", (void **)&api->gtk_settings_get_default);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_new", (void **)&api->gtk_window_new);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_set_title", (void **)&api->gtk_window_set_title);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_set_default_size", (void **)&api->gtk_window_set_default_size);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_set_resizable", (void **)&api->gtk_window_set_resizable);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_container_add", (void **)&api->gtk_container_add);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_box_new", (void **)&api->gtk_box_new);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_box_pack_start", (void **)&api->gtk_box_pack_start);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_box_reorder_child", (void **)&api->gtk_box_reorder_child);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_widget_show_all", (void **)&api->gtk_widget_show_all);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_widget_hide", (void **)&api->gtk_widget_hide);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_widget_destroy", (void **)&api->gtk_widget_destroy);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_widget_set_sensitive", (void **)&api->gtk_widget_set_sensitive);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_present", (void **)&api->gtk_window_present);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_iconify", (void **)&api->gtk_window_iconify);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_maximize", (void **)&api->gtk_window_maximize);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_unmaximize", (void **)&api->gtk_window_unmaximize);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_resize", (void **)&api->gtk_window_resize);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_move", (void **)&api->gtk_window_move);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_fullscreen", (void **)&api->gtk_window_fullscreen);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_unfullscreen", (void **)&api->gtk_window_unfullscreen);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_status_icon_new", (void **)&api->gtk_status_icon_new);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_status_icon_set_from_file", (void **)&api->gtk_status_icon_set_from_file);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_status_icon_set_tooltip_text", (void **)&api->gtk_status_icon_set_tooltip_text);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_status_icon_set_visible", (void **)&api->gtk_status_icon_set_visible);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_menu_new", (void **)&api->gtk_menu_new);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_menu_bar_new", (void **)&api->gtk_menu_bar_new);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_menu_item_new_with_label", (void **)&api->gtk_menu_item_new_with_label);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_menu_item_set_submenu", (void **)&api->gtk_menu_item_set_submenu);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_check_menu_item_new_with_label", (void **)&api->gtk_check_menu_item_new_with_label);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_separator_menu_item_new", (void **)&api->gtk_separator_menu_item_new);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_check_menu_item_set_active", (void **)&api->gtk_check_menu_item_set_active);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_menu_shell_append", (void **)&api->gtk_menu_shell_append);
  lepusa_linux_load_symbol(api->gtk, "gtk_menu_popup_at_pointer", (void **)&api->gtk_menu_popup_at_pointer);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_main", (void **)&api->gtk_main);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_main_quit", (void **)&api->gtk_main_quit);
  ok = ok && lepusa_linux_load_symbol(api->glib, "g_free", (void **)&api->g_free);
  ok = ok && lepusa_linux_load_symbol(api->gobject, "g_object_set", (void **)&api->g_object_set);
  ok = ok && lepusa_linux_load_symbol(api->gobject, "g_object_unref", (void **)&api->g_object_unref);
  ok = ok && lepusa_linux_load_symbol(api->gio, "g_memory_input_stream_new_from_data", (void **)&api->g_memory_input_stream_new_from_data);
  ok = ok && lepusa_linux_load_symbol(api->gobject, "g_signal_connect_data", (void **)&api->g_signal_connect_data);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_user_content_manager_new", (void **)&api->webkit_user_content_manager_new);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_user_content_manager_register_script_message_handler", (void **)&api->webkit_user_content_manager_register_script_message_handler);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_user_script_new", (void **)&api->webkit_user_script_new);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_user_content_manager_add_script", (void **)&api->webkit_user_content_manager_add_script);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_web_view_new_with_user_content_manager", (void **)&api->webkit_web_view_new_with_user_content_manager);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_web_view_load_uri", (void **)&api->webkit_web_view_load_uri);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_web_view_get_context", (void **)&api->webkit_web_view_get_context);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_web_context_register_uri_scheme", (void **)&api->webkit_web_context_register_uri_scheme);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_web_view_run_javascript", (void **)&api->webkit_web_view_run_javascript);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_javascript_result_get_js_value", (void **)&api->webkit_javascript_result_get_js_value);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_uri_scheme_request_get_uri", (void **)&api->webkit_uri_scheme_request_get_uri);
  ok = ok && lepusa_linux_load_symbol(api->webkit, "webkit_uri_scheme_request_finish", (void **)&api->webkit_uri_scheme_request_finish);
  ok = ok && lepusa_linux_load_symbol(api->jsc, "jsc_value_to_string", (void **)&api->jsc_value_to_string);
  if (!ok) {
    dlclose(api->jsc);
    dlclose(api->webkit);
    dlclose(api->gobject);
    dlclose(api->gtk);
    dlclose(api->gio);
    dlclose(api->glib);
  }
  return ok;
}

static char *lepusa_linux_cstr_from_bytes(moonbit_bytes_t bytes) {
  if (bytes == NULL) {
    return NULL;
  }
  int32_t len = Moonbit_array_length(bytes);
  char *out = (char *)malloc((size_t)len + 1);
  if (out == NULL) {
    return NULL;
  }
  memcpy(out, bytes, (size_t)len);
  out[len] = '\0';
  return out;
}

static char *lepusa_linux_cstr_from_range(const char *text, int32_t len) {
  int32_t safe_len = text == NULL || len < 0 ? 0 : len;
  char *out = (char *)malloc((size_t)safe_len + 1);
  if (out == NULL) {
    return NULL;
  }
  if (safe_len > 0) {
    memcpy(out, text, (size_t)safe_len);
  }
  out[safe_len] = '\0';
  return out;
}

static char *lepusa_linux_js_string_literal_from_range(
  const char *text,
  int32_t len
) {
  int32_t safe_len = text == NULL || len < 0 ? 0 : len;
  size_t capacity = (size_t)safe_len * 6 + 3;
  char *out = (char *)malloc(capacity);
  if (out == NULL) {
    return NULL;
  }
  size_t pos = 0;
  out[pos++] = '"';
  for (int32_t i = 0; i < safe_len; i++) {
    unsigned char ch = (unsigned char)text[i];
    if (ch == '"' || ch == '\\') {
      out[pos++] = '\\';
      out[pos++] = (char)ch;
    } else if (ch == '\n') {
      out[pos++] = '\\';
      out[pos++] = 'n';
    } else if (ch == '\r') {
      out[pos++] = '\\';
      out[pos++] = 'r';
    } else if (ch == '\t') {
      out[pos++] = '\\';
      out[pos++] = 't';
    } else if (ch < 0x20) {
      static const char hex[] = "0123456789abcdef";
      out[pos++] = '\\';
      out[pos++] = 'u';
      out[pos++] = '0';
      out[pos++] = '0';
      out[pos++] = hex[(ch >> 4) & 0xf];
      out[pos++] = hex[ch & 0xf];
    } else {
      out[pos++] = (char)ch;
    }
  }
  out[pos++] = '"';
  out[pos] = '\0';
  return out;
}

static moonbit_bytes_t lepusa_linux_bytes_from_cstr(const char *text) {
  const char *safe = text == NULL ? "" : text;
  int32_t len = (int32_t)strlen(safe);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, safe, (size_t)len);
  return bytes;
}

static void lepusa_linux_finish_uri_bytes(
  LepusaLinuxWebKit *api,
  void *request,
  const char *mime_type,
  char *data,
  int64_t length
) {
  if (api == NULL || request == NULL || data == NULL || length < 0) {
    free(data);
    return;
  }
  void *stream = api->g_memory_input_stream_new_from_data(
    data,
    (long)length,
    (void *)free
  );
  if (stream == NULL) {
    free(data);
    return;
  }
  api->webkit_uri_scheme_request_finish(
    request,
    stream,
    length,
    mime_type == NULL || mime_type[0] == '\0' ?
      "application/octet-stream" :
      mime_type
  );
  api->g_object_unref(stream);
}

static void lepusa_linux_finish_uri_text(
  LepusaLinuxWebKit *api,
  void *request,
  const char *mime_type,
  const char *text
) {
  const char *safe = text == NULL ? "" : text;
  size_t length = strlen(safe);
  char *copy = (char *)malloc(length + 1);
  if (copy == NULL) {
    return;
  }
  memcpy(copy, safe, length + 1);
  lepusa_linux_finish_uri_bytes(api, request, mime_type, copy, (int64_t)length);
}

static int lepusa_linux_read_file(
  const char *path,
  char **data_out,
  int64_t *length_out
) {
  FILE *file = fopen(path, "rb");
  if (file == NULL) {
    return 0;
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return 0;
  }
  long size = ftell(file);
  if (size < 0) {
    fclose(file);
    return 0;
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return 0;
  }
  char *data = (char *)malloc((size_t)size + 1);
  if (data == NULL) {
    fclose(file);
    return 0;
  }
  size_t read = fread(data, 1, (size_t)size, file);
  fclose(file);
  if (read != (size_t)size) {
    free(data);
    return 0;
  }
  data[size] = '\0';
  *data_out = data;
  *length_out = (int64_t)size;
  return 1;
}

static char *lepusa_linux_next_packet_line(char **cursor) {
  if (cursor == NULL || *cursor == NULL) {
    return NULL;
  }
  char *line = *cursor;
  char *newline = strchr(line, '\n');
  if (newline == NULL) {
    *cursor = NULL;
  } else {
    *newline = '\0';
    *cursor = newline + 1;
  }
  return line;
}

static moonbit_bytes_t lepusa_linux_immediate_script_from_handoff_packet(
  moonbit_bytes_t packet
) {
  char *packet_text = lepusa_linux_cstr_from_bytes(packet);
  char *cursor = packet_text;
  char *status = lepusa_linux_next_packet_line(&cursor);
  if (packet_text == NULL || status == NULL || strcmp(status, "immediate") != 0) {
    free(packet_text);
    return NULL;
  }
  char *window_label = lepusa_linux_next_packet_line(&cursor);
  if (window_label == NULL || cursor == NULL) {
    free(packet_text);
    return NULL;
  }
  char *body_len_text = lepusa_linux_next_packet_line(&cursor);
  if (body_len_text == NULL || cursor == NULL) {
    free(packet_text);
    return NULL;
  }
  char *endptr = NULL;
  long body_len = strtol(body_len_text, &endptr, 10);
  if (endptr == body_len_text || *endptr != '\0' || body_len < 0) {
    free(packet_text);
    return NULL;
  }
  if (body_len > INT32_MAX || (size_t)body_len > strlen(cursor)) {
    free(packet_text);
    return NULL;
  }
  int32_t script_len = (int32_t)body_len;
  moonbit_bytes_t script = moonbit_make_bytes(script_len, 0);
  if (script_len > 0) {
    memcpy(script, cursor, (size_t)script_len);
  }
  free(packet_text);
  return script;
}

static const char *lepusa_linux_find_newline_range(
  const char *start,
  const char *end
) {
  const char *cursor = start;
  while (cursor < end) {
    if (*cursor == '\n') {
      return cursor;
    }
    cursor++;
  }
  return NULL;
}

static int lepusa_linux_handoff_operations_range(
  moonbit_bytes_t packet,
  const char **operations_out,
  int32_t *operations_len_out
) {
  if (packet == NULL || operations_out == NULL || operations_len_out == NULL) {
    return 0;
  }
  const char *start = (const char *)packet;
  const char *end = start + Moonbit_array_length(packet);
  const char *first = lepusa_linux_find_newline_range(start, end);
  if (first == NULL ||
      (first - start) != 9 ||
      memcmp(start, "immediate", 9) != 0) {
    return 0;
  }
  const char *second = lepusa_linux_find_newline_range(first + 1, end);
  if (second == NULL) {
    return 0;
  }
  const char *third = lepusa_linux_find_newline_range(second + 1, end);
  if (third == NULL) {
    return 0;
  }
  int64_t body_len64 = 0;
  for (const char *p = second + 1; p < third; p++) {
    if (*p < '0' || *p > '9') {
      return 0;
    }
    body_len64 = body_len64 * 10 + (*p - '0');
    if (body_len64 > INT32_MAX) {
      return 0;
    }
  }
  const char *operations = third + 1 + (int32_t)body_len64;
  if (operations > end) {
    return 0;
  }
  if (operations < end && *operations == '\n') {
    operations++;
  }
  *operations_out = operations;
  *operations_len_out = (int32_t)(end - operations);
  return 1;
}

typedef struct {
  const char *kind;
  int32_t kind_len;
  const char *window;
  int32_t window_len;
  const char *action;
  int32_t action_len;
  const char *url;
  int32_t url_len;
  const char *title;
  int32_t title_len;
  const char *width;
  int32_t width_len;
  const char *height;
  int32_t height_len;
  const char *x;
  int32_t x_len;
  const char *y;
  int32_t y_len;
  const char *fullscreen;
  int32_t fullscreen_len;
  const char *resizable;
  int32_t resizable_len;
  const char *bridge_source;
  int32_t bridge_source_len;
  const char *native_hook;
  int32_t native_hook_len;
  const char *asset_protocol;
  int32_t asset_protocol_len;
} LepusaLinuxNativeOperationRecord;

static char *lepusa_linux_initialization_script_from_record(
  const LepusaLinuxNativeOperationRecord *record
) {
  if (record == NULL) {
    return NULL;
  }
  char *native_hook = lepusa_linux_js_string_literal_from_range(
    record->native_hook,
    record->native_hook_len
  );
  char *bridge_source = lepusa_linux_cstr_from_range(
    record->bridge_source,
    record->bridge_source_len
  );
  if (native_hook == NULL || bridge_source == NULL) {
    free(native_hook);
    free(bridge_source);
    return NULL;
  }
  const char *template_text =
    "(() => {\n"
    "  const nativeHook = %s;\n"
    "  const responseHook = `${nativeHook}Response`;\n"
    "  const pending = new Map();\n"
    "  Object.defineProperty(globalThis, responseHook, {\n"
    "    value: (response) => {\n"
    "      const id = response && String(response.id || \"\");\n"
    "      const callbacks = pending.get(id);\n"
    "      if (!callbacks) { return false; }\n"
    "      pending.delete(id);\n"
    "      if (response && response.error) { callbacks.reject(new Error(response.error)); }\n"
    "      else { callbacks.resolve(response || null); }\n"
    "      return true;\n"
    "    },\n"
    "    configurable: true,\n"
    "  });\n"
    "  Object.defineProperty(globalThis, nativeHook, {\n"
    "    value: (request) => new Promise((resolve, reject) => {\n"
    "      const handler = globalThis.webkit && globalThis.webkit.messageHandlers && globalThis.webkit.messageHandlers[nativeHook];\n"
    "      if (!handler || typeof handler.postMessage !== \"function\") {\n"
    "        reject(new Error(`Missing Lepusa Linux native message handler: ${nativeHook}`));\n"
    "        return;\n"
    "      }\n"
    "      pending.set(String(request.id || \"\"), { resolve, reject });\n"
    "      handler.postMessage(JSON.stringify(request));\n"
    "    }),\n"
    "    configurable: true,\n"
    "  });\n"
    "})();\n"
    "%s";
  int needed = snprintf(NULL, 0, template_text, native_hook, bridge_source);
  if (needed < 0) {
    free(native_hook);
    free(bridge_source);
    return NULL;
  }
  char *script = (char *)malloc((size_t)needed + 1);
  if (script != NULL) {
    snprintf(script, (size_t)needed + 1, template_text, native_hook, bridge_source);
  }
  free(native_hook);
  free(bridge_source);
  return script;
}

static int lepusa_linux_range_equals(
  const char *value,
  int32_t value_len,
  const char *literal
) {
  size_t literal_len = literal == NULL ? 0 : strlen(literal);
  return value != NULL &&
    value_len == (int32_t)literal_len &&
    memcmp(value, literal, literal_len) == 0;
}

static void lepusa_linux_copy_label_range(
  char *target,
  size_t target_len,
  const char *label,
  int32_t label_len
) {
  if (target == NULL || target_len == 0) {
    return;
  }
  size_t safe_len = label == NULL || label_len <= 0 ? 0 : (size_t)label_len;
  if (safe_len >= target_len) {
    safe_len = target_len - 1;
  }
  if (safe_len > 0) {
    memcpy(target, label, safe_len);
  }
  target[safe_len] = '\0';
}

static LepusaLinuxWindowSlot *lepusa_linux_find_window_slot_exact(
  LepusaLinuxBridgeContext *context,
  const char *label,
  int32_t label_len
) {
  if (context == NULL) {
    return NULL;
  }
  for (int i = 0; i < context->window_count; i++) {
    if (label != NULL &&
        label_len > 0 &&
        lepusa_linux_range_equals(
          label,
          label_len,
          context->windows[i].label
        )) {
      return &context->windows[i];
    }
  }
  return NULL;
}

static LepusaLinuxWindowSlot *lepusa_linux_find_window_slot(
  LepusaLinuxBridgeContext *context,
  const char *label,
  int32_t label_len
) {
  LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot_exact(
    context,
    label,
    label_len
  );
  if (slot != NULL) {
    return slot;
  }
  if (context == NULL) {
    return NULL;
  }
  return context->window_count > 0 ? &context->windows[0] : NULL;
}

static LepusaLinuxWindowSlot *lepusa_linux_register_window_slot(
  LepusaLinuxBridgeContext *context,
  const char *label,
  int32_t label_len,
  void *window,
  void *box,
  void *webview
) {
  if (context == NULL || window == NULL || box == NULL || webview == NULL) {
    return NULL;
  }
  LepusaLinuxWindowSlot *existing = lepusa_linux_find_window_slot_exact(
    context,
    label,
    label_len
  );
  if (existing != NULL) {
    if (existing->window == NULL) {
      context->live_windows++;
    }
    existing->window = window;
    existing->box = box;
    existing->webview = webview;
    return existing;
  }
  if (context->window_count >= 32) {
    return NULL;
  }
  LepusaLinuxWindowSlot *slot = &context->windows[context->window_count++];
  lepusa_linux_copy_label_range(
    slot->label,
    sizeof(slot->label),
    label,
    label_len
  );
  slot->window = window;
  slot->box = box;
  slot->webview = webview;
  context->live_windows++;
  return slot;
}

static void lepusa_linux_remove_window_slot(
  LepusaLinuxBridgeContext *context,
  void *window
) {
  if (context == NULL || window == NULL) {
    return;
  }
  for (int i = 0; i < context->window_count; i++) {
    if (context->windows[i].window != window) {
      continue;
    }
    for (int j = i; j + 1 < context->window_count; j++) {
      context->windows[j] = context->windows[j + 1];
    }
    context->window_count--;
    memset(
      &context->windows[context->window_count],
      0,
      sizeof(LepusaLinuxWindowSlot)
    );
    if (context->live_windows > 0) {
      context->live_windows--;
    }
    if (context->window == window) {
      context->window = context->window_count > 0 ?
        context->windows[0].window :
        NULL;
      context->webview = context->window_count > 0 ?
        context->windows[0].webview :
        NULL;
    }
    return;
  }
}

static void lepusa_linux_register_bridge_drain_request(
  LepusaLinuxBridgeContext *context,
  const char *window_label,
  int32_t window_label_len,
  const char *callback,
  int32_t callback_len
) {
  if (context == NULL || callback == NULL || callback_len <= 0) {
    return;
  }
  if (context->drain_request_count >= 32) {
    return;
  }
  LepusaLinuxBridgeDrainRequest *request =
    &context->drain_requests[context->drain_request_count++];
  lepusa_linux_copy_label_range(
    request->window_label,
    sizeof(request->window_label),
    window_label,
    window_label_len
  );
  lepusa_linux_copy_label_range(
    request->callback,
    sizeof(request->callback),
    callback,
    callback_len
  );
}

static LepusaLinuxWindowSlot *lepusa_linux_window_slot_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  if (context == NULL || packet == NULL) {
    return NULL;
  }
  const char *start = (const char *)packet;
  const char *end = start + Moonbit_array_length(packet);
  const char *first = lepusa_linux_find_newline_range(start, end);
  if (first == NULL) {
    return lepusa_linux_find_window_slot(context, NULL, 0);
  }
  const char *second = lepusa_linux_find_newline_range(first + 1, end);
  if (second == NULL) {
    return lepusa_linux_find_window_slot(context, NULL, 0);
  }
  return lepusa_linux_find_window_slot(
    context,
    first + 1,
    (int32_t)(second - first - 1)
  );
}

static int lepusa_linux_read_packet_field(
  const char **cursor,
  const char *end,
  const char **value_out,
  int32_t *value_len_out
) {
  if (cursor == NULL ||
      *cursor == NULL ||
      value_out == NULL ||
      value_len_out == NULL) {
    return 0;
  }
  const char *line_end = lepusa_linux_find_newline_range(*cursor, end);
  if (line_end == NULL) {
    return 0;
  }
  int64_t len64 = 0;
  for (const char *p = *cursor; p < line_end; p++) {
    if (*p < '0' || *p > '9') {
      return 0;
    }
    len64 = len64 * 10 + (*p - '0');
    if (len64 > INT32_MAX) {
      return 0;
    }
  }
  const char *value = line_end + 1;
  if (value + (int32_t)len64 > end) {
    return 0;
  }
  *value_out = value;
  *value_len_out = (int32_t)len64;
  *cursor = value + (int32_t)len64;
  return 1;
}

static int lepusa_linux_read_native_operation_record(
  const char **cursor,
  const char *end,
  LepusaLinuxNativeOperationRecord *record
) {
  return record != NULL &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->kind,
      &record->kind_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->window,
      &record->window_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->action,
      &record->action_len
    ) &&
    lepusa_linux_read_packet_field(cursor, end, &record->url, &record->url_len) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->title,
      &record->title_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->width,
      &record->width_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->height,
      &record->height_len
    ) &&
    lepusa_linux_read_packet_field(cursor, end, &record->x, &record->x_len) &&
    lepusa_linux_read_packet_field(cursor, end, &record->y, &record->y_len) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->fullscreen,
      &record->fullscreen_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->resizable,
      &record->resizable_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->bridge_source,
      &record->bridge_source_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->native_hook,
      &record->native_hook_len
    ) &&
    lepusa_linux_read_packet_field(
      cursor,
      end,
      &record->asset_protocol,
      &record->asset_protocol_len
    );
}

static int lepusa_linux_parse_record_int(
  const char *value,
  int32_t value_len,
  int *value_out
) {
  if (value == NULL || value_len <= 0 || value_out == NULL) {
    return 0;
  }
  int sign = 1;
  int32_t index = 0;
  if (value[0] == '-') {
    sign = -1;
    index = 1;
  }
  if (index >= value_len || !isdigit((unsigned char)value[index])) {
    return 0;
  }
  int parsed = 0;
  while (index < value_len && isdigit((unsigned char)value[index])) {
    parsed = parsed * 10 + (value[index] - '0');
    index++;
  }
  if (index != value_len) {
    return 0;
  }
  *value_out = sign * parsed;
  return 1;
}

static int lepusa_linux_parse_record_bool(
  const char *value,
  int32_t value_len,
  int *value_out
) {
  if (value_out == NULL) {
    return 0;
  }
  if (lepusa_linux_range_equals(value, value_len, "true")) {
    *value_out = 1;
    return 1;
  }
  if (lepusa_linux_range_equals(value, value_len, "false")) {
    *value_out = 0;
    return 1;
  }
  return 0;
}

static int lepusa_linux_handoff_operation_records(
  moonbit_bytes_t packet,
  const char **cursor_out,
  const char **end_out,
  int32_t *count_out
) {
  const char *operations = NULL;
  int32_t operations_len = 0;
  if (!lepusa_linux_handoff_operations_range(
        packet,
        &operations,
        &operations_len
      )) {
    return 0;
  }
  const char *cursor = operations;
  const char *end = operations + operations_len;
  const char *version = lepusa_linux_find_newline_range(cursor, end);
  if (version == NULL ||
      !lepusa_linux_range_equals(
        cursor,
        (int32_t)(version - cursor),
        "lepusa-ops-v3"
      )) {
    return 0;
  }
  cursor = version + 1;
  const char *count_end = lepusa_linux_find_newline_range(cursor, end);
  if (count_end == NULL) {
    return 0;
  }
  int64_t count64 = 0;
  for (const char *p = cursor; p < count_end; p++) {
    if (*p < '0' || *p > '9') {
      return 0;
    }
    count64 = count64 * 10 + (*p - '0');
    if (count64 > INT32_MAX) {
      return 0;
    }
  }
  *cursor_out = count_end + 1;
  *end_out = end;
  *count_out = (int32_t)count64;
  return 1;
}

static void lepusa_linux_apply_window_controls_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  if (context == NULL ||
      context->api == NULL ||
      context->window == NULL ||
      packet == NULL) {
    return;
  }
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (!lepusa_linux_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  int closed = 0;
  for (int32_t i = 0; i < count; i++) {
    LepusaLinuxNativeOperationRecord record;
    if (!lepusa_linux_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot(
      context,
      record.window,
      record.window_len
    );
    void *window = slot == NULL ? NULL : slot->window;
    if (window == NULL) {
      continue;
    }
    if (lepusa_linux_range_equals(
          record.kind,
          record.kind_len,
          "close-window"
      )) {
      if (!closed) {
        context->api->gtk_widget_destroy(window);
        closed = 1;
      }
      continue;
    }
    if (!lepusa_linux_range_equals(
          record.kind,
          record.kind_len,
          "window-control"
        )) {
      continue;
    }
    if (lepusa_linux_range_equals(record.action, record.action_len, "setTitle")) {
      char *title = lepusa_linux_cstr_from_range(record.title, record.title_len);
      if (title != NULL) {
        context->api->gtk_window_set_title(window, title);
        free(title);
      }
    } else if (lepusa_linux_range_equals(
                 record.action,
                 record.action_len,
                 "setSize"
               )) {
      int width = 0;
      int height = 0;
      if (lepusa_linux_parse_record_int(record.width, record.width_len, &width) &&
          lepusa_linux_parse_record_int(record.height, record.height_len, &height) &&
          width > 0 &&
          height > 0) {
        context->api->gtk_window_resize(window, width, height);
      }
    } else if (lepusa_linux_range_equals(
                 record.action,
                 record.action_len,
                 "setPosition"
               )) {
      int x = 0;
      int y = 0;
      if (lepusa_linux_parse_record_int(record.x, record.x_len, &x) &&
          lepusa_linux_parse_record_int(record.y, record.y_len, &y)) {
        context->api->gtk_window_move(window, x, y);
      }
    } else if (lepusa_linux_range_equals(
                 record.action,
                 record.action_len,
                 "setFullscreen"
               )) {
      int fullscreen = 0;
      if (lepusa_linux_parse_record_bool(
            record.fullscreen,
            record.fullscreen_len,
        &fullscreen
      )) {
        if (fullscreen) {
          context->api->gtk_window_fullscreen(window);
        } else {
          context->api->gtk_window_unfullscreen(window);
        }
      }
    } else if (lepusa_linux_range_equals(record.action, record.action_len, "show")) {
      context->api->gtk_widget_show_all(window);
    } else if (lepusa_linux_range_equals(record.action, record.action_len, "focus")) {
      context->api->gtk_window_present(window);
    } else if (lepusa_linux_range_equals(record.action, record.action_len, "hide")) {
      context->api->gtk_widget_hide(window);
    } else if (lepusa_linux_range_equals(
                 record.action,
                 record.action_len,
                 "minimize"
               )) {
      context->api->gtk_window_iconify(window);
    } else if (lepusa_linux_range_equals(
                 record.action,
                 record.action_len,
                 "maximize"
               )) {
      context->api->gtk_window_maximize(window);
    } else if (lepusa_linux_range_equals(
                 record.action,
                 record.action_len,
                 "unmaximize"
               )) {
      context->api->gtk_window_unmaximize(window);
    } else if (lepusa_linux_range_equals(record.action, record.action_len, "close")) {
      if (!closed) {
        context->api->gtk_widget_destroy(window);
        closed = 1;
      }
    }
  }
}

static void lepusa_linux_close_all_windows(LepusaLinuxBridgeContext *context) {
  if (context == NULL || context->api == NULL) {
    return;
  }
  for (int i = context->window_count - 1; i >= 0; i--) {
    void *window = context->windows[i].window;
    if (window != NULL) {
      context->api->gtk_widget_destroy(window);
    }
  }
}

static void lepusa_linux_free_process_argv(char **argv, int argc) {
  if (argv == NULL) {
    return;
  }
  for (int i = 0; i < argc; i++) {
    free(argv[i]);
  }
  free(argv);
}

static int lepusa_linux_current_process_argv(char ***argv_out, int *argc_out) {
  if (argv_out == NULL || argc_out == NULL) {
    return 0;
  }
  FILE *file = fopen("/proc/self/cmdline", "rb");
  if (file == NULL) {
    return 0;
  }
  size_t capacity = 4096;
  size_t length = 0;
  char *buffer = (char *)malloc(capacity);
  if (buffer == NULL) {
    fclose(file);
    return 0;
  }
  for (;;) {
    if (length == capacity) {
      if (capacity >= 1024 * 1024) {
        free(buffer);
        fclose(file);
        return 0;
      }
      capacity *= 2;
      char *grown = (char *)realloc(buffer, capacity);
      if (grown == NULL) {
        free(buffer);
        fclose(file);
        return 0;
      }
      buffer = grown;
    }
    size_t read = fread(buffer + length, 1, capacity - length, file);
    length += read;
    if (read == 0) {
      break;
    }
  }
  fclose(file);
  if (length == 0 || buffer[0] == '\0') {
    free(buffer);
    return 0;
  }
  int argc = 0;
  for (size_t i = 0; i < length; i++) {
    if (buffer[i] == '\0') {
      argc++;
    }
  }
  if (buffer[length - 1] != '\0') {
    argc++;
  }
  if (argc <= 0 || argc > 256) {
    free(buffer);
    return 0;
  }
  char **argv = (char **)calloc((size_t)argc + 1, sizeof(char *));
  if (argv == NULL) {
    free(buffer);
    return 0;
  }
  int index = 0;
  size_t start = 0;
  for (size_t i = 0; i <= length && index < argc; i++) {
    if (i == length || buffer[i] == '\0') {
      size_t item_len = i - start;
      argv[index] = (char *)malloc(item_len + 1);
      if (argv[index] == NULL) {
        free(buffer);
        lepusa_linux_free_process_argv(argv, index);
        return 0;
      }
      memcpy(argv[index], buffer + start, item_len);
      argv[index][item_len] = '\0';
      index++;
      start = i + 1;
    }
  }
  free(buffer);
  argv[index] = NULL;
  *argv_out = argv;
  *argc_out = index;
  return index > 0 && argv[0][0] != '\0';
}

static int lepusa_linux_spawn_current_process(void) {
  char **argv = NULL;
  int argc = 0;
  if (!lepusa_linux_current_process_argv(&argv, &argc)) {
    return 0;
  }
  pid_t pid = 0;
  int result = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
  lepusa_linux_free_process_argv(argv, argc);
  return result == 0;
}

static int lepusa_linux_app_shell_action_equals(
  const char *action,
  int32_t action_len,
  const char *name
) {
  size_t name_len = strlen(name);
  return lepusa_linux_range_equals(action, action_len, name) ||
    (action != NULL &&
     action_len == (int32_t)(name_len + 4) &&
     memcmp(action, "app.", 4) == 0 &&
     memcmp(action + 4, name, name_len) == 0);
}

static int lepusa_linux_range_contains_text(
  const char *value,
  int32_t value_len,
  const char *needle
) {
  if (value == NULL || value_len <= 0 || needle == NULL) {
    return 0;
  }
  size_t needle_len = strlen(needle);
  if (needle_len == 0 || value_len < (int32_t)needle_len) {
    return 0;
  }
  for (int32_t i = 0; i <= value_len - (int32_t)needle_len; i++) {
    if (memcmp(value + i, needle, needle_len) == 0) {
      return 1;
    }
  }
  return 0;
}

static const char *lepusa_linux_json_skip_space(const char *cursor, const char *end) {
  while (cursor < end && isspace((unsigned char)*cursor)) {
    cursor++;
  }
  return cursor;
}

static const char *lepusa_linux_json_string_end(const char *cursor, const char *end) {
  if (cursor >= end || *cursor != '"') {
    return NULL;
  }
  cursor++;
  while (cursor < end) {
    if (*cursor == '\\') {
      cursor += cursor + 1 < end ? 2 : 1;
    } else if (*cursor == '"') {
      return cursor + 1;
    } else {
      cursor++;
    }
  }
  return NULL;
}

static const char *lepusa_linux_json_value_end(const char *cursor, const char *end) {
  cursor = lepusa_linux_json_skip_space(cursor, end);
  if (cursor >= end) {
    return NULL;
  }
  if (*cursor == '"') {
    return lepusa_linux_json_string_end(cursor, end);
  }
  if (*cursor == '{' || *cursor == '[') {
    char open = *cursor;
    char close = open == '{' ? '}' : ']';
    int depth = 1;
    cursor++;
    while (cursor < end) {
      if (*cursor == '"') {
        cursor = lepusa_linux_json_string_end(cursor, end);
        if (cursor == NULL) {
          return NULL;
        }
      } else if (*cursor == open) {
        depth++;
        cursor++;
      } else if (*cursor == close) {
        depth--;
        cursor++;
        if (depth == 0) {
          return cursor;
        }
      } else {
        cursor++;
      }
    }
    return NULL;
  }
  while (cursor < end &&
         *cursor != ',' &&
         *cursor != '}' &&
         *cursor != ']') {
    cursor++;
  }
  return cursor;
}

static int lepusa_linux_json_find_member_value(
  const char *object,
  const char *end,
  const char *name,
  const char **value_out,
  const char **value_end_out
) {
  if (object == NULL || end == NULL || name == NULL || value_out == NULL || value_end_out == NULL) {
    return 0;
  }
  const char *cursor = lepusa_linux_json_skip_space(object, end);
  if (cursor >= end || *cursor != '{') {
    return 0;
  }
  cursor++;
  size_t name_len = strlen(name);
  while (cursor < end) {
    cursor = lepusa_linux_json_skip_space(cursor, end);
    if (cursor >= end || *cursor == '}') {
      return 0;
    }
    const char *key_start = cursor;
    const char *key_end = lepusa_linux_json_string_end(cursor, end);
    if (key_end == NULL) {
      return 0;
    }
    cursor = lepusa_linux_json_skip_space(key_end, end);
    if (cursor >= end || *cursor != ':') {
      return 0;
    }
    cursor++;
    const char *value = lepusa_linux_json_skip_space(cursor, end);
    const char *value_end = lepusa_linux_json_value_end(value, end);
    if (value_end == NULL) {
      return 0;
    }
    if ((size_t)(key_end - key_start - 2) == name_len &&
        memcmp(key_start + 1, name, name_len) == 0) {
      *value_out = value;
      *value_end_out = value_end;
      return 1;
    }
    cursor = lepusa_linux_json_skip_space(value_end, end);
    if (cursor < end && *cursor == ',') {
      cursor++;
    }
  }
  return 0;
}

static char *lepusa_linux_json_string_value_to_cstr(
  const char *value,
  const char *end
) {
  value = lepusa_linux_json_skip_space(value, end);
  if (value >= end || *value != '"') {
    return NULL;
  }
  const char *value_end = lepusa_linux_json_string_end(value, end);
  if (value_end == NULL || value_end > end) {
    return NULL;
  }
  return lepusa_linux_cstr_from_range(value + 1, (int32_t)(value_end - value - 2));
}

static char *lepusa_linux_json_payload_string(
  const char *payload,
  int32_t payload_len,
  const char *field
) {
  if (payload == NULL || payload_len <= 0) {
    return NULL;
  }
  const char *end = payload + payload_len;
  const char *cursor = lepusa_linux_json_skip_space(payload, end);
  if (cursor < end && *cursor == '"') {
    return lepusa_linux_json_string_value_to_cstr(cursor, end);
  }
  const char *value = NULL;
  const char *value_end = NULL;
  if (lepusa_linux_json_find_member_value(cursor, end, field, &value, &value_end)) {
    return lepusa_linux_json_string_value_to_cstr(value, value_end);
  }
  return NULL;
}

static int lepusa_linux_json_bool_value(
  const char *value,
  const char *end,
  int *out
) {
  if (out == NULL) {
    return 0;
  }
  value = lepusa_linux_json_skip_space(value, end);
  if (value + 4 <= end && memcmp(value, "true", 4) == 0) {
    *out = 1;
    return 1;
  }
  if (value + 5 <= end && memcmp(value, "false", 5) == 0) {
    *out = 0;
    return 1;
  }
  return 0;
}

static int lepusa_linux_json_payload_bool(
  const char *payload,
  int32_t payload_len,
  const char *field,
  int fallback
) {
  int value = fallback;
  if (payload == NULL || payload_len <= 0) {
    return value;
  }
  const char *end = payload + payload_len;
  const char *cursor = lepusa_linux_json_skip_space(payload, end);
  if (lepusa_linux_json_bool_value(cursor, end, &value)) {
    return value;
  }
  const char *member = NULL;
  const char *member_end = NULL;
  if (lepusa_linux_json_find_member_value(cursor, end, field, &member, &member_end)) {
    lepusa_linux_json_bool_value(member, member_end, &value);
  }
  return value;
}

static int lepusa_linux_theme_payload_prefers_dark(
  const char *payload,
  int32_t payload_len,
  int *dark_out
) {
  if (dark_out == NULL) {
    return 0;
  }
  if (payload_len <= 0 ||
      lepusa_linux_range_contains_text(payload, payload_len, "system") ||
      lepusa_linux_range_contains_text(payload, payload_len, "light")) {
    *dark_out = 0;
    return 1;
  }
  if (lepusa_linux_range_contains_text(payload, payload_len, "dark")) {
    *dark_out = 1;
    return 1;
  }
  return 0;
}

static void lepusa_linux_apply_app_theme(
  LepusaLinuxBridgeContext *context,
  const char *payload,
  int32_t payload_len
) {
  int prefer_dark = 0;
  if (context == NULL ||
      context->api == NULL ||
      context->api->gtk_settings_get_default == NULL ||
      context->api->g_object_set == NULL ||
      !lepusa_linux_theme_payload_prefers_dark(payload, payload_len, &prefer_dark)) {
    return;
  }
  void *settings = context->api->gtk_settings_get_default();
  if (settings != NULL) {
    context->api->g_object_set(
      settings,
      "gtk-application-prefer-dark-theme",
      prefer_dark,
      NULL
    );
  }
}

typedef struct {
  LepusaLinuxBridgeContext *context;
  char *event;
  char *id;
} LepusaLinuxMenuClick;

static void lepusa_linux_free_menu_click(void *data) {
  LepusaLinuxMenuClick *click = (LepusaLinuxMenuClick *)data;
  if (click == NULL) {
    return;
  }
  free(click->event);
  free(click->id);
  free(click);
}

static void lepusa_linux_dispatch_menu_click(
  LepusaLinuxBridgeContext *context,
  const char *event,
  const char *id
) {
  if (context == NULL ||
      context->api == NULL ||
      context->webview == NULL ||
      context->api->webkit_web_view_run_javascript == NULL ||
      event == NULL ||
      id == NULL) {
    return;
  }
  char *event_literal = lepusa_linux_js_string_literal_from_range(
    event,
    (int32_t)strlen(event)
  );
  char *id_literal = lepusa_linux_js_string_literal_from_range(
    id,
    (int32_t)strlen(id)
  );
  if (event_literal == NULL || id_literal == NULL) {
    free(event_literal);
    free(id_literal);
    return;
  }
  const char *template_text =
    "(globalThis[\"__lepusaDispatchEvent\"]||(()=>false))({name:%s,payload:JSON.stringify({id:%s})});";
  int needed = snprintf(NULL, 0, template_text, event_literal, id_literal);
  if (needed >= 0) {
    char *script = (char *)malloc((size_t)needed + 1);
    if (script != NULL) {
      snprintf(script, (size_t)needed + 1, template_text, event_literal, id_literal);
      context->api->webkit_web_view_run_javascript(
        context->webview,
        script,
        NULL,
        NULL,
        NULL
      );
      free(script);
    }
  }
  free(event_literal);
  free(id_literal);
}

static void lepusa_linux_menu_item_activated(void *widget, void *data) {
  (void)widget;
  LepusaLinuxMenuClick *click = (LepusaLinuxMenuClick *)data;
  if (click != NULL) {
    lepusa_linux_dispatch_menu_click(click->context, click->event, click->id);
  }
}

static void lepusa_linux_show_tray_menu(LepusaLinuxBridgeContext *context) {
  if (context == NULL ||
      context->api == NULL ||
      context->tray_menu == NULL ||
      context->api->gtk_widget_show_all == NULL) {
    return;
  }
  context->api->gtk_widget_show_all(context->tray_menu);
  if (context->api->gtk_menu_popup_at_pointer != NULL) {
    context->api->gtk_menu_popup_at_pointer(context->tray_menu, NULL);
  }
}

static void lepusa_linux_tray_popup_menu(
  void *status_icon,
  unsigned int button,
  unsigned int activate_time,
  void *data
) {
  (void)status_icon;
  (void)button;
  (void)activate_time;
  lepusa_linux_show_tray_menu((LepusaLinuxBridgeContext *)data);
}

static void lepusa_linux_tray_activated(void *status_icon, void *data) {
  (void)status_icon;
  lepusa_linux_show_tray_menu((LepusaLinuxBridgeContext *)data);
}

static void lepusa_linux_ensure_tray_icon(LepusaLinuxBridgeContext *context) {
  if (context == NULL || context->api == NULL || context->tray_icon != NULL) {
    return;
  }
  if (context->api->gtk_status_icon_new == NULL ||
      context->api->gtk_status_icon_set_visible == NULL ||
      context->api->g_signal_connect_data == NULL) {
    return;
  }
  context->tray_icon = context->api->gtk_status_icon_new();
  if (context->tray_icon == NULL) {
    return;
  }
  context->api->gtk_status_icon_set_visible(context->tray_icon, 1);
  context->api->g_signal_connect_data(
    context->tray_icon,
    "popup-menu",
    (void *)lepusa_linux_tray_popup_menu,
    context,
    NULL,
    0
  );
  context->api->g_signal_connect_data(
    context->tray_icon,
    "activate",
    (void *)lepusa_linux_tray_activated,
    context,
    NULL,
    0
  );
}

static int lepusa_linux_json_member_string_range(
  const char *object,
  const char *end,
  const char *field,
  const char **value_out,
  int32_t *value_len_out
) {
  const char *value = NULL;
  const char *value_end = NULL;
  if (!lepusa_linux_json_find_member_value(object, end, field, &value, &value_end)) {
    return 0;
  }
  value = lepusa_linux_json_skip_space(value, value_end);
  const char *string_end = lepusa_linux_json_string_end(value, value_end);
  if (string_end == NULL) {
    return 0;
  }
  *value_out = value + 1;
  *value_len_out = (int32_t)(string_end - value - 2);
  return 1;
}

static int lepusa_linux_json_member_bool(
  const char *object,
  const char *end,
  const char *field,
  int fallback
) {
  const char *value = NULL;
  const char *value_end = NULL;
  int out = fallback;
  if (lepusa_linux_json_find_member_value(object, end, field, &value, &value_end)) {
    lepusa_linux_json_bool_value(value, value_end, &out);
  }
  return out;
}

static void lepusa_linux_attach_menu_item_click(
  LepusaLinuxBridgeContext *context,
  void *item,
  const char *event,
  const char *id,
  int32_t id_len
) {
  if (context == NULL ||
      context->api == NULL ||
      context->api->g_signal_connect_data == NULL ||
      item == NULL ||
      event == NULL ||
      id == NULL ||
      id_len <= 0) {
    return;
  }
  LepusaLinuxMenuClick *click =
    (LepusaLinuxMenuClick *)calloc(1, sizeof(LepusaLinuxMenuClick));
  if (click == NULL) {
    return;
  }
  click->context = context;
  click->event = lepusa_linux_cstr_from_range(event, (int32_t)strlen(event));
  click->id = lepusa_linux_cstr_from_range(id, id_len);
  if (click->event == NULL || click->id == NULL) {
    lepusa_linux_free_menu_click(click);
    return;
  }
  context->api->g_signal_connect_data(
    item,
    "activate",
    (void *)lepusa_linux_menu_item_activated,
    click,
    (void *)lepusa_linux_free_menu_click,
    0
  );
}

static void lepusa_linux_add_tray_menu_items_from_array(
  LepusaLinuxBridgeContext *context,
  void *menu,
  const char *array,
  const char *array_end
) {
  if (context == NULL || context->api == NULL || menu == NULL) {
    return;
  }
  const char *cursor = lepusa_linux_json_skip_space(array, array_end);
  if (cursor >= array_end || *cursor != '[') {
    return;
  }
  cursor++;
  while (cursor < array_end) {
    cursor = lepusa_linux_json_skip_space(cursor, array_end);
    if (cursor >= array_end || *cursor == ']') {
      return;
    }
    const char *item_end = lepusa_linux_json_value_end(cursor, array_end);
    if (item_end == NULL) {
      return;
    }
    const char *kind = NULL;
    int32_t kind_len = 0;
    const char *label = NULL;
    int32_t label_len = 0;
    const char *id = NULL;
    int32_t id_len = 0;
    int is_separator = 0;
    int is_check = 0;
    void *item = NULL;
    if (cursor < item_end && *cursor == '{') {
      if (lepusa_linux_json_member_string_range(cursor, item_end, "kind", &kind, &kind_len)) {
        is_separator = lepusa_linux_range_equals(kind, kind_len, "separator");
        is_check = lepusa_linux_range_equals(kind, kind_len, "check");
      }
      if (is_separator) {
        item = context->api->gtk_separator_menu_item_new();
      } else {
        lepusa_linux_json_member_string_range(cursor, item_end, "label", &label, &label_len);
        char *label_text = lepusa_linux_cstr_from_range(label, label_len);
        if (label_text != NULL) {
          item = is_check ?
            context->api->gtk_check_menu_item_new_with_label(label_text) :
            context->api->gtk_menu_item_new_with_label(label_text);
          free(label_text);
        }
        if (item != NULL && is_check) {
          int checked = lepusa_linux_json_member_bool(cursor, item_end, "checked", 0);
          context->api->gtk_check_menu_item_set_active(item, checked);
        }
        if (item != NULL) {
          int enabled = lepusa_linux_json_member_bool(cursor, item_end, "enabled", 1);
          context->api->gtk_widget_set_sensitive(item, enabled);
          if (lepusa_linux_json_member_string_range(cursor, item_end, "id", &id, &id_len)) {
            lepusa_linux_attach_menu_item_click(
              context,
              item,
              "tray.onMenuItemClick",
              id,
              id_len
            );
          }
        }
      }
    }
    if (item != NULL) {
      context->api->gtk_menu_shell_append(menu, item);
    }
    cursor = lepusa_linux_json_skip_space(item_end, array_end);
    if (cursor < array_end && *cursor == ',') {
      cursor++;
    }
  }
}

static void lepusa_linux_apply_tray_menu(
  LepusaLinuxBridgeContext *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL || context->api == NULL || payload == NULL || payload_len <= 0) {
    return;
  }
  lepusa_linux_ensure_tray_icon(context);
  if (context->api->gtk_menu_new == NULL ||
      context->api->gtk_menu_shell_append == NULL ||
      context->api->gtk_menu_item_new_with_label == NULL ||
      context->api->gtk_check_menu_item_new_with_label == NULL ||
      context->api->gtk_separator_menu_item_new == NULL ||
      context->api->gtk_widget_set_sensitive == NULL ||
      context->api->gtk_check_menu_item_set_active == NULL) {
    return;
  }
  const char *end = payload + payload_len;
  const char *items = lepusa_linux_json_skip_space(payload, end);
  const char *items_end = end;
  const char *member = NULL;
  const char *member_end = NULL;
  if (items < end && *items == '{' &&
      lepusa_linux_json_find_member_value(items, end, "items", &member, &member_end)) {
    items = member;
    items_end = member_end;
  }
  void *menu = context->api->gtk_menu_new();
  if (menu == NULL) {
    return;
  }
  lepusa_linux_add_tray_menu_items_from_array(context, menu, items, items_end);
  if (context->tray_menu != NULL && context->api->g_object_unref != NULL) {
    context->api->g_object_unref(context->tray_menu);
  }
  context->tray_menu = menu;
}

static int lepusa_linux_tray_action_equals(
  const char *action,
  int32_t action_len,
  const char *name
) {
  size_t name_len = strlen(name);
  return lepusa_linux_range_equals(action, action_len, name) ||
    (action != NULL &&
     action_len == (int32_t)(name_len + 5) &&
     memcmp(action, "tray.", 5) == 0 &&
     memcmp(action + 5, name, name_len) == 0);
}

static void lepusa_linux_destroy_tray(LepusaLinuxBridgeContext *context) {
  if (context == NULL || context->api == NULL) {
    return;
  }
  if (context->tray_icon != NULL) {
    context->api->gtk_status_icon_set_visible(context->tray_icon, 0);
    if (context->api->g_object_unref != NULL) {
      context->api->g_object_unref(context->tray_icon);
    }
    context->tray_icon = NULL;
  }
  if (context->tray_menu != NULL && context->api->g_object_unref != NULL) {
    context->api->g_object_unref(context->tray_menu);
  }
  context->tray_menu = NULL;
}

static int lepusa_linux_menu_action_equals(
  const char *action,
  int32_t action_len,
  const char *name
) {
  size_t name_len = strlen(name);
  return lepusa_linux_range_equals(action, action_len, name) ||
    (action != NULL &&
     action_len == (int32_t)(name_len + 5) &&
     memcmp(action, "menu.", 5) == 0 &&
     memcmp(action + 5, name, name_len) == 0);
}

static void lepusa_linux_add_menu_items_from_array(
  LepusaLinuxBridgeContext *context,
  void *menu,
  const char *array,
  const char *array_end,
  int depth,
  const char *click_event
) {
  if (context == NULL ||
      context->api == NULL ||
      menu == NULL ||
      array == NULL ||
      depth > 8) {
    return;
  }
  const char *cursor = lepusa_linux_json_skip_space(array, array_end);
  if (cursor >= array_end || *cursor != '[') {
    return;
  }
  cursor++;
  while (cursor < array_end) {
    cursor = lepusa_linux_json_skip_space(cursor, array_end);
    if (cursor >= array_end || *cursor == ']') {
      return;
    }
    if (*cursor == ',') {
      cursor++;
      continue;
    }
    const char *item_end = lepusa_linux_json_value_end(cursor, array_end);
    if (item_end == NULL) {
      return;
    }
    void *item = NULL;
    if (cursor < item_end && *cursor == '{') {
      const char *kind = NULL;
      int32_t kind_len = 0;
      const char *label = NULL;
      int32_t label_len = 0;
      (void)lepusa_linux_json_member_string_range(
        cursor,
        item_end,
        "kind",
        &kind,
        &kind_len
      );
      if (lepusa_linux_range_equals(kind, kind_len, "separator")) {
        item = context->api->gtk_separator_menu_item_new();
      } else if (lepusa_linux_json_member_string_range(
                   cursor,
                   item_end,
                   "label",
                   &label,
                   &label_len
                 )) {
        char *label_text = lepusa_linux_cstr_from_range(label, label_len);
        if (label_text != NULL) {
          int is_check = lepusa_linux_range_equals(kind, kind_len, "check");
          int is_submenu = lepusa_linux_range_equals(kind, kind_len, "submenu");
          item = is_check ?
            context->api->gtk_check_menu_item_new_with_label(label_text) :
            context->api->gtk_menu_item_new_with_label(label_text);
          free(label_text);
          if (item != NULL) {
            int enabled = lepusa_linux_json_member_bool(
              cursor,
              item_end,
              "enabled",
              1
            );
            int checked = lepusa_linux_json_member_bool(
              cursor,
              item_end,
              "checked",
              0
            );
            context->api->gtk_widget_set_sensitive(item, enabled);
            if (is_check) {
              context->api->gtk_check_menu_item_set_active(item, checked);
            }
            if (is_submenu) {
              const char *children = NULL;
              const char *children_end = NULL;
              if (lepusa_linux_json_find_member_value(
                    cursor,
                    item_end,
                    "items",
                    &children,
                    &children_end
                  ) &&
                  children < children_end &&
                  *lepusa_linux_json_skip_space(children, children_end) == '[') {
                void *submenu = context->api->gtk_menu_new();
                if (submenu != NULL) {
                  lepusa_linux_add_menu_items_from_array(
                    context,
                    submenu,
                    children,
                    children_end,
                    depth + 1,
                    click_event
                  );
                  context->api->gtk_menu_item_set_submenu(item, submenu);
                }
              }
            } else {
              const char *id = NULL;
              int32_t id_len = 0;
              if (lepusa_linux_json_member_string_range(
                    cursor,
                    item_end,
                    "id",
                    &id,
                    &id_len
                  )) {
                lepusa_linux_attach_menu_item_click(
                  context,
                  item,
                  click_event,
                  id,
                  id_len
                );
              }
            }
          }
        }
      }
    }
    if (item != NULL) {
      context->api->gtk_menu_shell_append(menu, item);
    }
    cursor = lepusa_linux_json_skip_space(item_end, array_end);
    if (cursor < array_end && *cursor == ',') {
      cursor++;
    }
  }
}

static void *lepusa_linux_menu_bar_from_payload(
  LepusaLinuxBridgeContext *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL || context->api == NULL || payload == NULL || payload_len <= 0) {
    return NULL;
  }
  if (context->api->gtk_menu_bar_new == NULL ||
      context->api->gtk_menu_shell_append == NULL ||
      context->api->gtk_menu_item_new_with_label == NULL ||
      context->api->gtk_menu_item_set_submenu == NULL ||
      context->api->gtk_check_menu_item_new_with_label == NULL ||
      context->api->gtk_separator_menu_item_new == NULL ||
      context->api->gtk_widget_set_sensitive == NULL ||
      context->api->gtk_check_menu_item_set_active == NULL) {
    return NULL;
  }
  const char *end = payload + payload_len;
  const char *items = lepusa_linux_json_skip_space(payload, end);
  const char *items_end = end;
  const char *member = NULL;
  const char *member_end = NULL;
  if (items < end && *items == '{' &&
      lepusa_linux_json_find_member_value(items, end, "items", &member, &member_end)) {
    items = member;
    items_end = member_end;
  }
  if (items >= items_end || *items != '[') {
    return NULL;
  }
  void *menu_bar = context->api->gtk_menu_bar_new();
  if (menu_bar == NULL) {
    return NULL;
  }
  lepusa_linux_add_menu_items_from_array(
    context,
    menu_bar,
    items,
    items_end,
    0,
    "menu.onItemClick"
  );
  return menu_bar;
}

static void lepusa_linux_clear_window_menu_bar(
  LepusaLinuxBridgeContext *context,
  LepusaLinuxWindowSlot *slot
) {
  if (context == NULL || context->api == NULL || slot == NULL || slot->menu_bar == NULL) {
    return;
  }
  context->api->gtk_widget_destroy(slot->menu_bar);
  slot->menu_bar = NULL;
}

static void lepusa_linux_set_window_menu_bar(
  LepusaLinuxBridgeContext *context,
  LepusaLinuxWindowSlot *slot,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL || context->api == NULL || slot == NULL || slot->box == NULL) {
    return;
  }
  void *menu_bar = lepusa_linux_menu_bar_from_payload(
    context,
    payload,
    payload_len
  );
  if (menu_bar == NULL) {
    return;
  }
  lepusa_linux_clear_window_menu_bar(context, slot);
  slot->menu_bar = menu_bar;
  context->api->gtk_box_pack_start(slot->box, menu_bar, 0, 0, 0);
  context->api->gtk_box_reorder_child(slot->box, menu_bar, 0);
  if (slot->window != NULL) {
    context->api->gtk_widget_show_all(slot->window);
  }
}

static void lepusa_linux_apply_app_menu_to_available_windows(
  LepusaLinuxBridgeContext *context
) {
  if (context == NULL || context->app_menu_payload == NULL) {
    return;
  }
  for (int i = 0; i < context->window_count; i++) {
    LepusaLinuxWindowSlot *slot = &context->windows[i];
    if (slot->window != NULL && !slot->has_window_menu) {
      lepusa_linux_set_window_menu_bar(
        context,
        slot,
        context->app_menu_payload,
        context->app_menu_payload_len
      );
    }
  }
}

static void lepusa_linux_set_app_menu(
  LepusaLinuxBridgeContext *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL || payload == NULL || payload_len <= 0) {
    return;
  }
  char *copy = lepusa_linux_cstr_from_range(payload, payload_len);
  if (copy == NULL) {
    return;
  }
  free(context->app_menu_payload);
  context->app_menu_payload = copy;
  context->app_menu_payload_len = payload_len;
  lepusa_linux_apply_app_menu_to_available_windows(context);
}

static void lepusa_linux_clear_app_menu(LepusaLinuxBridgeContext *context) {
  if (context == NULL) {
    return;
  }
  free(context->app_menu_payload);
  context->app_menu_payload = NULL;
  context->app_menu_payload_len = 0;
  for (int i = 0; i < context->window_count; i++) {
    LepusaLinuxWindowSlot *slot = &context->windows[i];
    if (slot->window != NULL && !slot->has_window_menu) {
      lepusa_linux_clear_window_menu_bar(context, slot);
    }
  }
}

static void lepusa_linux_set_specific_window_menu(
  LepusaLinuxBridgeContext *context,
  const char *label,
  int32_t label_len,
  const char *payload,
  int32_t payload_len
) {
  LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot(
    context,
    label,
    label_len
  );
  if (slot == NULL) {
    return;
  }
  slot->has_window_menu = 1;
  lepusa_linux_set_window_menu_bar(context, slot, payload, payload_len);
}

static void lepusa_linux_clear_specific_window_menu(
  LepusaLinuxBridgeContext *context,
  const char *label,
  int32_t label_len
) {
  LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot(
    context,
    label,
    label_len
  );
  if (slot == NULL) {
    return;
  }
  slot->has_window_menu = 0;
  if (context != NULL && context->app_menu_payload != NULL) {
    lepusa_linux_set_window_menu_bar(
      context,
      slot,
      context->app_menu_payload,
      context->app_menu_payload_len
    );
  } else {
    lepusa_linux_clear_window_menu_bar(context, slot);
  }
}

static void lepusa_linux_apply_desktop_shell_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  if (context == NULL || context->api == NULL || packet == NULL) {
    return;
  }
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (!lepusa_linux_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  for (int32_t i = 0; i < count; i++) {
    LepusaLinuxNativeOperationRecord record;
    if (!lepusa_linux_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    if (!lepusa_linux_range_equals(
          record.kind,
          record.kind_len,
          "desktop-shell"
        )) {
      continue;
    }
    if (lepusa_linux_menu_action_equals(record.action, record.action_len, "setAppMenu")) {
      lepusa_linux_set_app_menu(context, record.url, record.url_len);
      continue;
    }
    if (lepusa_linux_menu_action_equals(record.action, record.action_len, "clearAppMenu")) {
      lepusa_linux_clear_app_menu(context);
      continue;
    }
    if (lepusa_linux_menu_action_equals(record.action, record.action_len, "setWindowMenu")) {
      lepusa_linux_set_specific_window_menu(
        context,
        record.window,
        record.window_len,
        record.url,
        record.url_len
      );
      continue;
    }
    if (lepusa_linux_menu_action_equals(record.action, record.action_len, "clearWindowMenu")) {
      lepusa_linux_clear_specific_window_menu(
        context,
        record.window,
        record.window_len
      );
      continue;
    }
    if (lepusa_linux_tray_action_equals(record.action, record.action_len, "setIcon")) {
      lepusa_linux_ensure_tray_icon(context);
      char *icon_path = lepusa_linux_json_payload_string(record.url, record.url_len, "iconPath");
      if (context->tray_icon != NULL && icon_path != NULL) {
        context->api->gtk_status_icon_set_from_file(context->tray_icon, icon_path);
      }
      free(icon_path);
      continue;
    }
    if (lepusa_linux_tray_action_equals(record.action, record.action_len, "setTooltip")) {
      lepusa_linux_ensure_tray_icon(context);
      char *tooltip = lepusa_linux_json_payload_string(record.url, record.url_len, "tooltip");
      if (context->tray_icon != NULL && tooltip != NULL) {
        context->api->gtk_status_icon_set_tooltip_text(context->tray_icon, tooltip);
      }
      free(tooltip);
      continue;
    }
    if (lepusa_linux_tray_action_equals(record.action, record.action_len, "setMenu")) {
      lepusa_linux_apply_tray_menu(context, record.url, record.url_len);
      continue;
    }
    if (lepusa_linux_tray_action_equals(record.action, record.action_len, "showMenu")) {
      lepusa_linux_show_tray_menu(context);
      continue;
    }
    if (lepusa_linux_tray_action_equals(record.action, record.action_len, "setVisible")) {
      lepusa_linux_ensure_tray_icon(context);
      int visible = lepusa_linux_json_payload_bool(record.url, record.url_len, "visible", 1);
      if (context->tray_icon != NULL) {
        context->api->gtk_status_icon_set_visible(context->tray_icon, visible);
      }
      continue;
    }
    if (lepusa_linux_tray_action_equals(record.action, record.action_len, "destroy")) {
      lepusa_linux_destroy_tray(context);
      continue;
    }
    if (lepusa_linux_app_shell_action_equals(record.action, record.action_len, "restart")) {
      if (lepusa_linux_spawn_current_process()) {
        lepusa_linux_close_all_windows(context);
      }
      continue;
    }
    if (lepusa_linux_app_shell_action_equals(record.action, record.action_len, "exit")) {
      lepusa_linux_close_all_windows(context);
      continue;
    }
    if (lepusa_linux_app_shell_action_equals(record.action, record.action_len, "setTheme")) {
      lepusa_linux_apply_app_theme(context, record.url, record.url_len);
      continue;
    }
    LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot(
      context,
      record.window,
      record.window_len
    );
    void *window = slot == NULL ? NULL : slot->window;
    if (window == NULL) {
      continue;
    }
    if (lepusa_linux_app_shell_action_equals(record.action, record.action_len, "show")) {
      context->api->gtk_widget_show_all(window);
      context->api->gtk_window_present(window);
    } else if (lepusa_linux_app_shell_action_equals(record.action, record.action_len, "hide")) {
      context->api->gtk_widget_hide(window);
    }
  }
}

static void lepusa_linux_apply_navigation_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  if (context == NULL ||
      context->api == NULL ||
      context->webview == NULL ||
      packet == NULL) {
    return;
  }
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (!lepusa_linux_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  for (int32_t i = 0; i < count; i++) {
    LepusaLinuxNativeOperationRecord record;
    if (!lepusa_linux_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    if (lepusa_linux_range_equals(
          record.kind,
          record.kind_len,
          "navigate-window"
        )) {
      LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot(
        context,
        record.window,
        record.window_len
      );
      char *url = lepusa_linux_cstr_from_range(record.url, record.url_len);
      if (url != NULL && slot != NULL && slot->webview != NULL) {
        context->api->webkit_web_view_load_uri(slot->webview, url);
      }
      if (url != NULL) {
        free(url);
      }
    }
  }
}

static void lepusa_linux_apply_bridge_drains_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  if (context == NULL || packet == NULL) {
    return;
  }
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (!lepusa_linux_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  for (int32_t i = 0; i < count; i++) {
    LepusaLinuxNativeOperationRecord record;
    if (!lepusa_linux_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    if (!lepusa_linux_range_equals(
          record.kind,
          record.kind_len,
          "drain-bridge-window"
        )) {
      continue;
    }
    lepusa_linux_register_bridge_drain_request(
      context,
      record.window,
      record.window_len,
      record.action,
      record.action_len
    );
  }
}

static void lepusa_linux_apply_evaluate_scripts_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  if (context == NULL ||
      context->api == NULL ||
      context->webview == NULL ||
      packet == NULL) {
    return;
  }
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (!lepusa_linux_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  for (int32_t i = 0; i < count; i++) {
    LepusaLinuxNativeOperationRecord record;
    if (!lepusa_linux_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    if (!lepusa_linux_range_equals(
          record.kind,
          record.kind_len,
          "evaluate-script"
        ) ||
        record.url_len <= 0) {
      continue;
    }
    LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot(
      context,
      record.window,
      record.window_len
    );
    char *script = lepusa_linux_cstr_from_range(record.url, record.url_len);
    if (script != NULL && slot != NULL && slot->webview != NULL) {
      context->api->webkit_web_view_run_javascript(
        slot->webview,
        script,
        NULL,
        NULL,
        NULL
      );
    }
    free(script);
  }
}

static void lepusa_linux_uri_scheme_request(void *request, void *user_data);
static void lepusa_linux_script_message_received(
  void *manager,
  void *js_result,
  void *user_data
);
static void lepusa_linux_window_destroyed(void *widget, void *data);

static void lepusa_linux_open_window_from_record(
  LepusaLinuxBridgeContext *context,
  const LepusaLinuxNativeOperationRecord *record
) {
  if (context == NULL ||
      context->api == NULL ||
      record == NULL ||
      record->window_len <= 0 ||
      record->url_len <= 0) {
    return;
  }
  if (lepusa_linux_find_window_slot_exact(
        context,
        record->window,
        record->window_len
      ) != NULL) {
    return;
  }
  int width = 960;
  int height = 640;
  int resizable = 1;
  (void)lepusa_linux_parse_record_int(record->width, record->width_len, &width);
  (void)lepusa_linux_parse_record_int(
    record->height,
    record->height_len,
    &height
  );
  (void)lepusa_linux_parse_record_bool(
    record->resizable,
    record->resizable_len,
    &resizable
  );
  if (width <= 0) {
    width = 960;
  }
  if (height <= 0) {
    height = 640;
  }
  char *title = lepusa_linux_cstr_from_range(record->title, record->title_len);
  char *url = lepusa_linux_cstr_from_range(record->url, record->url_len);
  char *script_text = lepusa_linux_initialization_script_from_record(record);
  char *native_hook = lepusa_linux_cstr_from_range(
    record->native_hook,
    record->native_hook_len
  );
  char *asset_protocol = lepusa_linux_cstr_from_range(
    record->asset_protocol,
    record->asset_protocol_len
  );
  if (title == NULL ||
      url == NULL ||
      script_text == NULL ||
      native_hook == NULL ||
      asset_protocol == NULL) {
    free(title);
    free(url);
    free(script_text);
    free(native_hook);
    free(asset_protocol);
    return;
  }
  void *window = context->api->gtk_window_new(0);
  void *manager = context->api->webkit_user_content_manager_new();
  if (window == NULL || manager == NULL) {
    free(title);
    free(url);
    free(script_text);
    free(native_hook);
    free(asset_protocol);
    return;
  }
  if (native_hook[0] != '\0' &&
      context->call_dispatch != NULL &&
      context->dispatch != NULL) {
    context->api->webkit_user_content_manager_register_script_message_handler(
      manager,
      native_hook
    );
  }
  void *script = context->api->webkit_user_script_new(
    script_text,
    0,
    0,
    NULL,
    NULL
  );
  if (script != NULL) {
    context->api->webkit_user_content_manager_add_script(manager, script);
  }
  void *webview = context->api->webkit_web_view_new_with_user_content_manager(
    manager
  );
  void *box = context->api->gtk_box_new(1, 0);
  if (webview == NULL || box == NULL) {
    free(title);
    free(url);
    free(script_text);
    free(native_hook);
    free(asset_protocol);
    return;
  }
  if (asset_protocol[0] != '\0' &&
      context->call_resolve_asset != NULL &&
      context->resolve_asset != NULL) {
    void *web_context = context->api->webkit_web_view_get_context(webview);
    if (web_context != NULL) {
      context->api->webkit_web_context_register_uri_scheme(
        web_context,
        asset_protocol,
        (void *)lepusa_linux_uri_scheme_request,
        context,
        NULL
      );
    }
  }
  if (native_hook[0] != '\0' &&
      context->call_dispatch != NULL &&
      context->dispatch != NULL) {
    char signal_name[256];
    snprintf(
      signal_name,
      sizeof(signal_name),
      "script-message-received::%s",
      native_hook
    );
    context->api->g_signal_connect_data(
      manager,
      signal_name,
      (void *)lepusa_linux_script_message_received,
      context,
      NULL,
      0
    );
  }
  context->api->gtk_window_set_title(window, title);
  context->api->gtk_window_set_default_size(window, width, height);
  context->api->gtk_window_set_resizable(window, resizable != 0);
  context->api->gtk_container_add(window, box);
  context->api->gtk_box_pack_start(box, webview, 1, 1, 0);
  LepusaLinuxWindowSlot *slot = lepusa_linux_register_window_slot(
    context,
    record->window,
    record->window_len,
    window,
    box,
    webview
  );
  if (slot != NULL &&
      context->app_menu_payload != NULL &&
      !slot->has_window_menu) {
    lepusa_linux_set_window_menu_bar(
      context,
      slot,
      context->app_menu_payload,
      context->app_menu_payload_len
    );
  }
  context->api->g_signal_connect_data(
    window,
    "destroy",
    (void *)lepusa_linux_window_destroyed,
    context,
    NULL,
    0
  );
  context->api->webkit_web_view_load_uri(webview, url);
  context->api->gtk_widget_show_all(window);
  free(title);
  free(url);
  free(script_text);
  free(native_hook);
  free(asset_protocol);
}

static void lepusa_linux_apply_open_windows_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  if (context == NULL || packet == NULL) {
    return;
  }
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (!lepusa_linux_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  for (int32_t i = 0; i < count; i++) {
    LepusaLinuxNativeOperationRecord record;
    if (!lepusa_linux_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    if (lepusa_linux_range_equals(record.kind, record.kind_len, "open-window")) {
      lepusa_linux_open_window_from_record(context, &record);
    }
  }
}

static void lepusa_linux_apply_operations_from_handoff_packet(
  LepusaLinuxBridgeContext *context,
  moonbit_bytes_t packet
) {
  lepusa_linux_apply_evaluate_scripts_from_handoff_packet(context, packet);
  lepusa_linux_apply_bridge_drains_from_handoff_packet(context, packet);
  lepusa_linux_apply_open_windows_from_handoff_packet(context, packet);
  lepusa_linux_apply_window_controls_from_handoff_packet(context, packet);
  lepusa_linux_apply_navigation_from_handoff_packet(context, packet);
  lepusa_linux_apply_desktop_shell_from_handoff_packet(context, packet);
}

static moonbit_bytes_t lepusa_linux_bridge_drain_request_message(
  const char *window_label
) {
  const char *prefix = "lepusa-drain-v1\n";
  size_t prefix_len = strlen(prefix);
  size_t label_len = window_label == NULL ? 0 : strlen(window_label);
  moonbit_bytes_t bytes = moonbit_make_bytes(
    (int32_t)(prefix_len + label_len),
    0
  );
  memcpy(bytes, prefix, prefix_len);
  if (label_len > 0) {
    memcpy(bytes + prefix_len, window_label, label_len);
  }
  return bytes;
}

static void lepusa_linux_process_bridge_drain_requests(
  LepusaLinuxBridgeContext *context
) {
  if (context == NULL ||
      context->api == NULL ||
      context->call_dispatch == NULL ||
      context->dispatch == NULL ||
      context->drain_request_count <= 0) {
    return;
  }
  int rounds = 0;
  while (context->drain_request_count > 0 && rounds++ < 32) {
    LepusaLinuxBridgeDrainRequest requests[32];
    int request_count = context->drain_request_count;
    if (request_count > 32) {
      request_count = 32;
    }
    for (int i = 0; i < request_count; i++) {
      requests[i] = context->drain_requests[i];
    }
    context->drain_request_count = 0;
    for (int i = 0; i < request_count; i++) {
      moonbit_bytes_t request = lepusa_linux_bridge_drain_request_message(
        requests[i].window_label
      );
      moonbit_bytes_t packet = context->call_dispatch(context->dispatch, request);
      moonbit_bytes_t script = lepusa_linux_immediate_script_from_handoff_packet(
        packet
      );
      char *script_text = lepusa_linux_cstr_from_bytes(script);
      LepusaLinuxWindowSlot *slot = lepusa_linux_find_window_slot(
        context,
        requests[i].window_label,
        (int32_t)strlen(requests[i].window_label)
      );
      void *target_webview = slot == NULL ? context->webview : slot->webview;
      if (script_text != NULL && target_webview != NULL) {
        context->api->webkit_web_view_run_javascript(
          target_webview,
          script_text,
          NULL,
          NULL,
          NULL
        );
      }
      free(script_text);
      lepusa_linux_apply_operations_from_handoff_packet(context, packet);
    }
  }
}

static void lepusa_linux_uri_scheme_request(
  void *request,
  void *user_data
) {
  LepusaLinuxBridgeContext *context = (LepusaLinuxBridgeContext *)user_data;
  if (context == NULL ||
      context->api == NULL ||
      context->call_resolve_asset == NULL ||
      context->resolve_asset == NULL) {
    return;
  }
  const char *uri = context->api->webkit_uri_scheme_request_get_uri(request);
  moonbit_bytes_t uri_bytes = lepusa_linux_bytes_from_cstr(uri);
  moonbit_bytes_t packet = context->call_resolve_asset(
    context->resolve_asset,
    uri_bytes
  );
  char *packet_text = lepusa_linux_cstr_from_bytes(packet);
  char *cursor = packet_text;
  char *status = lepusa_linux_next_packet_line(&cursor);
  if (packet_text == NULL || status == NULL || strcmp(status, "ok") != 0) {
    const char *message = cursor == NULL ? "asset resolution failed" : cursor;
    lepusa_linux_finish_uri_text(
      context->api,
      request,
      "text/plain",
      message
    );
    free(packet_text);
    return;
  }
  char *kind = lepusa_linux_next_packet_line(&cursor);
  char *mime_type = lepusa_linux_next_packet_line(&cursor);
  char *body = cursor == NULL ? "" : cursor;
  if (kind == NULL || mime_type == NULL) {
    lepusa_linux_finish_uri_text(
      context->api,
      request,
      "text/plain",
      "malformed asset packet"
    );
    free(packet_text);
    return;
  }
  if (strcmp(kind, "virtual") == 0) {
    lepusa_linux_finish_uri_text(context->api, request, mime_type, body);
  } else if (strcmp(kind, "file") == 0) {
    char *data = NULL;
    int64_t length = 0;
    if (lepusa_linux_read_file(body, &data, &length)) {
      lepusa_linux_finish_uri_bytes(
        context->api,
        request,
        mime_type,
        data,
        length
      );
    } else {
      lepusa_linux_finish_uri_text(
        context->api,
        request,
        "text/plain",
        "asset file could not be read"
      );
    }
  } else {
    lepusa_linux_finish_uri_text(
      context->api,
      request,
      "text/plain",
      "unsupported asset packet kind"
    );
  }
  free(packet_text);
}

static void lepusa_linux_script_message_received(
  void *manager,
  void *js_result,
  void *user_data
) {
  (void)manager;
  LepusaLinuxBridgeContext *context = (LepusaLinuxBridgeContext *)user_data;
  if (context == NULL ||
      context->webview == NULL ||
      context->api == NULL ||
      context->call_dispatch == NULL ||
      context->dispatch == NULL) {
    return;
  }
  void *value = context->api->webkit_javascript_result_get_js_value(js_result);
  char *message = value == NULL ? NULL : context->api->jsc_value_to_string(value);
  moonbit_bytes_t request = lepusa_linux_bytes_from_cstr(message);
  moonbit_bytes_t packet = context->call_dispatch(context->dispatch, request);
  moonbit_bytes_t script = lepusa_linux_immediate_script_from_handoff_packet(
    packet
  );
  char *script_text = lepusa_linux_cstr_from_bytes(script);
  LepusaLinuxWindowSlot *slot = lepusa_linux_window_slot_from_handoff_packet(
    context,
    packet
  );
  void *target_webview = slot == NULL ? context->webview : slot->webview;
  if (script_text != NULL && target_webview != NULL) {
    context->api->webkit_web_view_run_javascript(
      target_webview,
      script_text,
      NULL,
      NULL,
      NULL
    );
    free(script_text);
  }
  lepusa_linux_apply_operations_from_handoff_packet(context, packet);
  lepusa_linux_process_bridge_drain_requests(context);
  if (message != NULL) {
    context->api->g_free(message);
  }
}

static void lepusa_linux_free_argv(char **argv, int argc) {
  if (argv == NULL) {
    return;
  }
  for (int i = 0; i < argc; i++) {
    free(argv[i]);
  }
  free(argv);
}

static int lepusa_linux_parse_command_packet(
  moonbit_bytes_t packet,
  char ***argv_out,
  int *argc_out
) {
  if (packet == NULL || argv_out == NULL || argc_out == NULL) {
    return 0;
  }
  const char *cursor = (const char *)packet;
  const char *end = cursor + Moonbit_array_length(packet);
  int capacity = 4;
  int argc = 0;
  char **argv = (char **)calloc((size_t)capacity + 1, sizeof(char *));
  if (argv == NULL) {
    return 0;
  }
  while (cursor < end) {
    int len = 0;
    if (cursor >= end || !isdigit((unsigned char)*cursor)) {
      lepusa_linux_free_argv(argv, argc);
      return 0;
    }
    while (cursor < end && isdigit((unsigned char)*cursor)) {
      len = len * 10 + (*cursor - '0');
      cursor++;
    }
    if (cursor >= end || *cursor != '\n') {
      lepusa_linux_free_argv(argv, argc);
      return 0;
    }
    cursor++;
    if (len < 0 || cursor + len > end) {
      lepusa_linux_free_argv(argv, argc);
      return 0;
    }
    if (argc >= capacity) {
      capacity *= 2;
      char **grown = (char **)realloc(
        argv,
        ((size_t)capacity + 1) * sizeof(char *)
      );
      if (grown == NULL) {
        lepusa_linux_free_argv(argv, argc);
        return 0;
      }
      argv = grown;
    }
    argv[argc] = (char *)malloc((size_t)len + 1);
    if (argv[argc] == NULL) {
      lepusa_linux_free_argv(argv, argc);
      return 0;
    }
    memcpy(argv[argc], cursor, (size_t)len);
    argv[argc][len] = '\0';
    argc++;
    cursor += len;
  }
  if (argc == 0 || argv[0][0] == '\0') {
    lepusa_linux_free_argv(argv, argc);
    return 0;
  }
  argv[argc] = NULL;
  *argv_out = argv;
  *argc_out = argc;
  return 1;
}

static int lepusa_linux_track_service(const char *name, pid_t pid) {
  if (name == NULL || name[0] == '\0') {
    return 0;
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_linux_service_processes[i].name != NULL &&
        strcmp(lepusa_linux_service_processes[i].name, name) == 0) {
      pid_t old_pid = lepusa_linux_service_processes[i].pid;
      if (old_pid > 0) {
        (void)kill(old_pid, SIGTERM);
        (void)waitpid(old_pid, NULL, WNOHANG);
      }
      lepusa_linux_service_processes[i].pid = pid;
      return 1;
    }
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_linux_service_processes[i].name == NULL) {
      lepusa_linux_service_processes[i].name = strdup(name);
      lepusa_linux_service_processes[i].pid = pid;
      return lepusa_linux_service_processes[i].name != NULL;
    }
  }
  return 0;
}

static pid_t lepusa_linux_untrack_service(const char *name) {
  if (name == NULL) {
    return -1;
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_linux_service_processes[i].name != NULL &&
        strcmp(lepusa_linux_service_processes[i].name, name) == 0) {
      pid_t pid = lepusa_linux_service_processes[i].pid;
      free(lepusa_linux_service_processes[i].name);
      lepusa_linux_service_processes[i].name = NULL;
      lepusa_linux_service_processes[i].pid = 0;
      return pid;
    }
  }
  return -1;
}

static void lepusa_linux_terminate_tracked_services(int clear_entries) {
  for (int i = 0; i < 64; i++) {
    pid_t pid = lepusa_linux_service_processes[i].pid;
    if (pid > 0) {
      if (kill(pid, SIGTERM) == 0 || errno == ESRCH) {
        (void)waitpid(pid, NULL, WNOHANG);
      }
    }
    if (clear_entries) {
      free(lepusa_linux_service_processes[i].name);
      lepusa_linux_service_processes[i].name = NULL;
      lepusa_linux_service_processes[i].pid = 0;
    }
  }
}

static void lepusa_linux_cleanup_services_at_exit(void) {
  lepusa_linux_terminate_tracked_services(1);
}

static void lepusa_linux_cleanup_services_on_signal(int signo) {
  lepusa_linux_terminate_tracked_services(0);
  struct sigaction reset_action;
  memset(&reset_action, 0, sizeof(reset_action));
  reset_action.sa_handler = SIG_DFL;
  sigemptyset(&reset_action.sa_mask);
  sigaction(signo, &reset_action, NULL);
  raise(signo);
}

static void lepusa_linux_window_destroyed(void *widget, void *data) {
  LepusaLinuxBridgeContext *context = (LepusaLinuxBridgeContext *)data;
  if (context != NULL) {
    lepusa_linux_remove_window_slot(context, widget);
  }
  if (context == NULL || context->live_windows <= 0) {
    lepusa_linux_terminate_tracked_services(1);
    if (context != NULL &&
        context->api != NULL &&
        context->api->gtk_main_quit != NULL) {
      context->api->gtk_main_quit();
    }
  }
}

static void lepusa_linux_install_service_signal_action(void) {
  struct sigaction action;
  memset(&action, 0, sizeof(action));
  action.sa_handler = lepusa_linux_cleanup_services_on_signal;
  sigemptyset(&action.sa_mask);
  sigaction(SIGINT, &action, NULL);
  sigaction(SIGTERM, &action, NULL);
  sigaction(SIGHUP, &action, NULL);
}

static void lepusa_linux_install_service_cleanup_handlers(void) {
  if (lepusa_linux_service_signal_handlers_installed) {
    return;
  }
  lepusa_linux_service_signal_handlers_installed = 1;
  atexit(lepusa_linux_cleanup_services_at_exit);
  lepusa_linux_install_service_signal_action();
}

static long lepusa_linux_now_ms(void) {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return (long)tv.tv_sec * 1000L + (long)(tv.tv_usec / 1000L);
}

static int lepusa_linux_parse_http_url(
  const char *url,
  char *host,
  size_t host_len,
  char *port,
  size_t port_len,
  char *path,
  size_t path_len
) {
  const char *prefix = "http://";
  size_t prefix_len = strlen(prefix);
  if (url == NULL || strncmp(url, prefix, prefix_len) != 0) {
    return 0;
  }
  const char *authority = url + prefix_len;
  const char *slash = strchr(authority, '/');
  const char *authority_end = slash == NULL ? url + strlen(url) : slash;
  const char *colon = memchr(authority, ':', (size_t)(authority_end - authority));
  const char *host_end = colon == NULL ? authority_end : colon;
  size_t raw_host_len = (size_t)(host_end - authority);
  if (raw_host_len == 0 || raw_host_len >= host_len) {
    return 0;
  }
  memcpy(host, authority, raw_host_len);
  host[raw_host_len] = '\0';
  const char *raw_port = colon == NULL ? "80" : colon + 1;
  size_t raw_port_len = (size_t)(authority_end - raw_port);
  if (raw_port_len == 0 || raw_port_len >= port_len) {
    return 0;
  }
  memcpy(port, raw_port, raw_port_len);
  port[raw_port_len] = '\0';
  const char *raw_path = slash == NULL ? "/" : slash;
  size_t raw_path_len = strlen(raw_path);
  if (raw_path_len == 0 || raw_path_len >= path_len) {
    return 0;
  }
  memcpy(path, raw_path, raw_path_len);
  path[raw_path_len] = '\0';
  return 1;
}

static int lepusa_linux_try_http_ready(
  const char *host,
  const char *port,
  const char *path
) {
  struct addrinfo hints;
  struct addrinfo *result = NULL;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  if (getaddrinfo(host, port, &hints, &result) != 0) {
    return 0;
  }
  int ready = 0;
  for (struct addrinfo *rp = result; rp != NULL && !ready; rp = rp->ai_next) {
    int fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
    if (fd < 0) {
      continue;
    }
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0) {
      (void)fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
    int connected = connect(fd, rp->ai_addr, rp->ai_addrlen) == 0;
    if (!connected && errno == EINPROGRESS) {
      struct pollfd pfd = { fd, POLLOUT, 0 };
      if (poll(&pfd, 1, 500) > 0 && (pfd.revents & POLLOUT) != 0) {
        int error = 0;
        socklen_t error_len = sizeof(error);
        connected = getsockopt(
          fd,
          SOL_SOCKET,
          SO_ERROR,
          &error,
          &error_len
        ) == 0 && error == 0;
      }
    }
    if (flags >= 0) {
      (void)fcntl(fd, F_SETFL, flags);
    }
    if (connected) {
      char request[1024];
      snprintf(
        request,
        sizeof(request),
        "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n",
        path,
        host
      );
      (void)send(fd, request, strlen(request), 0);
      char response[64];
      ssize_t n = recv(fd, response, sizeof(response) - 1, 0);
      if (n > 0) {
        response[n] = '\0';
        ready = strncmp(response, "HTTP/", 5) == 0 &&
          response[9] >= '2' &&
          response[9] <= '3';
      }
    }
    close(fd);
  }
  freeaddrinfo(result);
  return ready;
}
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_linux_backend_available(void) {
#if defined(__linux__)
  void *gtk = dlopen("libgtk-3.so.0", RTLD_LAZY | RTLD_LOCAL);
  if (gtk == NULL) {
    return 0;
  }
  dlclose(gtk);
  const char *libraries[] = {
    "libwebkit2gtk-4.1.so.0",
    "libwebkit2gtk-4.0.so.37"
  };
  for (int i = 0; i < 2; i++) {
    void *handle = dlopen(libraries[i], RTLD_LAZY | RTLD_LOCAL);
    if (handle != NULL) {
      dlclose(handle);
      return 1;
    }
  }
#endif
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_linux_backend_engine_name(void) {
  const char *name = "WebKitGTK";
  int32_t len = (int32_t)strlen(name);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, name, len);
  return bytes;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_linux_run_webview(
  moonbit_bytes_t label,
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  moonbit_bytes_t native_hook,
  moonbit_bytes_t asset_protocol,
  moonbit_bytes_t initial_open_packet,
  int32_t width,
  int32_t height,
  int32_t resizable,
  LepusaLinuxBytesCallback call_dispatch,
  void *dispatch,
  LepusaLinuxBytesCallback call_resolve_asset,
  void *resolve_asset
) {
#if defined(__linux__)
  LepusaLinuxWebKit api;
  if (!lepusa_linux_load_webkit(&api)) {
    return 2;
  }
  char *title_text = lepusa_linux_cstr_from_bytes(title);
  char *label_text = lepusa_linux_cstr_from_bytes(label);
  char *url_text = lepusa_linux_cstr_from_bytes(url);
  char *script_text = lepusa_linux_cstr_from_bytes(initialization_script);
  char *native_hook_text = lepusa_linux_cstr_from_bytes(native_hook);
  char *asset_protocol_text = lepusa_linux_cstr_from_bytes(asset_protocol);
  if (title_text == NULL ||
      label_text == NULL ||
      url_text == NULL ||
      script_text == NULL ||
      native_hook_text == NULL ||
      asset_protocol_text == NULL) {
    free(title_text);
    free(label_text);
    free(url_text);
    free(script_text);
    free(native_hook_text);
    free(asset_protocol_text);
    return 3;
  }
  int argc = 0;
  char **argv = NULL;
  if (!api.gtk_init_check(&argc, &argv)) {
    free(title_text);
    free(label_text);
    free(url_text);
    free(script_text);
    free(native_hook_text);
    free(asset_protocol_text);
    return 2;
  }
  void *window = api.gtk_window_new(0);
  void *manager = api.webkit_user_content_manager_new();
  if (window == NULL || manager == NULL) {
    free(title_text);
    free(label_text);
    free(url_text);
    free(script_text);
    free(native_hook_text);
    free(asset_protocol_text);
    return 4;
  }
  if (native_hook_text[0] != '\0' &&
      call_dispatch != NULL &&
      dispatch != NULL) {
    api.webkit_user_content_manager_register_script_message_handler(
      manager,
      native_hook_text
    );
  }
  void *script = api.webkit_user_script_new(script_text, 0, 0, NULL, NULL);
  if (script != NULL) {
    api.webkit_user_content_manager_add_script(manager, script);
  }
  void *webview = api.webkit_web_view_new_with_user_content_manager(manager);
  void *box = api.gtk_box_new(1, 0);
  if (webview == NULL || box == NULL) {
    free(title_text);
    free(label_text);
    free(url_text);
    free(script_text);
    free(native_hook_text);
    free(asset_protocol_text);
    return 5;
  }
  LepusaLinuxBridgeContext bridge_context = {
    .window = window,
    .webview = webview,
    .windows = { 0 },
    .window_count = 0,
    .live_windows = 0,
    .drain_requests = { 0 },
    .drain_request_count = 0,
    .tray_icon = NULL,
    .tray_menu = NULL,
    .app_menu_payload = NULL,
    .app_menu_payload_len = 0,
    .api = &api,
    .call_dispatch = call_dispatch,
    .dispatch = dispatch,
    .call_resolve_asset = call_resolve_asset,
    .resolve_asset = resolve_asset
  };
  if (asset_protocol_text[0] != '\0' &&
      call_resolve_asset != NULL &&
      resolve_asset != NULL) {
    void *context = api.webkit_web_view_get_context(webview);
    if (context != NULL) {
      api.webkit_web_context_register_uri_scheme(
        context,
        asset_protocol_text,
        (void *)lepusa_linux_uri_scheme_request,
        &bridge_context,
        NULL
      );
    }
  }
  lepusa_linux_register_window_slot(
    &bridge_context,
    label_text,
    (int32_t)strlen(label_text),
    window,
    box,
    webview
  );
  if (native_hook_text[0] != '\0' &&
      call_dispatch != NULL &&
      dispatch != NULL) {
    char signal_name[256];
    snprintf(
      signal_name,
      sizeof(signal_name),
      "script-message-received::%s",
      native_hook_text
    );
    api.g_signal_connect_data(
      manager,
      signal_name,
      (void *)lepusa_linux_script_message_received,
      &bridge_context,
      NULL,
      0
    );
  }
  api.gtk_window_set_title(window, title_text);
  api.g_signal_connect_data(
    window,
    "destroy",
    (void *)lepusa_linux_window_destroyed,
    &bridge_context,
    NULL,
    0
  );
  api.gtk_window_set_default_size(
    window,
    width > 0 ? width : 960,
    height > 0 ? height : 640
  );
  api.gtk_window_set_resizable(window, resizable != 0);
  api.gtk_container_add(window, box);
  api.gtk_box_pack_start(box, webview, 1, 1, 0);
  api.webkit_web_view_load_uri(webview, url_text);
  api.gtk_widget_show_all(window);
  lepusa_linux_apply_open_windows_from_handoff_packet(
    &bridge_context,
    initial_open_packet
  );
  api.gtk_main();
  lepusa_linux_destroy_tray(&bridge_context);
  free(bridge_context.app_menu_payload);
  free(title_text);
  free(label_text);
  free(url_text);
  free(script_text);
  free(native_hook_text);
  free(asset_protocol_text);
  return 0;
#else
  (void)label;
  (void)title;
  (void)url;
  (void)initialization_script;
  (void)native_hook;
  (void)asset_protocol;
  (void)initial_open_packet;
  (void)width;
  (void)height;
  (void)resizable;
  (void)call_dispatch;
  (void)dispatch;
  (void)call_resolve_asset;
  (void)resolve_asset;
  return 2;
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_linux_start_service(
  moonbit_bytes_t name,
  moonbit_bytes_t command_packet
) {
#if defined(__linux__)
  char *service_name = lepusa_linux_cstr_from_bytes(name);
  char **argv = NULL;
  int argc = 0;
  if (service_name == NULL ||
      !lepusa_linux_parse_command_packet(command_packet, &argv, &argc)) {
    free(service_name);
    return 1;
  }
  pid_t pid = 0;
  int spawn_error = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
  lepusa_linux_free_argv(argv, argc);
  if (spawn_error != 0) {
    free(service_name);
    return 2;
  }
  if (!lepusa_linux_track_service(service_name, pid)) {
    kill(pid, SIGTERM);
    free(service_name);
    return 3;
  }
  lepusa_linux_install_service_cleanup_handlers();
  free(service_name);
  return 0;
#else
  (void)name;
  (void)command_packet;
  return 2;
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_linux_stop_service(moonbit_bytes_t name) {
#if defined(__linux__)
  char *service_name = lepusa_linux_cstr_from_bytes(name);
  if (service_name == NULL) {
    return 2;
  }
  pid_t pid = lepusa_linux_untrack_service(service_name);
  free(service_name);
  if (pid <= 0) {
    return 1;
  }
  if (kill(pid, SIGTERM) != 0 && errno != ESRCH) {
    return 2;
  }
  (void)waitpid(pid, NULL, WNOHANG);
  return 0;
#else
  (void)name;
  return 1;
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_linux_wait_until_ready(
  moonbit_bytes_t readiness_url,
  int32_t timeout_ms
) {
#if defined(__linux__)
  char *url = lepusa_linux_cstr_from_bytes(readiness_url);
  char host[256];
  char port[16];
  char path[512];
  if (url == NULL ||
      !lepusa_linux_parse_http_url(url, host, sizeof(host), port, sizeof(port), path, sizeof(path))) {
    free(url);
    return 2;
  }
  free(url);
  long deadline = lepusa_linux_now_ms() + (timeout_ms <= 0 ? 1 : timeout_ms);
  do {
    if (lepusa_linux_try_http_ready(host, port, path)) {
      return 0;
    }
    usleep(100000);
  } while (lepusa_linux_now_ms() < deadline);
  return 1;
#else
  (void)readiness_url;
  (void)timeout_ms;
  return 2;
#endif
}
