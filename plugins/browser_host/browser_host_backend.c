#include <moonbit.h>
#include <string.h>

#if defined(__APPLE__)
#include <dlfcn.h>

typedef struct { double x; double y; } BrowserHostPoint;
typedef struct { double width; double height; } BrowserHostSize;
typedef struct { BrowserHostPoint origin; BrowserHostSize size; } BrowserHostRect;
typedef void *(*MsgId)(void *, void *);
typedef void *(*MsgIdRect)(void *, void *, BrowserHostRect);
typedef void *(*MsgIdId)(void *, void *, void *);
typedef void *(*MsgIdULongId)(void *, void *, unsigned long, void *);
typedef void (*MsgVoidRectId)(void *, void *, BrowserHostRect, void *);
typedef BrowserHostRect (*MsgRect)(void *, void *);
typedef unsigned long (*MsgULong)(void *, void *);
typedef const void *(*MsgBytes)(void *, void *);
typedef void *(*GetClass)(const char *);
typedef void *(*GetSelector)(const char *);

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_browser_host_capture_visible_webview_png(void) {
  void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY | RTLD_LOCAL);
  if (objc == NULL) return moonbit_make_bytes(0, 0);
  GetClass get_class = (GetClass)dlsym(objc, "objc_getClass");
  GetSelector get_selector = (GetSelector)dlsym(objc, "sel_registerName");
  void *send = dlsym(objc, "objc_msgSend");
  if (get_class == NULL || get_selector == NULL || send == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  void *application = ((MsgId)send)(
    get_class("NSApplication"), get_selector("sharedApplication")
  );
  void *window = application == NULL ? NULL :
    ((MsgId)send)(application, get_selector("keyWindow"));
  if (window == NULL && application != NULL) {
    void *windows = ((MsgId)send)(application, get_selector("windows"));
    window = windows == NULL ? NULL :
      ((MsgId)send)(windows, get_selector("firstObject"));
  }
  void *view = window == NULL ? NULL :
    ((MsgId)send)(window, get_selector("contentView"));
  if (view == NULL) return moonbit_make_bytes(0, 0);
  BrowserHostRect bounds = ((MsgRect)send)(view, get_selector("bounds"));
  void *bitmap = ((MsgIdRect)send)(
    view, get_selector("bitmapImageRepForCachingDisplayInRect:"), bounds
  );
  if (bitmap == NULL) return moonbit_make_bytes(0, 0);
  ((MsgVoidRectId)send)(
    view, get_selector("cacheDisplayInRect:toBitmapImageRep:"), bounds, bitmap
  );
  void *data = ((MsgIdULongId)send)(
    bitmap,
    get_selector("representationUsingType:properties:"),
    4UL,
    ((MsgId)send)(get_class("NSDictionary"), get_selector("dictionary"))
  );
  if (data == NULL) return moonbit_make_bytes(0, 0);
  unsigned long length = ((MsgULong)send)(data, get_selector("length"));
  const void *bytes = ((MsgBytes)send)(data, get_selector("bytes"));
  if (bytes == NULL || length == 0 || length > 100UL * 1024UL * 1024UL) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)length, 0);
  memcpy(out, bytes, length);
  return out;
}

#else

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_browser_host_capture_visible_webview_png(void) {
  return moonbit_make_bytes(0, 0);
}

#endif
