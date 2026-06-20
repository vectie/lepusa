#include <moonbit.h>
#include <string.h>

#if defined(__APPLE__)

#include <dlfcn.h>
#include <ctype.h>
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
  double x;
  double y;
} LepusaPoint;

typedef struct {
  double width;
  double height;
} LepusaSize;

typedef struct {
  LepusaPoint origin;
  LepusaSize size;
} LepusaRect;

static const unsigned long LEPUSA_NS_WINDOW_STYLE_TITLED = 1UL << 0;
static const unsigned long LEPUSA_NS_WINDOW_STYLE_CLOSABLE = 1UL << 1;
static const unsigned long LEPUSA_NS_WINDOW_STYLE_MINIATURIZABLE = 1UL << 2;
static const unsigned long LEPUSA_NS_WINDOW_STYLE_RESIZABLE = 1UL << 3;
static const unsigned long LEPUSA_NS_BACKING_STORE_BUFFERED = 2UL;
static const int LEPUSA_NS_APPLICATION_ACTIVATION_POLICY_REGULAR = 0;

typedef void *(*LepusaMsgSendId)(void *, void *);
typedef void *(*LepusaMsgSendIdId)(void *, void *, void *);
typedef void *(*LepusaMsgSendIdCStr)(void *, void *, const char *);
typedef void *(*LepusaMsgSendIdRect)(void *, void *, LepusaRect);
typedef void *(*LepusaMsgSendIdRectId)(void *, void *, LepusaRect, void *);
typedef void *(*LepusaMsgSendIdRectStyle)(void *, void *, LepusaRect, unsigned long, unsigned long, int);
typedef void *(*LepusaMsgSendIdScript)(void *, void *, void *, long, int);
typedef void *(*LepusaMsgSendIdIdIdLongId)(void *, void *, void *, void *, long long, void *);
typedef void *(*LepusaMsgSendIdPtrULong)(void *, void *, const void *, unsigned long);
typedef const char *(*LepusaMsgSendCString)(void *, void *);
typedef void (*LepusaMsgSendVoid)(void *, void *);
typedef void (*LepusaMsgSendVoidId)(void *, void *, void *);
typedef void (*LepusaMsgSendVoidIdId)(void *, void *, void *, void *);
typedef void (*LepusaMsgSendVoidInt)(void *, void *, int);
typedef int (*LepusaMsgSendIntInt)(void *, void *, int);
typedef void *(*LepusaObjcGetClass)(const char *);
typedef void *(*LepusaSelRegisterName)(const char *);
typedef void *(*LepusaObjcAllocateClassPair)(void *, const char *, size_t);
typedef void (*LepusaObjcRegisterClassPair)(void *);
typedef int (*LepusaClassAddMethod)(void *, void *, void *, const char *);
typedef void *LepusaObjcMsgSend;
typedef moonbit_bytes_t (*LepusaBytesCallback)(void *, moonbit_bytes_t);

typedef struct {
  void *webview;
  LepusaBytesCallback call_dispatch;
  void *dispatch;
  LepusaBytesCallback call_resolve_asset;
  void *resolve_asset;
} LepusaBridgeContext;

static LepusaObjcGetClass lepusa_objc_get_class = NULL;
static LepusaSelRegisterName lepusa_sel_register_name = NULL;
static LepusaObjcMsgSend lepusa_objc_msg_send = NULL;
static LepusaObjcAllocateClassPair lepusa_objc_allocate_class_pair = NULL;
static LepusaObjcRegisterClassPair lepusa_objc_register_class_pair = NULL;
static LepusaClassAddMethod lepusa_class_add_method = NULL;
static LepusaBridgeContext *lepusa_current_bridge_context = NULL;

typedef struct {
  char *name;
  pid_t pid;
} LepusaServiceProcess;

static LepusaServiceProcess lepusa_service_processes[64];

