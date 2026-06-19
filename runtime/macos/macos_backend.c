#include <moonbit.h>
#include <dlfcn.h>
#include <string.h>

MOONBIT_FFI_EXPORT
int32_t lepusa_macos_backend_available(void) {
  void *handle = dlopen(
    "/System/Library/Frameworks/WebKit.framework/WebKit",
    RTLD_LAZY | RTLD_LOCAL
  );
  if (handle == NULL) {
    return 0;
  }
  dlclose(handle);
  return 1;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_macos_backend_engine_name(void) {
  const char *name = "WKWebView";
  int32_t len = (int32_t)strlen(name);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, name, len);
  return bytes;
}
