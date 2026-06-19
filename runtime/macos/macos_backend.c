#include <moonbit.h>
#include <string.h>

#if defined(__APPLE__)

#include <dlfcn.h>

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
  moonbit_bytes_t script = context->call_dispatch(context->dispatch, request);
  if (script == NULL) {
    return;
  }
  lepusa_msg_void_id_id(
    context->webview,
    "evaluateJavaScript:completionHandler:",
    lepusa_ns_string(script),
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