static void *lepusa_cls(const char *name) {
  return lepusa_objc_get_class == NULL ? NULL : lepusa_objc_get_class(name);
}

static void *lepusa_sel(const char *name) {
  return lepusa_sel_register_name == NULL ? NULL : lepusa_sel_register_name(name);
}

static void *lepusa_msg_id(void *target, const char *selector) {
  return ((LepusaMsgSendId)lepusa_objc_msg_send)(target, lepusa_sel(selector));
}

static void lepusa_msg_void_id(void *target, const char *selector, void *arg) {
  ((LepusaMsgSendVoidId)lepusa_objc_msg_send)(target, lepusa_sel(selector), arg);
}

static void lepusa_msg_void_id_id(
  void *target,
  const char *selector,
  void *arg1,
  void *arg2
) {
  ((LepusaMsgSendVoidIdId)lepusa_objc_msg_send)(
    target,
    lepusa_sel(selector),
    arg1,
    arg2
  );
}

static void lepusa_msg_void_int(void *target, const char *selector, int arg) {
  ((LepusaMsgSendVoidInt)lepusa_objc_msg_send)(target, lepusa_sel(selector), arg);
}

static moonbit_bytes_t lepusa_bytes_from_cstr(const char *text) {
  const char *safe = text == NULL ? "" : text;
  int32_t len = (int32_t)strlen(safe);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, safe, len);
  return bytes;
}

static char *lepusa_cstr_from_bytes(moonbit_bytes_t bytes) {
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

static void lepusa_free_argv(char **argv, int argc) {
  if (argv == NULL) {
    return;
  }
  for (int i = 0; i < argc; i++) {
    free(argv[i]);
  }
  free(argv);
}

static int lepusa_parse_command_packet(
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
      lepusa_free_argv(argv, argc);
      return 0;
    }
    while (cursor < end && isdigit((unsigned char)*cursor)) {
      len = len * 10 + (*cursor - '0');
      cursor++;
    }
    if (cursor >= end || *cursor != '\n') {
      lepusa_free_argv(argv, argc);
      return 0;
    }
    cursor++;
    if (len < 0 || cursor + len > end) {
      lepusa_free_argv(argv, argc);
      return 0;
    }
    if (argc >= capacity) {
      capacity *= 2;
      char **grown = (char **)realloc(
        argv,
        ((size_t)capacity + 1) * sizeof(char *)
      );
      if (grown == NULL) {
        lepusa_free_argv(argv, argc);
        return 0;
      }
      argv = grown;
    }
    argv[argc] = (char *)malloc((size_t)len + 1);
    if (argv[argc] == NULL) {
      lepusa_free_argv(argv, argc);
      return 0;
    }
    memcpy(argv[argc], cursor, (size_t)len);
    argv[argc][len] = '\0';
    argc++;
    cursor += len;
  }
  if (argc == 0 || argv[0][0] == '\0') {
    lepusa_free_argv(argv, argc);
    return 0;
  }
  argv[argc] = NULL;
  *argv_out = argv;
  *argc_out = argc;
  return 1;
}

static int lepusa_track_service(const char *name, pid_t pid) {
  if (name == NULL || name[0] == '\0') {
    return 0;
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_service_processes[i].name != NULL &&
        strcmp(lepusa_service_processes[i].name, name) == 0) {
      lepusa_service_processes[i].pid = pid;
      return 1;
    }
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_service_processes[i].name == NULL) {
      lepusa_service_processes[i].name = strdup(name);
      lepusa_service_processes[i].pid = pid;
      return lepusa_service_processes[i].name != NULL;
    }
  }
  return 0;
}

static pid_t lepusa_untrack_service(const char *name) {
  if (name == NULL) {
    return -1;
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_service_processes[i].name != NULL &&
        strcmp(lepusa_service_processes[i].name, name) == 0) {
      pid_t pid = lepusa_service_processes[i].pid;
      free(lepusa_service_processes[i].name);
      lepusa_service_processes[i].name = NULL;
      lepusa_service_processes[i].pid = 0;
      return pid;
    }
  }
  return -1;
}

