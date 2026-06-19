#include <moonbit.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_windows_backend_available(void) {
#if defined(_WIN32)
  HMODULE handle = LoadLibraryA("WebView2Loader.dll");
  if (handle == NULL) {
    return 0;
  }
  FreeLibrary(handle);
  return 1;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_windows_backend_engine_name(void) {
  const char *name = "WebView2";
  int32_t len = (int32_t)strlen(name);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, name, len);
  return bytes;
}
