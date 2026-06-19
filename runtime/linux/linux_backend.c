#include <moonbit.h>
#include <string.h>

#if defined(__linux__)
#include <dlfcn.h>
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_linux_backend_available(void) {
#if defined(__linux__)
  const char *libraries[] = {
    "libwebkit2gtk-4.1.so.0",
    "libwebkit2gtk-4.0.so.37",
    "libwebkitgtk-6.0.so.4"
  };
  for (int i = 0; i < 3; i++) {
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