static long lepusa_now_ms(void) {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return (long)tv.tv_sec * 1000L + (long)(tv.tv_usec / 1000L);
}

static int lepusa_parse_http_url(
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

static int lepusa_try_http_ready(
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

static moonbit_bytes_t lepusa_bytes_from_range(const char *text, int32_t len) {
  int32_t safe_len = len < 0 ? 0 : len;
  moonbit_bytes_t bytes = moonbit_make_bytes(safe_len, 0);
  if (text != NULL && safe_len > 0) {
    memcpy(bytes, text, safe_len);
  }
  return bytes;
}

static void *lepusa_ns_string(moonbit_bytes_t bytes) {
  return ((LepusaMsgSendIdCStr)lepusa_objc_msg_send)(
    lepusa_cls("NSString"),
    lepusa_sel("stringWithUTF8String:"),
    (const char *)bytes
  );
}

static void *lepusa_ns_url(moonbit_bytes_t bytes) {
  void *url_string = lepusa_ns_string(bytes);
  return ((LepusaMsgSendIdId)lepusa_objc_msg_send)(
    lepusa_cls("NSURL"),
    lepusa_sel("URLWithString:"),
    url_string
  );
}

static void *lepusa_ns_string_from_range(const char *text, int32_t len) {
  return lepusa_ns_string(lepusa_bytes_from_range(text, len));
}

static void *lepusa_ns_data_from_range(const char *text, int32_t len) {
  int32_t safe_len = len < 0 ? 0 : len;
  return ((LepusaMsgSendIdPtrULong)lepusa_objc_msg_send)(
    lepusa_cls("NSData"),
    lepusa_sel("dataWithBytes:length:"),
    text == NULL ? "" : text,
    (unsigned long)safe_len
  );
}

static const char *lepusa_find_newline(const char *start, const char *end) {
  const char *cursor = start;
  while (cursor < end) {
    if (*cursor == '\n') {
      return cursor;
    }
    cursor++;
  }
  return NULL;
}

static moonbit_bytes_t lepusa_immediate_script_from_handoff_packet(
  moonbit_bytes_t packet
) {
  if (packet == NULL) {
    return NULL;
  }
  const char *start = (const char *)packet;
  const char *end = start + Moonbit_array_length(packet);
  const char *first = lepusa_find_newline(start, end);
  if (first == NULL ||
      (first - start) != 9 ||
      memcmp(start, "immediate", 9) != 0) {
    return NULL;
  }
  const char *second = lepusa_find_newline(first + 1, end);
  if (second == NULL) {
    return NULL;
  }
  const char *body = second + 1;
  int32_t body_len = (int32_t)(end - body);
  moonbit_bytes_t script = moonbit_make_bytes(body_len, 0);
  if (body_len > 0) {
    memcpy(script, body, (size_t)body_len);
  }
  return script;
}

static void lepusa_send_scheme_data(
  void *task,
  void *url,
  const char *mime,
  int32_t mime_len,
  void *data
) {
  void *response_alloc = lepusa_msg_id(lepusa_cls("NSURLResponse"), "alloc");
  void *response = ((LepusaMsgSendIdIdIdLongId)lepusa_objc_msg_send)(
    response_alloc,
    lepusa_sel("initWithURL:MIMEType:expectedContentLength:textEncodingName:"),
    url,
    lepusa_ns_string_from_range(mime, mime_len),
    -1,
    NULL
  );
  if (response == NULL || data == NULL) {
    return;
  }
  lepusa_msg_void_id(task, "didReceiveResponse:", response);
  lepusa_msg_void_id(task, "didReceiveData:", data);
  ((LepusaMsgSendVoid)lepusa_objc_msg_send)(task, lepusa_sel("didFinish"));
}

static void lepusa_send_scheme_error(
  void *task,
  void *url,
  const char *message,
  int32_t message_len
) {
  lepusa_send_scheme_data(
    task,
    url,
    "text/plain",
    10,
    lepusa_ns_data_from_range(message, message_len)
  );
}

static void lepusa_finish_scheme_task(
  void *task,
  void *url,
  moonbit_bytes_t packet
) {
  if (packet == NULL) {
    lepusa_send_scheme_error(task, url, "empty asset response", 20);
    return;
  }
  const char *start = (const char *)packet;
  const char *end = start + Moonbit_array_length(packet);
  const char *first = lepusa_find_newline(start, end);
  if (first == NULL) {
    lepusa_send_scheme_error(task, url, "invalid asset response", 22);
    return;
  }
  if ((first - start) == 5 && memcmp(start, "error", 5) == 0) {
    lepusa_send_scheme_error(
      task,
      url,
      first + 1,
      (int32_t)(end - first - 1)
    );
    return;
  }
  if ((first - start) != 2 || memcmp(start, "ok", 2) != 0) {
    lepusa_send_scheme_error(task, url, "invalid asset status", 20);
    return;
  }

  const char *second = lepusa_find_newline(first + 1, end);
  if (second == NULL) {
    lepusa_send_scheme_error(task, url, "missing asset kind", 18);
    return;
  }
  const char *third = lepusa_find_newline(second + 1, end);
  if (third == NULL) {
    lepusa_send_scheme_error(task, url, "missing asset mime", 18);
    return;
  }
  const char *kind = first + 1;
  int32_t kind_len = (int32_t)(second - kind);
  const char *mime = second + 1;
  int32_t mime_len = (int32_t)(third - mime);
  const char *body = third + 1;
  int32_t body_len = (int32_t)(end - body);

  if (kind_len == 7 && memcmp(kind, "virtual", 7) == 0) {
    lepusa_send_scheme_data(
      task,
      url,
      mime,
      mime_len,
      lepusa_ns_data_from_range(body, body_len)
    );
  } else if (kind_len == 4 && memcmp(kind, "file", 4) == 0) {
    void *data = ((LepusaMsgSendIdId)lepusa_objc_msg_send)(
      lepusa_cls("NSData"),
      lepusa_sel("dataWithContentsOfFile:"),
      lepusa_ns_string_from_range(body, body_len)
    );
    if (data == NULL) {
      lepusa_send_scheme_error(task, url, "asset file could not be read", 28);
      return;
    }
    lepusa_send_scheme_data(task, url, mime, mime_len, data);
  } else {
    lepusa_send_scheme_error(task, url, "unsupported asset kind", 22);
  }
}

static void lepusa_script_message_handler(
  void *self,
  void *selector,
  void *user_content_controller,
  void *message
) {
  (void)self;
  (void)selector;
  (void)user_content_controller;
  LepusaBridgeContext *context = lepusa_current_bridge_context;
  if (context == NULL ||
      context->webview == NULL ||
      context->call_dispatch == NULL ||
      context->dispatch == NULL) {
    return;
  }

  void *body = lepusa_msg_id(message, "body");
  void *body_description = body == NULL ? NULL : lepusa_msg_id(body, "description");
  const char *body_text = body_description == NULL
    ? ""
    : ((LepusaMsgSendCString)lepusa_objc_msg_send)(
        body_description,
        lepusa_sel("UTF8String")
      );
  moonbit_bytes_t request = lepusa_bytes_from_cstr(body_text);
  moonbit_bytes_t packet = context->call_dispatch(context->dispatch, request);
  moonbit_bytes_t script = lepusa_immediate_script_from_handoff_packet(packet);
  if (script == NULL) {
    return;
  }
  lepusa_msg_void_id_id(
    context->webview,
    "evaluateJavaScript:completionHandler:",
    lepusa_ns_string_from_range(
      (const char *)script,
      Moonbit_array_length(script)
    ),
    NULL
  );
}

static void lepusa_url_scheme_start_task(
  void *self,
  void *selector,
  void *webview,
  void *task
) {
  (void)self;
  (void)selector;
  (void)webview;
  LepusaBridgeContext *context = lepusa_current_bridge_context;
  if (context == NULL ||
      context->call_resolve_asset == NULL ||
      context->resolve_asset == NULL) {
    return;
  }

  void *request = lepusa_msg_id(task, "request");
  void *url = request == NULL ? NULL : lepusa_msg_id(request, "URL");
  void *absolute = url == NULL ? NULL : lepusa_msg_id(url, "absoluteString");
  const char *url_text = absolute == NULL
    ? ""
    : ((LepusaMsgSendCString)lepusa_objc_msg_send)(
        absolute,
        lepusa_sel("UTF8String")
      );
  moonbit_bytes_t request_url = lepusa_bytes_from_cstr(url_text);
  moonbit_bytes_t packet = context->call_resolve_asset(
    context->resolve_asset,
    request_url
  );
  lepusa_finish_scheme_task(task, url, packet);
}

static void lepusa_url_scheme_stop_task(
  void *self,
  void *selector,
  void *webview,
  void *task
) {
  (void)self;
  (void)selector;
  (void)webview;
  (void)task;
}

static void *lepusa_bridge_handler_class(void) {
  static void *handler_class = NULL;
  if (handler_class != NULL) {
    return handler_class;
  }
  handler_class = lepusa_objc_get_class("LepusaWKScriptMessageHandler");
  if (handler_class != NULL) {
    return handler_class;
  }
  void *superclass = lepusa_cls("NSObject");
  if (superclass == NULL ||
      lepusa_objc_allocate_class_pair == NULL ||
      lepusa_objc_register_class_pair == NULL ||
      lepusa_class_add_method == NULL) {
    return NULL;
  }
  handler_class = lepusa_objc_allocate_class_pair(
    superclass,
    "LepusaWKScriptMessageHandler",
    0
  );
  if (handler_class == NULL) {
    return NULL;
  }
  lepusa_class_add_method(
    handler_class,
    lepusa_sel("userContentController:didReceiveScriptMessage:"),
    (void *)lepusa_script_message_handler,
    "v@:@@"
  );
  lepusa_objc_register_class_pair(handler_class);
  return handler_class;
}

static void *lepusa_url_scheme_handler_class(void) {
  static void *handler_class = NULL;
  if (handler_class != NULL) {
    return handler_class;
  }
  handler_class = lepusa_objc_get_class("LepusaWKURLSchemeHandler");
  if (handler_class != NULL) {
    return handler_class;
  }
  void *superclass = lepusa_cls("NSObject");
  if (superclass == NULL ||
      lepusa_objc_allocate_class_pair == NULL ||
      lepusa_objc_register_class_pair == NULL ||
      lepusa_class_add_method == NULL) {
    return NULL;
  }
  handler_class = lepusa_objc_allocate_class_pair(
    superclass,
    "LepusaWKURLSchemeHandler",
    0
  );
  if (handler_class == NULL) {
    return NULL;
  }
  lepusa_class_add_method(
    handler_class,
    lepusa_sel("webView:startURLSchemeTask:"),
    (void *)lepusa_url_scheme_start_task,
    "v@:@@"
  );
  lepusa_class_add_method(
    handler_class,
    lepusa_sel("webView:stopURLSchemeTask:"),
    (void *)lepusa_url_scheme_stop_task,
    "v@:@@"
  );
  lepusa_objc_register_class_pair(handler_class);
  return handler_class;
}

static int lepusa_load_frameworks(void) {
  void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY | RTLD_LOCAL);
  void *cocoa = dlopen(
    "/System/Library/Frameworks/Cocoa.framework/Cocoa",
    RTLD_LAZY | RTLD_LOCAL
  );
  void *webkit = dlopen(
    "/System/Library/Frameworks/WebKit.framework/WebKit",
    RTLD_LAZY | RTLD_LOCAL
  );
  if (objc == NULL || cocoa == NULL || webkit == NULL) {
    return 0;
  }
  lepusa_objc_get_class = (LepusaObjcGetClass)dlsym(objc, "objc_getClass");
  lepusa_sel_register_name = (LepusaSelRegisterName)dlsym(objc, "sel_registerName");
  lepusa_objc_msg_send = (LepusaObjcMsgSend)dlsym(objc, "objc_msgSend");
  lepusa_objc_allocate_class_pair = (LepusaObjcAllocateClassPair)dlsym(objc, "objc_allocateClassPair");
  lepusa_objc_register_class_pair = (LepusaObjcRegisterClassPair)dlsym(objc, "objc_registerClassPair");
  lepusa_class_add_method = (LepusaClassAddMethod)dlsym(objc, "class_addMethod");
  return lepusa_objc_get_class != NULL &&
    lepusa_sel_register_name != NULL &&
    lepusa_objc_msg_send != NULL &&
    lepusa_objc_allocate_class_pair != NULL &&
    lepusa_objc_register_class_pair != NULL &&
    lepusa_class_add_method != NULL;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_macos_backend_available(void) {
  return lepusa_load_frameworks() ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_macos_backend_engine_name(void) {
  const char *name = "WKWebView";
  int32_t len = (int32_t)strlen(name);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, name, len);
  return bytes;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_macos_start_service(
  moonbit_bytes_t name,
  moonbit_bytes_t command_packet
) {
  char *service_name = lepusa_cstr_from_bytes(name);
  char **argv = NULL;
  int argc = 0;
  if (service_name == NULL ||
      !lepusa_parse_command_packet(command_packet, &argv, &argc)) {
    free(service_name);
    return 1;
  }
  pid_t pid = 0;
  int spawn_error = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
  lepusa_free_argv(argv, argc);
  if (spawn_error != 0) {
    free(service_name);
    return 2;
  }
  if (!lepusa_track_service(service_name, pid)) {
    kill(pid, SIGTERM);
    free(service_name);
    return 3;
  }
  free(service_name);
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_macos_stop_service(moonbit_bytes_t name) {
  char *service_name = lepusa_cstr_from_bytes(name);
  if (service_name == NULL) {
    return 2;
  }
  pid_t pid = lepusa_untrack_service(service_name);
  free(service_name);
  if (pid <= 0) {
    return 1;
  }
  if (kill(pid, SIGTERM) != 0 && errno != ESRCH) {
    return 2;
  }
  (void)waitpid(pid, NULL, WNOHANG);
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_macos_wait_until_ready(
  moonbit_bytes_t readiness_url,
  int32_t timeout_ms
) {
  char *url = lepusa_cstr_from_bytes(readiness_url);
  char host[256];
  char port[16];
  char path[512];
  if (url == NULL ||
      !lepusa_parse_http_url(url, host, sizeof(host), port, sizeof(port), path, sizeof(path))) {
    free(url);
    return 2;
  }
  free(url);
  long deadline = lepusa_now_ms() + (timeout_ms <= 0 ? 1 : timeout_ms);
  do {
    if (lepusa_try_http_ready(host, port, path)) {
      return 0;
    }
    usleep(100000);
  } while (lepusa_now_ms() < deadline);
  return 1;
}

static int32_t lepusa_macos_run_webview_impl(
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  moonbit_bytes_t native_hook,
  moonbit_bytes_t asset_protocol,
  int32_t width,
  int32_t height,
  int32_t resizable,
  LepusaBytesCallback call_dispatch,
  void *dispatch,
  LepusaBytesCallback call_resolve_asset,
  void *resolve_asset
) {
  if (!lepusa_load_frameworks()) {
    return 2;
  }

  void *ns_application = lepusa_cls("NSApplication");
  void *app = ((LepusaMsgSendId)lepusa_objc_msg_send)(
    ns_application,
    lepusa_sel("sharedApplication")
  );
  if (app == NULL) {
    return 3;
  }

  ((LepusaMsgSendIntInt)lepusa_objc_msg_send)(
    app,
    lepusa_sel("setActivationPolicy:"),
    LEPUSA_NS_APPLICATION_ACTIVATION_POLICY_REGULAR
  );

  LepusaRect frame = {
    { 0.0, 0.0 },
    { width > 0 ? (double)width : 960.0, height > 0 ? (double)height : 640.0 }
  };
  unsigned long style = LEPUSA_NS_WINDOW_STYLE_TITLED |
    LEPUSA_NS_WINDOW_STYLE_CLOSABLE |
    LEPUSA_NS_WINDOW_STYLE_MINIATURIZABLE;
  if (resizable) {
    style |= LEPUSA_NS_WINDOW_STYLE_RESIZABLE;
  }

  void *window_alloc = lepusa_msg_id(lepusa_cls("NSWindow"), "alloc");
  void *window = ((LepusaMsgSendIdRectStyle)lepusa_objc_msg_send)(
    window_alloc,
    lepusa_sel("initWithContentRect:styleMask:backing:defer:"),
    frame,
    style,
    LEPUSA_NS_BACKING_STORE_BUFFERED,
    0
  );
  if (window == NULL) {
    return 4;
  }

  void *configuration = lepusa_msg_id(
    lepusa_cls("WKWebViewConfiguration"),
    "new"
  );
  void *controller = lepusa_msg_id(
    lepusa_cls("WKUserContentController"),
    "new"
  );
  if (configuration == NULL || controller == NULL) {
    return 5;
  }

  void *script_source = lepusa_ns_string(initialization_script);
  void *user_script_alloc = lepusa_msg_id(lepusa_cls("WKUserScript"), "alloc");
  void *user_script = ((LepusaMsgSendIdScript)lepusa_objc_msg_send)(
    user_script_alloc,
    lepusa_sel("initWithSource:injectionTime:forMainFrameOnly:"),
    script_source,
    0,
    0
  );
  if (user_script == NULL) {
    return 5;
  }
  lepusa_msg_void_id(controller, "addUserScript:", user_script);

  LepusaBridgeContext bridge_context = {
    NULL,
    call_dispatch,
    dispatch,
    call_resolve_asset,
    resolve_asset
  };
  if (native_hook != NULL && call_dispatch != NULL && dispatch != NULL) {
    void *handler_class = lepusa_bridge_handler_class();
    void *handler = handler_class == NULL ? NULL : lepusa_msg_id(handler_class, "new");
    if (handler == NULL) {
      return 5;
    }
    lepusa_current_bridge_context = &bridge_context;
    lepusa_msg_void_id_id(
      controller,
      "addScriptMessageHandler:name:",
      handler,
      lepusa_ns_string(native_hook)
    );
  }
  if (asset_protocol != NULL &&
      call_resolve_asset != NULL &&
      resolve_asset != NULL) {
    void *handler_class = lepusa_url_scheme_handler_class();
    void *handler = handler_class == NULL ? NULL : lepusa_msg_id(handler_class, "new");
    if (handler == NULL) {
      return 5;
    }
    lepusa_current_bridge_context = &bridge_context;
    lepusa_msg_void_id_id(
      configuration,
      "setURLSchemeHandler:forURLScheme:",
      handler,
      lepusa_ns_string(asset_protocol)
    );
  }
  lepusa_msg_void_id(configuration, "setUserContentController:", controller);

  void *webview_alloc = lepusa_msg_id(lepusa_cls("WKWebView"), "alloc");
  void *webview = ((LepusaMsgSendIdRectId)lepusa_objc_msg_send)(
    webview_alloc,
    lepusa_sel("initWithFrame:configuration:"),
    frame,
    configuration
  );
  if (webview == NULL) {
    return 6;
  }
  bridge_context.webview = webview;

  void *ns_url = lepusa_ns_url(url);
  if (ns_url == NULL) {
    return 7;
  }
  void *request = ((LepusaMsgSendIdId)lepusa_objc_msg_send)(
    lepusa_cls("NSURLRequest"),
    lepusa_sel("requestWithURL:"),
    ns_url
  );
  if (request == NULL) {
    return 8;
  }

  lepusa_msg_void_id(window, "setTitle:", lepusa_ns_string(title));
  lepusa_msg_void_id(window, "setContentView:", webview);
  ((LepusaMsgSendVoid)lepusa_objc_msg_send)(window, lepusa_sel("center"));
  lepusa_msg_void_id(webview, "loadRequest:", request);
  lepusa_msg_void_id(window, "makeKeyAndOrderFront:", NULL);
  lepusa_msg_void_int(app, "activateIgnoringOtherApps:", 1);
  ((LepusaMsgSendVoid)lepusa_objc_msg_send)(app, lepusa_sel("run"));
  if (lepusa_current_bridge_context == &bridge_context) {
    lepusa_current_bridge_context = NULL;
  }
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_macos_run_webview(
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  int32_t width,
  int32_t height,
  int32_t resizable
) {
  return lepusa_macos_run_webview_impl(
    title,
    url,
    initialization_script,
    NULL,
    NULL,
    width,
    height,
    resizable,
    NULL,
    NULL,
    NULL,
    NULL
  );
}

MOONBIT_FFI_EXPORT
int32_t lepusa_macos_run_webview_with_bridge(
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  moonbit_bytes_t native_hook,
  moonbit_bytes_t asset_protocol,
  int32_t width,
  int32_t height,
  int32_t resizable,
  LepusaBytesCallback call_dispatch,
  void *dispatch,
  LepusaBytesCallback call_resolve_asset,
  void *resolve_asset
) {
  return lepusa_macos_run_webview_impl(
    title,
    url,
    initialization_script,
    native_hook,
    asset_protocol,
    width,
    height,
    resizable,
    call_dispatch,
    dispatch,
    call_resolve_asset,
    resolve_asset
  );
}

#else

int32_t lepusa_macos_backend_available(void) {
  return 1;
}

moonbit_bytes_t lepusa_macos_backend_engine_name(void) {
  static const char unavailable[] = "WKWebView unavailable";
  moonbit_bytes_t bytes = moonbit_make_bytes(sizeof(unavailable) - 1, 0);
  memcpy(bytes, unavailable, sizeof(unavailable) - 1);
  return bytes;
}

int32_t lepusa_macos_start_service(
  moonbit_bytes_t name,
  moonbit_bytes_t command_packet
) {
  (void)name;
  (void)command_packet;
  return 2;
}

int32_t lepusa_macos_stop_service(moonbit_bytes_t name) {
  (void)name;
  return 1;
}

int32_t lepusa_macos_wait_until_ready(
  moonbit_bytes_t readiness_url,
  int32_t timeout_ms
) {
  (void)readiness_url;
  (void)timeout_ms;
  return 2;
}

int32_t lepusa_macos_run_webview(
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  int32_t width,
  int32_t height,
  int32_t resizable
) {
  (void)title;
  (void)url;
  (void)initialization_script;
  (void)width;
  (void)height;
  (void)resizable;
  return 1;
}

int32_t lepusa_macos_run_webview_with_bridge(
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  moonbit_bytes_t native_hook,
  moonbit_bytes_t asset_protocol,
  int32_t width,
  int32_t height,
  int32_t resizable,
  void *call_dispatch,
  void *dispatch,
  void *call_resolve_asset,
  void *resolve_asset
) {
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
  return 1;
}

#endif
