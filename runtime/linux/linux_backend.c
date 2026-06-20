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
typedef void *(*LepusaGtkWindowNew)(int);
typedef void (*LepusaGtkWindowSetTitle)(void *, const char *);
typedef void (*LepusaGtkWindowSetDefaultSize)(void *, int, int);
typedef void (*LepusaGtkWindowSetResizable)(void *, int);
typedef void (*LepusaGtkContainerAdd)(void *, void *);
typedef void (*LepusaGtkWidgetShowAll)(void *);
typedef void (*LepusaGtkMain)(void);
typedef void (*LepusaGtkMainQuit)(void);
typedef void (*LepusaGFree)(void *);
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
  LepusaGtkWindowNew gtk_window_new;
  LepusaGtkWindowSetTitle gtk_window_set_title;
  LepusaGtkWindowSetDefaultSize gtk_window_set_default_size;
  LepusaGtkWindowSetResizable gtk_window_set_resizable;
  LepusaGtkContainerAdd gtk_container_add;
  LepusaGtkWidgetShowAll gtk_widget_show_all;
  LepusaGtkMain gtk_main;
  LepusaGtkMainQuit gtk_main_quit;
  LepusaGFree g_free;
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
  void *webview;
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
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_new", (void **)&api->gtk_window_new);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_set_title", (void **)&api->gtk_window_set_title);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_set_default_size", (void **)&api->gtk_window_set_default_size);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_window_set_resizable", (void **)&api->gtk_window_set_resizable);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_container_add", (void **)&api->gtk_container_add);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_widget_show_all", (void **)&api->gtk_widget_show_all);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_main", (void **)&api->gtk_main);
  ok = ok && lepusa_linux_load_symbol(api->gtk, "gtk_main_quit", (void **)&api->gtk_main_quit);
  ok = ok && lepusa_linux_load_symbol(api->glib, "g_free", (void **)&api->g_free);
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
  if (script_text != NULL) {
    context->api->webkit_web_view_run_javascript(
      context->webview,
      script_text,
      NULL,
      NULL,
      NULL
    );
    free(script_text);
  }
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
  signal(signo, SIG_DFL);
  raise(signo);
}

static void lepusa_linux_install_service_cleanup_handlers(void) {
  if (lepusa_linux_service_signal_handlers_installed) {
    return;
  }
  lepusa_linux_service_signal_handlers_installed = 1;
  atexit(lepusa_linux_cleanup_services_at_exit);
  signal(SIGINT, lepusa_linux_cleanup_services_on_signal);
  signal(SIGTERM, lepusa_linux_cleanup_services_on_signal);
  signal(SIGHUP, lepusa_linux_cleanup_services_on_signal);
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
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  moonbit_bytes_t native_hook,
  moonbit_bytes_t asset_protocol,
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
  char *url_text = lepusa_linux_cstr_from_bytes(url);
  char *script_text = lepusa_linux_cstr_from_bytes(initialization_script);
  char *native_hook_text = lepusa_linux_cstr_from_bytes(native_hook);
  char *asset_protocol_text = lepusa_linux_cstr_from_bytes(asset_protocol);
  if (title_text == NULL ||
      url_text == NULL ||
      script_text == NULL ||
      native_hook_text == NULL ||
      asset_protocol_text == NULL) {
    free(title_text);
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
  if (webview == NULL) {
    free(title_text);
    free(url_text);
    free(script_text);
    free(native_hook_text);
    free(asset_protocol_text);
    return 5;
  }
  LepusaLinuxBridgeContext bridge_context = {
    webview,
    &api,
    call_dispatch,
    dispatch,
    call_resolve_asset,
    resolve_asset
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
    (void *)api.gtk_main_quit,
    NULL,
    NULL,
    0
  );
  api.gtk_window_set_default_size(
    window,
    width > 0 ? width : 960,
    height > 0 ? height : 640
  );
  api.gtk_window_set_resizable(window, resizable != 0);
  api.gtk_container_add(window, webview);
  api.webkit_web_view_load_uri(webview, url_text);
  api.gtk_widget_show_all(window);
  api.gtk_main();
  free(title_text);
  free(url_text);
  free(script_text);
  free(native_hook_text);
  free(asset_protocol_text);
  return 0;
#else
  (void)title;
  (void)url;
  (void)initialization_script;
  (void)native_hook;
  (void)asset_protocol;
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
