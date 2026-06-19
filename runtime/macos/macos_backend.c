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
typedef void (*LepusaMsgSendVoid)(void *, void *);
typedef void (*LepusaMsgSendVoidId)(void *, void *, void *);
typedef void (*LepusaMsgSendVoidInt)(void *, void *, int);
typedef int (*LepusaMsgSendIntInt)(void *, void *, int);
typedef void *(*LepusaObjcGetClass)(const char *);
typedef void *(*LepusaSelRegisterName)(const char *);
typedef void *LepusaObjcMsgSend;

static LepusaObjcGetClass lepusa_objc_get_class = NULL;
static LepusaSelRegisterName lepusa_sel_register_name = NULL;
static LepusaObjcMsgSend lepusa_objc_msg_send = NULL;

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

static void lepusa_msg_void_int(void *target, const char *selector, int arg) {
  ((LepusaMsgSendVoidInt)lepusa_objc_msg_send)(target, lepusa_sel(selector), arg);
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
  return lepusa_objc_get_class != NULL &&
    lepusa_sel_register_name != NULL &&
    lepusa_objc_msg_send != NULL;
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
int32_t lepusa_macos_run_webview(
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  int32_t width,
  int32_t height,
  int32_t resizable
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
  return 0;
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

#endif
