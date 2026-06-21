#include <moonbit.h>
#include <string.h>

typedef moonbit_bytes_t (*LepusaWindowsBytesCallback)(void *, moonbit_bytes_t);

#if defined(_WIN32)
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <objbase.h>

typedef struct {
  char *name;
  HANDLE process;
} LepusaWindowsServiceProcess;

static LepusaWindowsServiceProcess lepusa_windows_service_processes[64];
static int lepusa_windows_service_cleanup_handlers_installed = 0;

typedef int (WSAAPI *LepusaWindowsWSAStartup)(WORD, LPWSADATA);
typedef int (WSAAPI *LepusaWindowsWSACleanup)(void);
typedef int (WSAAPI *LepusaWindowsGetAddrInfo)(
  PCSTR,
  PCSTR,
  const struct addrinfo *,
  struct addrinfo **
);
typedef void (WSAAPI *LepusaWindowsFreeAddrInfo)(struct addrinfo *);
typedef SOCKET (WSAAPI *LepusaWindowsSocket)(int, int, int);
typedef int (WSAAPI *LepusaWindowsCloseSocket)(SOCKET);
typedef int (WSAAPI *LepusaWindowsIoctlSocket)(SOCKET, long, u_long *);
typedef int (WSAAPI *LepusaWindowsConnect)(SOCKET, const struct sockaddr *, int);
typedef int (WSAAPI *LepusaWindowsWSAGetLastError)(void);
typedef int (WSAAPI *LepusaWindowsSelect)(
  int,
  fd_set *,
  fd_set *,
  fd_set *,
  const struct timeval *
);
typedef int (WSAAPI *LepusaWindowsGetSockOpt)(SOCKET, int, int, char *, int *);
typedef int (WSAAPI *LepusaWindowsSend)(SOCKET, const char *, int, int);
typedef int (WSAAPI *LepusaWindowsRecv)(SOCKET, char *, int, int);

static HMODULE lepusa_windows_winsock = NULL;
static LepusaWindowsWSAStartup lepusa_windows_wsa_startup = NULL;
static LepusaWindowsWSACleanup lepusa_windows_wsa_cleanup = NULL;
static LepusaWindowsGetAddrInfo lepusa_windows_getaddrinfo = NULL;
static LepusaWindowsFreeAddrInfo lepusa_windows_freeaddrinfo = NULL;
static LepusaWindowsSocket lepusa_windows_socket = NULL;
static LepusaWindowsCloseSocket lepusa_windows_closesocket = NULL;
static LepusaWindowsIoctlSocket lepusa_windows_ioctlsocket = NULL;
static LepusaWindowsConnect lepusa_windows_connect = NULL;
static LepusaWindowsWSAGetLastError lepusa_windows_wsa_get_last_error = NULL;
static LepusaWindowsSelect lepusa_windows_select = NULL;
static LepusaWindowsGetSockOpt lepusa_windows_getsockopt = NULL;
static LepusaWindowsSend lepusa_windows_send = NULL;
static LepusaWindowsRecv lepusa_windows_recv = NULL;

typedef struct ICoreWebView2 ICoreWebView2;
typedef struct ICoreWebView2Controller ICoreWebView2Controller;
typedef struct ICoreWebView2Environment ICoreWebView2Environment;
typedef struct ICoreWebView2EnvironmentOptions ICoreWebView2EnvironmentOptions;
typedef struct ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler
  ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler;
typedef struct ICoreWebView2ExecuteScriptCompletedHandler
  ICoreWebView2ExecuteScriptCompletedHandler;
typedef struct ICoreWebView2WebMessageReceivedEventHandler
  ICoreWebView2WebMessageReceivedEventHandler;
typedef struct ICoreWebView2WebMessageReceivedEventArgs
  ICoreWebView2WebMessageReceivedEventArgs;
typedef struct ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler;
typedef struct ICoreWebView2CreateCoreWebView2ControllerCompletedHandler
  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler;

typedef struct {
  int64_t value;
} LepusaWindowsEventRegistrationToken;

typedef struct ICoreWebView2Vtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2 *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(ICoreWebView2 *);
  ULONG (STDMETHODCALLTYPE *Release)(ICoreWebView2 *);
  void *get_Settings;
  void *get_Source;
  HRESULT (STDMETHODCALLTYPE *Navigate)(ICoreWebView2 *, LPCWSTR);
  HRESULT (STDMETHODCALLTYPE *NavigateToString)(ICoreWebView2 *, LPCWSTR);
  void *add_NavigationStarting;
  void *remove_NavigationStarting;
  void *add_ContentLoading;
  void *remove_ContentLoading;
  void *add_SourceChanged;
  void *remove_SourceChanged;
  void *add_HistoryChanged;
  void *remove_HistoryChanged;
  void *add_NavigationCompleted;
  void *remove_NavigationCompleted;
  void *add_FrameNavigationStarting;
  void *remove_FrameNavigationStarting;
  void *add_FrameNavigationCompleted;
  void *remove_FrameNavigationCompleted;
  void *add_ScriptDialogOpening;
  void *remove_ScriptDialogOpening;
  void *add_PermissionRequested;
  void *remove_PermissionRequested;
  void *add_ProcessFailed;
  void *remove_ProcessFailed;
  HRESULT (STDMETHODCALLTYPE *AddScriptToExecuteOnDocumentCreated)(
    ICoreWebView2 *,
    LPCWSTR,
    ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler *
  );
  void *RemoveScriptToExecuteOnDocumentCreated;
  HRESULT (STDMETHODCALLTYPE *ExecuteScript)(
    ICoreWebView2 *,
    LPCWSTR,
    ICoreWebView2ExecuteScriptCompletedHandler *
  );
  void *CapturePreview;
  void *Reload;
  void *PostWebMessageAsJson;
  void *PostWebMessageAsString;
  HRESULT (STDMETHODCALLTYPE *add_WebMessageReceived)(
    ICoreWebView2 *,
    ICoreWebView2WebMessageReceivedEventHandler *,
    LepusaWindowsEventRegistrationToken *
  );
  void *remove_WebMessageReceived;
} ICoreWebView2Vtbl;

struct ICoreWebView2 {
  const ICoreWebView2Vtbl *lpVtbl;
};

typedef struct ICoreWebView2ControllerVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2Controller *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(ICoreWebView2Controller *);
  ULONG (STDMETHODCALLTYPE *Release)(ICoreWebView2Controller *);
  void *get_IsVisible;
  void *put_IsVisible;
  void *get_Bounds;
  HRESULT (STDMETHODCALLTYPE *put_Bounds)(ICoreWebView2Controller *, RECT);
  void *get_ZoomFactor;
  void *put_ZoomFactor;
  void *add_ZoomFactorChanged;
  void *remove_ZoomFactorChanged;
  void *SetBoundsAndZoomFactor;
  void *MoveFocus;
  void *add_MoveFocusRequested;
  void *remove_MoveFocusRequested;
  void *add_GotFocus;
  void *remove_GotFocus;
  void *add_LostFocus;
  void *remove_LostFocus;
  void *add_AcceleratorKeyPressed;
  void *remove_AcceleratorKeyPressed;
  void *get_ParentWindow;
  void *put_ParentWindow;
  void *NotifyParentWindowPositionChanged;
  HRESULT (STDMETHODCALLTYPE *Close)(ICoreWebView2Controller *);
  HRESULT (STDMETHODCALLTYPE *get_CoreWebView2)(
    ICoreWebView2Controller *,
    ICoreWebView2 **
  );
} ICoreWebView2ControllerVtbl;

struct ICoreWebView2Controller {
  const ICoreWebView2ControllerVtbl *lpVtbl;
};

typedef struct ICoreWebView2EnvironmentVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2Environment *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(ICoreWebView2Environment *);
  ULONG (STDMETHODCALLTYPE *Release)(ICoreWebView2Environment *);
  HRESULT (STDMETHODCALLTYPE *CreateCoreWebView2Controller)(
    ICoreWebView2Environment *,
    HWND,
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *
  );
  void *CreateWebResourceResponse;
  void *get_BrowserVersionString;
  void *add_NewBrowserVersionAvailable;
  void *remove_NewBrowserVersionAvailable;
} ICoreWebView2EnvironmentVtbl;

struct ICoreWebView2Environment {
  const ICoreWebView2EnvironmentVtbl *lpVtbl;
};

typedef struct ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *
  );
  ULONG (STDMETHODCALLTYPE *Release)(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *
  );
  HRESULT (STDMETHODCALLTYPE *Invoke)(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *,
    HRESULT,
    ICoreWebView2Environment *
  );
} ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl;

struct ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler {
  const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl *lpVtbl;
};

typedef struct ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *
  );
  ULONG (STDMETHODCALLTYPE *Release)(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *
  );
  HRESULT (STDMETHODCALLTYPE *Invoke)(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *,
    HRESULT,
    ICoreWebView2Controller *
  );
} ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl;

struct ICoreWebView2CreateCoreWebView2ControllerCompletedHandler {
  const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl *lpVtbl;
};

typedef struct ICoreWebView2WebMessageReceivedEventArgsVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2WebMessageReceivedEventArgs *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(ICoreWebView2WebMessageReceivedEventArgs *);
  ULONG (STDMETHODCALLTYPE *Release)(ICoreWebView2WebMessageReceivedEventArgs *);
  HRESULT (STDMETHODCALLTYPE *get_Source)(
    ICoreWebView2WebMessageReceivedEventArgs *,
    LPWSTR *
  );
  HRESULT (STDMETHODCALLTYPE *get_WebMessageAsJson)(
    ICoreWebView2WebMessageReceivedEventArgs *,
    LPWSTR *
  );
  HRESULT (STDMETHODCALLTYPE *TryGetWebMessageAsString)(
    ICoreWebView2WebMessageReceivedEventArgs *,
    LPWSTR *
  );
} ICoreWebView2WebMessageReceivedEventArgsVtbl;

struct ICoreWebView2WebMessageReceivedEventArgs {
  const ICoreWebView2WebMessageReceivedEventArgsVtbl *lpVtbl;
};

typedef struct ICoreWebView2WebMessageReceivedEventHandlerVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2WebMessageReceivedEventHandler *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(
    ICoreWebView2WebMessageReceivedEventHandler *
  );
  ULONG (STDMETHODCALLTYPE *Release)(
    ICoreWebView2WebMessageReceivedEventHandler *
  );
  HRESULT (STDMETHODCALLTYPE *Invoke)(
    ICoreWebView2WebMessageReceivedEventHandler *,
    ICoreWebView2 *,
    ICoreWebView2WebMessageReceivedEventArgs *
  );
} ICoreWebView2WebMessageReceivedEventHandlerVtbl;

struct ICoreWebView2WebMessageReceivedEventHandler {
  const ICoreWebView2WebMessageReceivedEventHandlerVtbl *lpVtbl;
};

typedef HRESULT (WINAPI *LepusaCreateCoreWebView2EnvironmentWithOptions)(
  PCWSTR,
  PCWSTR,
  ICoreWebView2EnvironmentOptions *,
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *
);
typedef HRESULT (WINAPI *LepusaWindowsCoInitializeEx)(LPVOID, DWORD);
typedef void (WINAPI *LepusaWindowsCoUninitialize)(void);
typedef void (WINAPI *LepusaWindowsCoTaskMemFree)(LPVOID);

static const IID lepusa_iid_iunknown = {
  0x00000000,
  0x0000,
  0x0000,
  { 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 }
};
static const IID lepusa_iid_environment_completed = {
  0x4e8a3389,
  0xc9d8,
  0x4bd2,
  { 0xb6, 0xb5, 0x12, 0x4f, 0xee, 0x6c, 0xc1, 0x4d }
};
static const IID lepusa_iid_controller_completed = {
  0x6c4819f3,
  0xc9b7,
  0x4260,
  { 0x81, 0x27, 0xc9, 0xf5, 0xbd, 0xe7, 0xf6, 0x8c }
};
static const IID lepusa_iid_web_message_received = {
  0x57213f19,
  0x00e6,
  0x49fa,
  { 0x8e, 0x07, 0x89, 0x8e, 0xa0, 0x1e, 0xcb, 0xd2 }
};

static int lepusa_windows_load_winsock(void) {
  if (lepusa_windows_winsock != NULL) {
    return 1;
  }
  HMODULE library = LoadLibraryA("Ws2_32.dll");
  if (library == NULL) {
    return 0;
  }
  lepusa_windows_wsa_startup = (LepusaWindowsWSAStartup)GetProcAddress(
    library,
    "WSAStartup"
  );
  lepusa_windows_wsa_cleanup = (LepusaWindowsWSACleanup)GetProcAddress(
    library,
    "WSACleanup"
  );
  lepusa_windows_getaddrinfo = (LepusaWindowsGetAddrInfo)GetProcAddress(
    library,
    "getaddrinfo"
  );
  lepusa_windows_freeaddrinfo = (LepusaWindowsFreeAddrInfo)GetProcAddress(
    library,
    "freeaddrinfo"
  );
  lepusa_windows_socket = (LepusaWindowsSocket)GetProcAddress(library, "socket");
  lepusa_windows_closesocket = (LepusaWindowsCloseSocket)GetProcAddress(
    library,
    "closesocket"
  );
  lepusa_windows_ioctlsocket = (LepusaWindowsIoctlSocket)GetProcAddress(
    library,
    "ioctlsocket"
  );
  lepusa_windows_connect = (LepusaWindowsConnect)GetProcAddress(
    library,
    "connect"
  );
  lepusa_windows_wsa_get_last_error =
    (LepusaWindowsWSAGetLastError)GetProcAddress(library, "WSAGetLastError");
  lepusa_windows_select = (LepusaWindowsSelect)GetProcAddress(library, "select");
  lepusa_windows_getsockopt = (LepusaWindowsGetSockOpt)GetProcAddress(
    library,
    "getsockopt"
  );
  lepusa_windows_send = (LepusaWindowsSend)GetProcAddress(library, "send");
  lepusa_windows_recv = (LepusaWindowsRecv)GetProcAddress(library, "recv");
  if (lepusa_windows_wsa_startup == NULL ||
      lepusa_windows_wsa_cleanup == NULL ||
      lepusa_windows_getaddrinfo == NULL ||
      lepusa_windows_freeaddrinfo == NULL ||
      lepusa_windows_socket == NULL ||
      lepusa_windows_closesocket == NULL ||
      lepusa_windows_ioctlsocket == NULL ||
      lepusa_windows_connect == NULL ||
      lepusa_windows_wsa_get_last_error == NULL ||
      lepusa_windows_select == NULL ||
      lepusa_windows_getsockopt == NULL ||
      lepusa_windows_send == NULL ||
      lepusa_windows_recv == NULL) {
    FreeLibrary(library);
    return 0;
  }
  lepusa_windows_winsock = library;
  return 1;
}

static char *lepusa_windows_cstr_from_bytes(moonbit_bytes_t bytes) {
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

static wchar_t *lepusa_windows_wstr_from_bytes(moonbit_bytes_t bytes) {
  if (bytes == NULL) {
    return NULL;
  }
  int32_t len = Moonbit_array_length(bytes);
  int wide_len = MultiByteToWideChar(
    CP_UTF8,
    0,
    (const char *)bytes,
    len,
    NULL,
    0
  );
  if (wide_len <= 0) {
    return NULL;
  }
  wchar_t *out = (wchar_t *)calloc((size_t)wide_len + 1, sizeof(wchar_t));
  if (out == NULL) {
    return NULL;
  }
  if (MultiByteToWideChar(
        CP_UTF8,
        0,
        (const char *)bytes,
        len,
        out,
        wide_len
      ) != wide_len) {
    free(out);
    return NULL;
  }
  out[wide_len] = L'\0';
  return out;
}

static moonbit_bytes_t lepusa_windows_bytes_from_wstr(const wchar_t *text) {
  if (text == NULL) {
    return NULL;
  }
  int len = WideCharToMultiByte(CP_UTF8, 0, text, -1, NULL, 0, NULL, NULL);
  if (len <= 0) {
    return NULL;
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(len - 1, 0);
  char *buffer = (char *)malloc((size_t)len);
  if (buffer == NULL) {
    return NULL;
  }
  if (WideCharToMultiByte(CP_UTF8, 0, text, -1, buffer, len, NULL, NULL) <= 0) {
    free(buffer);
    return NULL;
  }
  if (len > 1) {
    memcpy(bytes, buffer, (size_t)(len - 1));
  }
  free(buffer);
  return bytes;
}

static const char *lepusa_windows_find_newline(
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

static moonbit_bytes_t lepusa_windows_immediate_script_from_handoff_packet(
  moonbit_bytes_t packet
) {
  if (packet == NULL) {
    return NULL;
  }
  const char *start = (const char *)packet;
  const char *end = start + Moonbit_array_length(packet);
  const char *first = lepusa_windows_find_newline(start, end);
  if (first == NULL ||
      (first - start) != 9 ||
      memcmp(start, "immediate", 9) != 0) {
    return NULL;
  }
  const char *second = lepusa_windows_find_newline(first + 1, end);
  if (second == NULL) {
    return NULL;
  }
  const char *third = lepusa_windows_find_newline(second + 1, end);
  if (third == NULL) {
    return NULL;
  }
  int64_t body_len64 = 0;
  for (const char *p = second + 1; p < third; p++) {
    if (*p < '0' || *p > '9') {
      return NULL;
    }
    body_len64 = body_len64 * 10 + (*p - '0');
    if (body_len64 > INT32_MAX) {
      return NULL;
    }
  }
  const char *body = third + 1;
  int32_t body_len = (int32_t)body_len64;
  if (body_len < 0 || body + body_len > end) {
    return NULL;
  }
  moonbit_bytes_t script = moonbit_make_bytes(body_len, 0);
  if (body_len > 0) {
    memcpy(script, body, (size_t)body_len);
  }
  return script;
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
} LepusaWindowsNativeOperationRecord;

static int lepusa_windows_range_equals(
  const char *value,
  int32_t value_len,
  const char *expected
) {
  return value != NULL &&
    expected != NULL &&
    value_len == (int32_t)strlen(expected) &&
    memcmp(value, expected, (size_t)value_len) == 0;
}

static int lepusa_windows_read_packet_field(
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
  const char *line_end = lepusa_windows_find_newline(*cursor, end);
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

static int lepusa_windows_read_native_operation_record(
  const char **cursor,
  const char *end,
  LepusaWindowsNativeOperationRecord *record
) {
  return record != NULL &&
    lepusa_windows_read_packet_field(cursor, end, &record->kind, &record->kind_len) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->window,
      &record->window_len
    ) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->action,
      &record->action_len
    ) &&
    lepusa_windows_read_packet_field(cursor, end, &record->url, &record->url_len) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->title,
      &record->title_len
    ) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->width,
      &record->width_len
    ) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->height,
      &record->height_len
    ) &&
    lepusa_windows_read_packet_field(cursor, end, &record->x, &record->x_len) &&
    lepusa_windows_read_packet_field(cursor, end, &record->y, &record->y_len) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->fullscreen,
      &record->fullscreen_len
    ) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->resizable,
      &record->resizable_len
    ) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->bridge_source,
      &record->bridge_source_len
    ) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->native_hook,
      &record->native_hook_len
    ) &&
    lepusa_windows_read_packet_field(
      cursor,
      end,
      &record->asset_protocol,
      &record->asset_protocol_len
    );
}

static int lepusa_windows_parse_record_int(
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

static int lepusa_windows_parse_record_bool(
  const char *value,
  int32_t value_len,
  int *value_out
) {
  if (value_out == NULL) {
    return 0;
  }
  if (lepusa_windows_range_equals(value, value_len, "true")) {
    *value_out = 1;
    return 1;
  }
  if (lepusa_windows_range_equals(value, value_len, "false")) {
    *value_out = 0;
    return 1;
  }
  return 0;
}

static int lepusa_windows_handoff_operations_range(
  moonbit_bytes_t packet,
  const char **operations_out,
  int32_t *operations_len_out
) {
  if (packet == NULL || operations_out == NULL || operations_len_out == NULL) {
    return 0;
  }
  const char *start = (const char *)packet;
  const char *end = start + Moonbit_array_length(packet);
  const char *first = lepusa_windows_find_newline(start, end);
  if (first == NULL ||
      ((first - start) != 9 || memcmp(start, "immediate", 9) != 0) &&
      ((first - start) != 8 || memcmp(start, "deferred", 8) != 0)) {
    return 0;
  }
  const char *second = lepusa_windows_find_newline(first + 1, end);
  if (second == NULL) {
    return 0;
  }
  const char *third = lepusa_windows_find_newline(second + 1, end);
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

static int lepusa_windows_handoff_operation_records(
  moonbit_bytes_t packet,
  const char **cursor_out,
  const char **end_out,
  int32_t *count_out
) {
  const char *operations = NULL;
  int32_t operations_len = 0;
  if (!lepusa_windows_handoff_operations_range(
        packet,
        &operations,
        &operations_len
      )) {
    return 0;
  }
  const char *cursor = operations;
  const char *end = operations + operations_len;
  const char *version = lepusa_windows_find_newline(cursor, end);
  if (version == NULL ||
      !lepusa_windows_range_equals(
        cursor,
        (int32_t)(version - cursor),
        "lepusa-ops-v3"
      )) {
    return 0;
  }
  cursor = version + 1;
  const char *count_end = lepusa_windows_find_newline(cursor, end);
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

static void lepusa_windows_free_argv(char **argv, int argc) {
  if (argv == NULL) {
    return;
  }
  for (int i = 0; i < argc; i++) {
    free(argv[i]);
  }
  free(argv);
}

static int lepusa_windows_parse_command_packet(
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
      lepusa_windows_free_argv(argv, argc);
      return 0;
    }
    while (cursor < end && isdigit((unsigned char)*cursor)) {
      len = len * 10 + (*cursor - '0');
      cursor++;
    }
    if (cursor >= end || *cursor != '\n') {
      lepusa_windows_free_argv(argv, argc);
      return 0;
    }
    cursor++;
    if (len < 0 || cursor + len > end) {
      lepusa_windows_free_argv(argv, argc);
      return 0;
    }
    if (argc >= capacity) {
      capacity *= 2;
      char **grown = (char **)realloc(
        argv,
        ((size_t)capacity + 1) * sizeof(char *)
      );
      if (grown == NULL) {
        lepusa_windows_free_argv(argv, argc);
        return 0;
      }
      argv = grown;
    }
    argv[argc] = (char *)malloc((size_t)len + 1);
    if (argv[argc] == NULL) {
      lepusa_windows_free_argv(argv, argc);
      return 0;
    }
    memcpy(argv[argc], cursor, (size_t)len);
    argv[argc][len] = '\0';
    argc++;
    cursor += len;
  }
  if (argc == 0 || argv[0][0] == '\0') {
    lepusa_windows_free_argv(argv, argc);
    return 0;
  }
  argv[argc] = NULL;
  *argv_out = argv;
  *argc_out = argc;
  return 1;
}

static int lepusa_windows_needs_quote(const char *text) {
  if (text == NULL || text[0] == '\0') {
    return 1;
  }
  for (const char *p = text; *p != '\0'; p++) {
    if (*p == ' ' || *p == '\t' || *p == '"' || *p == '\\') {
      return 1;
    }
  }
  return 0;
}

static size_t lepusa_windows_quoted_len(const char *text) {
  if (!lepusa_windows_needs_quote(text)) {
    return strlen(text);
  }
  size_t len = 2;
  for (const char *p = text; p != NULL && *p != '\0'; p++) {
    len += (*p == '"' || *p == '\\') ? 2 : 1;
  }
  return len;
}

static void lepusa_windows_append_quoted(char *out, size_t *offset, const char *text) {
  if (!lepusa_windows_needs_quote(text)) {
    size_t len = strlen(text);
    memcpy(out + *offset, text, len);
    *offset += len;
    return;
  }
  out[(*offset)++] = '"';
  for (const char *p = text; p != NULL && *p != '\0'; p++) {
    if (*p == '"' || *p == '\\') {
      out[(*offset)++] = '\\';
    }
    out[(*offset)++] = *p;
  }
  out[(*offset)++] = '"';
}

static char *lepusa_windows_command_line(char **argv, int argc) {
  size_t len = 1;
  for (int i = 0; i < argc; i++) {
    len += lepusa_windows_quoted_len(argv[i]);
    if (i + 1 < argc) {
      len++;
    }
  }
  char *line = (char *)malloc(len);
  if (line == NULL) {
    return NULL;
  }
  size_t offset = 0;
  for (int i = 0; i < argc; i++) {
    lepusa_windows_append_quoted(line, &offset, argv[i]);
    if (i + 1 < argc) {
      line[offset++] = ' ';
    }
  }
  line[offset] = '\0';
  return line;
}

static int lepusa_windows_track_service(const char *name, HANDLE process) {
  if (name == NULL || name[0] == '\0' || process == NULL) {
    return 0;
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_windows_service_processes[i].name != NULL &&
        strcmp(lepusa_windows_service_processes[i].name, name) == 0) {
      DWORD code = 0;
      if (GetExitCodeProcess(lepusa_windows_service_processes[i].process, &code) &&
          code == STILL_ACTIVE) {
        TerminateProcess(lepusa_windows_service_processes[i].process, 0);
        WaitForSingleObject(lepusa_windows_service_processes[i].process, 1000);
      }
      CloseHandle(lepusa_windows_service_processes[i].process);
      lepusa_windows_service_processes[i].process = process;
      return 1;
    }
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_windows_service_processes[i].name == NULL) {
      lepusa_windows_service_processes[i].name = _strdup(name);
      lepusa_windows_service_processes[i].process = process;
      return lepusa_windows_service_processes[i].name != NULL;
    }
  }
  return 0;
}

static HANDLE lepusa_windows_untrack_service(const char *name) {
  if (name == NULL) {
    return NULL;
  }
  for (int i = 0; i < 64; i++) {
    if (lepusa_windows_service_processes[i].name != NULL &&
        strcmp(lepusa_windows_service_processes[i].name, name) == 0) {
      HANDLE process = lepusa_windows_service_processes[i].process;
      free(lepusa_windows_service_processes[i].name);
      lepusa_windows_service_processes[i].name = NULL;
      lepusa_windows_service_processes[i].process = NULL;
      return process;
    }
  }
  return NULL;
}

static void lepusa_windows_terminate_tracked_services(int clear_entries) {
  for (int i = 0; i < 64; i++) {
    HANDLE process = lepusa_windows_service_processes[i].process;
    if (process != NULL) {
      DWORD code = 0;
      if (GetExitCodeProcess(process, &code) && code == STILL_ACTIVE) {
        TerminateProcess(process, 0);
        WaitForSingleObject(process, 1000);
      }
      if (clear_entries) {
        CloseHandle(process);
      }
    }
    if (clear_entries) {
      free(lepusa_windows_service_processes[i].name);
      lepusa_windows_service_processes[i].name = NULL;
      lepusa_windows_service_processes[i].process = NULL;
    }
  }
}

static void lepusa_windows_cleanup_services_at_exit(void) {
  lepusa_windows_terminate_tracked_services(1);
}

static BOOL WINAPI lepusa_windows_cleanup_services_on_console(
  DWORD control_type
) {
  switch (control_type) {
    case CTRL_C_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_CLOSE_EVENT:
    case CTRL_LOGOFF_EVENT:
    case CTRL_SHUTDOWN_EVENT:
      lepusa_windows_terminate_tracked_services(0);
      return FALSE;
    default:
      return FALSE;
  }
}

static void lepusa_windows_install_service_cleanup_handlers(void) {
  if (lepusa_windows_service_cleanup_handlers_installed) {
    return;
  }
  lepusa_windows_service_cleanup_handlers_installed = 1;
  atexit(lepusa_windows_cleanup_services_at_exit);
  SetConsoleCtrlHandler(lepusa_windows_cleanup_services_on_console, TRUE);
}

static int lepusa_windows_parse_http_url(
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

static int lepusa_windows_try_http_ready(
  const char *host,
  const char *port,
  const char *path
) {
  struct addrinfo hints;
  struct addrinfo *result = NULL;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  if (lepusa_windows_getaddrinfo(host, port, &hints, &result) != 0) {
    return 0;
  }
  int ready = 0;
  for (struct addrinfo *rp = result; rp != NULL && !ready; rp = rp->ai_next) {
    SOCKET sock = lepusa_windows_socket(
      rp->ai_family,
      rp->ai_socktype,
      rp->ai_protocol
    );
    if (sock == INVALID_SOCKET) {
      continue;
    }
    u_long mode = 1;
    lepusa_windows_ioctlsocket(sock, FIONBIO, &mode);
    int connected = lepusa_windows_connect(
      sock,
      rp->ai_addr,
      (int)rp->ai_addrlen
    ) == 0;
    if (!connected &&
        lepusa_windows_wsa_get_last_error() == WSAEWOULDBLOCK) {
      fd_set write_set;
      FD_ZERO(&write_set);
      FD_SET(sock, &write_set);
      struct timeval timeout;
      timeout.tv_sec = 0;
      timeout.tv_usec = 500000;
      if (lepusa_windows_select(0, NULL, &write_set, NULL, &timeout) > 0) {
        int error = 0;
        int error_len = sizeof(error);
        connected = lepusa_windows_getsockopt(
          sock,
          SOL_SOCKET,
          SO_ERROR,
          (char *)&error,
          &error_len
        ) == 0 && error == 0;
      }
    }
    mode = 0;
    lepusa_windows_ioctlsocket(sock, FIONBIO, &mode);
    if (connected) {
      char request[1024];
      snprintf(
        request,
        sizeof(request),
        "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n",
        path,
        host
      );
      (void)lepusa_windows_send(sock, request, (int)strlen(request), 0);
      char response[64];
      int n = lepusa_windows_recv(sock, response, sizeof(response) - 1, 0);
      if (n > 0) {
        response[n] = '\0';
        ready = strncmp(response, "HTTP/", 5) == 0 &&
          response[9] >= '2' &&
        response[9] <= '3';
      }
    }
    lepusa_windows_closesocket(sock);
  }
  lepusa_windows_freeaddrinfo(result);
  return ready;
}
#endif

#if defined(_WIN32)
typedef struct LepusaWindowsWebView2Context LepusaWindowsWebView2Context;
typedef struct LepusaWindowsWindowSlot LepusaWindowsWindowSlot;

typedef struct {
  const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl *lpVtbl;
  LONG ref_count;
  LepusaWindowsWebView2Context *context;
} LepusaWindowsEnvironmentCompletedHandler;

typedef struct {
  const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl *lpVtbl;
  LONG ref_count;
  LepusaWindowsWebView2Context *context;
  LepusaWindowsWindowSlot *slot;
} LepusaWindowsControllerCompletedHandler;

typedef struct {
  const ICoreWebView2WebMessageReceivedEventHandlerVtbl *lpVtbl;
  LONG ref_count;
  LepusaWindowsWebView2Context *context;
  LepusaWindowsWindowSlot *slot;
} LepusaWindowsWebMessageReceivedHandler;

struct LepusaWindowsWindowSlot {
  char label[128];
  HWND hwnd;
  ICoreWebView2Controller *controller;
  ICoreWebView2 *webview;
  wchar_t *title;
  wchar_t *url;
  wchar_t *initialization_script;
  int width;
  int height;
  int resizable;
  LepusaWindowsEventRegistrationToken web_message_token;
  LepusaWindowsControllerCompletedHandler controller_handler;
  LepusaWindowsWebMessageReceivedHandler web_message_handler;
  LepusaWindowsWebView2Context *context;
};

struct LepusaWindowsWebView2Context {
  HINSTANCE instance;
  ICoreWebView2Environment *environment;
  moonbit_bytes_t label;
  moonbit_bytes_t title;
  moonbit_bytes_t url;
  moonbit_bytes_t initialization_script;
  int width;
  int height;
  int resizable;
  LepusaWindowsBytesCallback call_dispatch;
  void *dispatch;
  LepusaWindowsCoTaskMemFree co_task_mem_free;
  HRESULT result;
  int live_windows;
  LepusaWindowsWindowSlot windows[32];
  int window_count;
  LepusaWindowsEnvironmentCompletedHandler environment_handler;
  moonbit_bytes_t initial_open_packet;
};

static int lepusa_windows_iid_equals(REFIID left, const IID *right) {
  return left != NULL && right != NULL && IsEqualGUID(left, right);
}

static HRESULT STDMETHODCALLTYPE lepusa_windows_environment_query_interface(
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self,
  REFIID riid,
  void **object
) {
  if (object == NULL) {
    return E_POINTER;
  }
  if (lepusa_windows_iid_equals(riid, &lepusa_iid_iunknown) ||
      lepusa_windows_iid_equals(riid, &lepusa_iid_environment_completed)) {
    *object = self;
    self->lpVtbl->AddRef(self);
    return S_OK;
  }
  *object = NULL;
  return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE lepusa_windows_environment_add_ref(
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self
) {
  LepusaWindowsEnvironmentCompletedHandler *handler =
    (LepusaWindowsEnvironmentCompletedHandler *)self;
  return (ULONG)InterlockedIncrement(&handler->ref_count);
}

static ULONG STDMETHODCALLTYPE lepusa_windows_environment_release(
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self
) {
  LepusaWindowsEnvironmentCompletedHandler *handler =
    (LepusaWindowsEnvironmentCompletedHandler *)self;
  return (ULONG)InterlockedDecrement(&handler->ref_count);
}

static void lepusa_windows_copy_label_range(
  char *out,
  size_t out_len,
  const char *label,
  int32_t label_len
) {
  if (out == NULL || out_len == 0) {
    return;
  }
  size_t copy_len = label == NULL || label_len <= 0 ? 0 : (size_t)label_len;
  if (copy_len >= out_len) {
    copy_len = out_len - 1;
  }
  if (copy_len > 0) {
    memcpy(out, label, copy_len);
  }
  out[copy_len] = '\0';
}

static LepusaWindowsWindowSlot *lepusa_windows_find_window_slot_exact(
  LepusaWindowsWebView2Context *context,
  const char *label,
  int32_t label_len
) {
  if (context == NULL || label == NULL || label_len <= 0) {
    return NULL;
  }
  for (int i = 0; i < context->window_count; i++) {
    if (strlen(context->windows[i].label) == (size_t)label_len &&
        memcmp(context->windows[i].label, label, (size_t)label_len) == 0) {
      return &context->windows[i];
    }
  }
  return NULL;
}

static LepusaWindowsWindowSlot *lepusa_windows_find_window_slot(
  LepusaWindowsWebView2Context *context,
  const char *label,
  int32_t label_len
) {
  if (context == NULL) {
    return NULL;
  }
  if (label != NULL && label_len > 0) {
    LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot_exact(
      context,
      label,
      label_len
    );
    if (slot != NULL) {
      return slot;
    }
  }
  return context->window_count > 0 ? &context->windows[0] : NULL;
}

static LepusaWindowsWindowSlot *lepusa_windows_window_slot_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
) {
  if (context == NULL || packet == NULL) {
    return NULL;
  }
  const char *start = (const char *)packet;
  const char *end = start + Moonbit_array_length(packet);
  const char *first = lepusa_windows_find_newline(start, end);
  if (first == NULL) {
    return lepusa_windows_find_window_slot(context, NULL, 0);
  }
  const char *second = lepusa_windows_find_newline(first + 1, end);
  if (second == NULL) {
    return lepusa_windows_find_window_slot(context, NULL, 0);
  }
  return lepusa_windows_find_window_slot(
    context,
    first + 1,
    (int32_t)(second - first - 1)
  );
}

static void lepusa_windows_resize_slot(LepusaWindowsWindowSlot *slot) {
  if (slot == NULL || slot->hwnd == NULL || slot->controller == NULL) {
    return;
  }
  RECT bounds;
  GetClientRect(slot->hwnd, &bounds);
  slot->controller->lpVtbl->put_Bounds(slot->controller, bounds);
}

static HRESULT STDMETHODCALLTYPE lepusa_windows_controller_query_interface(
  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self,
  REFIID riid,
  void **object
) {
  if (object == NULL) {
    return E_POINTER;
  }
  if (lepusa_windows_iid_equals(riid, &lepusa_iid_iunknown) ||
      lepusa_windows_iid_equals(riid, &lepusa_iid_controller_completed)) {
    *object = self;
    self->lpVtbl->AddRef(self);
    return S_OK;
  }
  *object = NULL;
  return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE lepusa_windows_controller_add_ref(
  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self
) {
  LepusaWindowsControllerCompletedHandler *handler =
    (LepusaWindowsControllerCompletedHandler *)self;
  return (ULONG)InterlockedIncrement(&handler->ref_count);
}

static ULONG STDMETHODCALLTYPE lepusa_windows_controller_release(
  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self
) {
  LepusaWindowsControllerCompletedHandler *handler =
    (LepusaWindowsControllerCompletedHandler *)self;
  return (ULONG)InterlockedDecrement(&handler->ref_count);
}

static HRESULT STDMETHODCALLTYPE lepusa_windows_web_message_query_interface(
  ICoreWebView2WebMessageReceivedEventHandler *self,
  REFIID riid,
  void **object
) {
  if (object == NULL) {
    return E_POINTER;
  }
  if (lepusa_windows_iid_equals(riid, &lepusa_iid_iunknown) ||
      lepusa_windows_iid_equals(riid, &lepusa_iid_web_message_received)) {
    *object = self;
    self->lpVtbl->AddRef(self);
    return S_OK;
  }
  *object = NULL;
  return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE lepusa_windows_web_message_add_ref(
  ICoreWebView2WebMessageReceivedEventHandler *self
) {
  LepusaWindowsWebMessageReceivedHandler *handler =
    (LepusaWindowsWebMessageReceivedHandler *)self;
  return (ULONG)InterlockedIncrement(&handler->ref_count);
}

static ULONG STDMETHODCALLTYPE lepusa_windows_web_message_release(
  ICoreWebView2WebMessageReceivedEventHandler *self
) {
  LepusaWindowsWebMessageReceivedHandler *handler =
    (LepusaWindowsWebMessageReceivedHandler *)self;
  return (ULONG)InterlockedDecrement(&handler->ref_count);
}

static void lepusa_windows_apply_open_windows_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
);

static void lepusa_windows_apply_close_windows_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
);

static void lepusa_windows_execute_script_bytes(
  LepusaWindowsWindowSlot *slot,
  moonbit_bytes_t script
) {
  if (slot == NULL ||
      slot->webview == NULL ||
      script == NULL ||
      Moonbit_array_length(script) == 0) {
    return;
  }
  wchar_t *script_text = lepusa_windows_wstr_from_bytes(script);
  if (script_text == NULL) {
    return;
  }
  slot->webview->lpVtbl->ExecuteScript(slot->webview, script_text, NULL);
  free(script_text);
}

static HRESULT STDMETHODCALLTYPE lepusa_windows_web_message_invoke(
  ICoreWebView2WebMessageReceivedEventHandler *self,
  ICoreWebView2 *sender,
  ICoreWebView2WebMessageReceivedEventArgs *args
) {
  (void)sender;
  LepusaWindowsWebMessageReceivedHandler *handler =
    (LepusaWindowsWebMessageReceivedHandler *)self;
  LepusaWindowsWebView2Context *context = handler->context;
  LepusaWindowsWindowSlot *source_slot = handler->slot;
  if (context == NULL ||
      source_slot == NULL ||
      args == NULL ||
      context->call_dispatch == NULL ||
      context->dispatch == NULL) {
    return S_OK;
  }
  LPWSTR message_text = NULL;
  HRESULT message_result = args->lpVtbl->TryGetWebMessageAsString(
    args,
    &message_text
  );
  if (FAILED(message_result) || message_text == NULL) {
    return S_OK;
  }
  moonbit_bytes_t message = lepusa_windows_bytes_from_wstr(message_text);
  if (context->co_task_mem_free != NULL) {
    context->co_task_mem_free(message_text);
  }
  if (message == NULL) {
    return S_OK;
  }
  moonbit_bytes_t packet = context->call_dispatch(context->dispatch, message);
  moonbit_bytes_t script =
    lepusa_windows_immediate_script_from_handoff_packet(packet);
  LepusaWindowsWindowSlot *target_slot =
    lepusa_windows_window_slot_from_handoff_packet(context, packet);
  lepusa_windows_execute_script_bytes(
    target_slot == NULL ? source_slot : target_slot,
    script
  );
  lepusa_windows_apply_open_windows_from_handoff_packet(context, packet);
  lepusa_windows_apply_close_windows_from_handoff_packet(context, packet);
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE lepusa_windows_controller_invoke(
  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self,
  HRESULT error_code,
  ICoreWebView2Controller *controller
) {
  LepusaWindowsControllerCompletedHandler *handler =
    (LepusaWindowsControllerCompletedHandler *)self;
  LepusaWindowsWebView2Context *context = handler->context;
  LepusaWindowsWindowSlot *slot = handler->slot;
  if (context == NULL || slot == NULL) {
    return S_OK;
  }
  context->result = error_code;
  if (FAILED(error_code) || controller == NULL) {
    PostMessageW(slot->hwnd, WM_CLOSE, 0, 0);
    return S_OK;
  }
  slot->controller = controller;
  slot->controller->lpVtbl->AddRef(slot->controller);
  lepusa_windows_resize_slot(slot);
  HRESULT webview_result = slot->controller->lpVtbl->get_CoreWebView2(
    slot->controller,
    &slot->webview
  );
  if (FAILED(webview_result) || slot->webview == NULL) {
    context->result = webview_result;
    PostMessageW(slot->hwnd, WM_CLOSE, 0, 0);
    return S_OK;
  }
  if (slot->initialization_script != NULL &&
      slot->initialization_script[0] != L'\0') {
    slot->webview->lpVtbl->AddScriptToExecuteOnDocumentCreated(
      slot->webview,
      slot->initialization_script,
      NULL
    );
  }
  if (context->call_dispatch != NULL && context->dispatch != NULL) {
    slot->webview->lpVtbl->add_WebMessageReceived(
      slot->webview,
      (ICoreWebView2WebMessageReceivedEventHandler *)
        &slot->web_message_handler,
      &slot->web_message_token
    );
  }
  if (slot->url != NULL && slot->url[0] != L'\0') {
    HRESULT navigate_result = slot->webview->lpVtbl->Navigate(
      slot->webview,
      slot->url
    );
    if (FAILED(navigate_result)) {
      context->result = navigate_result;
      PostMessageW(slot->hwnd, WM_CLOSE, 0, 0);
    }
  }
  return S_OK;
}

static const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl
  lepusa_windows_controller_handler_vtbl = {
    lepusa_windows_controller_query_interface,
    lepusa_windows_controller_add_ref,
    lepusa_windows_controller_release,
    lepusa_windows_controller_invoke
  };

static const ICoreWebView2WebMessageReceivedEventHandlerVtbl
  lepusa_windows_web_message_handler_vtbl = {
    lepusa_windows_web_message_query_interface,
    lepusa_windows_web_message_add_ref,
    lepusa_windows_web_message_release,
    lepusa_windows_web_message_invoke
  };

static LepusaWindowsWindowSlot *lepusa_windows_create_window_slot(
  LepusaWindowsWebView2Context *context,
  const char *label,
  int32_t label_len,
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  int width,
  int height,
  int resizable
) {
  if (context == NULL ||
      context->environment == NULL ||
      context->window_count >= 32) {
    return NULL;
  }
  if (label != NULL &&
      label_len > 0 &&
      lepusa_windows_find_window_slot_exact(context, label, label_len) != NULL) {
    return NULL;
  }
  LepusaWindowsWindowSlot *slot = &context->windows[context->window_count];
  memset(slot, 0, sizeof(*slot));
  lepusa_windows_copy_label_range(
    slot->label,
    sizeof(slot->label),
    label,
    label_len
  );
  slot->title = lepusa_windows_wstr_from_bytes(title);
  slot->url = lepusa_windows_wstr_from_bytes(url);
  slot->initialization_script = lepusa_windows_wstr_from_bytes(
    initialization_script
  );
  slot->width = width > 0 ? width : 960;
  slot->height = height > 0 ? height : 640;
  slot->resizable = resizable != 0;
  slot->context = context;
  slot->controller_handler.lpVtbl = &lepusa_windows_controller_handler_vtbl;
  slot->controller_handler.ref_count = 1;
  slot->controller_handler.context = context;
  slot->controller_handler.slot = slot;
  slot->web_message_handler.lpVtbl = &lepusa_windows_web_message_handler_vtbl;
  slot->web_message_handler.ref_count = 1;
  slot->web_message_handler.context = context;
  slot->web_message_handler.slot = slot;
  if (slot->title == NULL ||
      slot->url == NULL ||
      slot->initialization_script == NULL) {
    free(slot->title);
    free(slot->url);
    free(slot->initialization_script);
    memset(slot, 0, sizeof(*slot));
    return NULL;
  }
  DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
  if (slot->resizable) {
    style |= WS_THICKFRAME | WS_MAXIMIZEBOX;
  }
  RECT window_rect = { 0, 0, slot->width, slot->height };
  AdjustWindowRect(&window_rect, style, FALSE);
  slot->hwnd = CreateWindowExW(
    0,
    L"LepusaWebView2Window",
    slot->title,
    style,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    window_rect.right - window_rect.left,
    window_rect.bottom - window_rect.top,
    NULL,
    NULL,
    context->instance,
    NULL
  );
  if (slot->hwnd == NULL) {
    free(slot->title);
    free(slot->url);
    free(slot->initialization_script);
    memset(slot, 0, sizeof(*slot));
    return NULL;
  }
  context->window_count++;
  context->live_windows++;
  SetWindowLongPtrW(slot->hwnd, GWLP_USERDATA, (LONG_PTR)slot);
  ShowWindow(slot->hwnd, SW_SHOW);
  UpdateWindow(slot->hwnd);
  HRESULT controller_result =
    context->environment->lpVtbl->CreateCoreWebView2Controller(
      context->environment,
      slot->hwnd,
      (ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *)
        &slot->controller_handler
    );
  if (FAILED(controller_result)) {
    context->result = controller_result;
    DestroyWindow(slot->hwnd);
    return NULL;
  }
  return slot;
}

static moonbit_bytes_t lepusa_windows_bytes_from_range(
  const char *value,
  int32_t value_len
) {
  int32_t safe_len = value == NULL || value_len < 0 ? 0 : value_len;
  moonbit_bytes_t bytes = moonbit_make_bytes(safe_len, 0);
  if (safe_len > 0) {
    memcpy(bytes, value, (size_t)safe_len);
  }
  return bytes;
}

static char *lepusa_windows_js_string_literal_from_range(
  const char *value,
  int32_t value_len
) {
  size_t len = 2;
  for (int32_t i = 0; value != NULL && i < value_len; i++) {
    char ch = value[i];
    len += (ch == '"' || ch == '\\' || ch == '\n' || ch == '\r') ? 2 : 1;
  }
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  out[offset++] = '"';
  for (int32_t i = 0; value != NULL && i < value_len; i++) {
    char ch = value[i];
    if (ch == '"' || ch == '\\') {
      out[offset++] = '\\';
      out[offset++] = ch;
    } else if (ch == '\n') {
      out[offset++] = '\\';
      out[offset++] = 'n';
    } else if (ch == '\r') {
      out[offset++] = '\\';
      out[offset++] = 'r';
    } else {
      out[offset++] = ch;
    }
  }
  out[offset++] = '"';
  out[offset] = '\0';
  return out;
}

static moonbit_bytes_t lepusa_windows_initialization_from_record(
  const LepusaWindowsNativeOperationRecord *record
) {
  if (record == NULL) {
    return lepusa_windows_bytes_from_range("", 0);
  }
  char *native_hook = lepusa_windows_js_string_literal_from_range(
    record->native_hook,
    record->native_hook_len
  );
  if (native_hook == NULL) {
    return lepusa_windows_bytes_from_range(record->bridge_source, record->bridge_source_len);
  }
  const char *template_text =
    "(() => {\n"
    "  const nativeHook = %s;\n"
    "  const responseHook = nativeHook + \"Response\";\n"
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
    "      const chrome = globalThis.chrome;\n"
    "      const webview = chrome && chrome.webview;\n"
    "      if (!webview || typeof webview.postMessage !== \"function\") {\n"
    "        reject(new Error(`Missing Lepusa Windows WebView2 bridge: ${nativeHook}`));\n"
    "        return;\n"
    "      }\n"
    "      pending.set(String(request.id || \"\"), { resolve, reject });\n"
    "      webview.postMessage(JSON.stringify(request));\n"
    "    }),\n"
    "    configurable: true,\n"
    "  });\n"
    "})();\n";
  int needed = snprintf(NULL, 0, template_text, native_hook);
  if (needed < 0) {
    free(native_hook);
    return lepusa_windows_bytes_from_range(record->bridge_source, record->bridge_source_len);
  }
  char *script = (char *)malloc((size_t)needed + 1);
  if (script == NULL) {
    free(native_hook);
    return lepusa_windows_bytes_from_range(record->bridge_source, record->bridge_source_len);
  }
  snprintf(script, (size_t)needed + 1, template_text, native_hook);
  int32_t bridge_len = record->bridge_source_len > 0 ? record->bridge_source_len : 0;
  moonbit_bytes_t bytes = moonbit_make_bytes(needed + bridge_len, 0);
  memcpy(bytes, script, (size_t)needed);
  if (bridge_len > 0) {
    memcpy(bytes + needed, record->bridge_source, (size_t)bridge_len);
  }
  free(script);
  free(native_hook);
  return bytes;
}

static void lepusa_windows_open_window_from_record(
  LepusaWindowsWebView2Context *context,
  const LepusaWindowsNativeOperationRecord *record
) {
  if (context == NULL ||
      record == NULL ||
      record->window_len <= 0 ||
      record->url_len <= 0) {
    return;
  }
  if (lepusa_windows_find_window_slot_exact(
        context,
        record->window,
        record->window_len
      ) != NULL) {
    return;
  }
  int width = 960;
  int height = 640;
  int resizable = 1;
  (void)lepusa_windows_parse_record_int(record->width, record->width_len, &width);
  (void)lepusa_windows_parse_record_int(
    record->height,
    record->height_len,
    &height
  );
  (void)lepusa_windows_parse_record_bool(
    record->resizable,
    record->resizable_len,
    &resizable
  );
  moonbit_bytes_t title = lepusa_windows_bytes_from_range(
    record->title,
    record->title_len
  );
  moonbit_bytes_t url = lepusa_windows_bytes_from_range(
    record->url,
    record->url_len
  );
  moonbit_bytes_t initialization_script =
    lepusa_windows_initialization_from_record(record);
  (void)lepusa_windows_create_window_slot(
    context,
    record->window,
    record->window_len,
    title,
    url,
    initialization_script,
    width,
    height,
    resizable
  );
}

static void lepusa_windows_apply_open_windows_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
) {
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (context == NULL ||
      packet == NULL ||
      !lepusa_windows_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  for (int32_t i = 0; i < count; i++) {
    LepusaWindowsNativeOperationRecord record;
    if (!lepusa_windows_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    if (lepusa_windows_range_equals(record.kind, record.kind_len, "open-window")) {
      lepusa_windows_open_window_from_record(context, &record);
    }
  }
}

static void lepusa_windows_apply_close_windows_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
) {
  const char *cursor = NULL;
  const char *end = NULL;
  int32_t count = 0;
  if (context == NULL ||
      packet == NULL ||
      !lepusa_windows_handoff_operation_records(packet, &cursor, &end, &count)) {
    return;
  }
  for (int32_t i = 0; i < count; i++) {
    LepusaWindowsNativeOperationRecord record;
    if (!lepusa_windows_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    if (lepusa_windows_range_equals(record.kind, record.kind_len, "close-window")) {
      LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
        context,
        record.window,
        record.window_len
      );
      if (slot != NULL && slot->hwnd != NULL) {
        DestroyWindow(slot->hwnd);
      }
    }
  }
}

static HRESULT STDMETHODCALLTYPE lepusa_windows_environment_invoke(
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self,
  HRESULT error_code,
  ICoreWebView2Environment *environment
) {
  LepusaWindowsEnvironmentCompletedHandler *handler =
    (LepusaWindowsEnvironmentCompletedHandler *)self;
  LepusaWindowsWebView2Context *context = handler->context;
  if (context == NULL) {
    return S_OK;
  }
  context->result = error_code;
  if (FAILED(error_code) || environment == NULL) {
    PostQuitMessage(0);
    return S_OK;
  }
  context->environment = environment;
  context->environment->lpVtbl->AddRef(context->environment);
  LepusaWindowsWindowSlot *slot = lepusa_windows_create_window_slot(
    context,
    (const char *)context->label,
    context->label == NULL ? 0 : Moonbit_array_length(context->label),
    context->title,
    context->url,
    context->initialization_script,
    context->width,
    context->height,
    context->resizable
  );
  if (slot == NULL) {
    PostQuitMessage(0);
    return S_OK;
  }
  lepusa_windows_apply_open_windows_from_handoff_packet(
    context,
    context->initial_open_packet
  );
  return S_OK;
}

static const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl
  lepusa_windows_environment_handler_vtbl = {
    lepusa_windows_environment_query_interface,
    lepusa_windows_environment_add_ref,
    lepusa_windows_environment_release,
    lepusa_windows_environment_invoke
  };

static LRESULT CALLBACK lepusa_windows_webview_window_proc(
  HWND hwnd,
  UINT message,
  WPARAM wparam,
  LPARAM lparam
) {
  LepusaWindowsWindowSlot *slot =
    (LepusaWindowsWindowSlot *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
  switch (message) {
  case WM_SIZE:
    lepusa_windows_resize_slot(slot);
    return 0;
  case WM_CLOSE:
    DestroyWindow(hwnd);
    return 0;
  case WM_DESTROY:
    if (slot != NULL && slot->controller != NULL) {
      slot->controller->lpVtbl->Close(slot->controller);
    }
    if (slot != NULL && slot->context != NULL) {
      slot->hwnd = NULL;
      slot->context->live_windows--;
      if (slot->context->live_windows <= 0) {
        PostQuitMessage(0);
      }
    } else {
      PostQuitMessage(0);
    }
    return 0;
  default:
    return DefWindowProcW(hwnd, message, wparam, lparam);
  }
}

static int lepusa_windows_register_webview_class(HINSTANCE instance) {
  WNDCLASSEXW wc;
  memset(&wc, 0, sizeof(wc));
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = lepusa_windows_webview_window_proc;
  wc.hInstance = instance;
  wc.hCursor = LoadCursor(NULL, IDC_ARROW);
  wc.lpszClassName = L"LepusaWebView2Window";
  if (RegisterClassExW(&wc) != 0 ||
      GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
    return 1;
  }
  return 0;
}

static int32_t lepusa_windows_run_webview2_loop(
  moonbit_bytes_t label,
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  moonbit_bytes_t initial_open_packet,
  int32_t width,
  int32_t height,
  int32_t resizable,
  LepusaWindowsBytesCallback call_dispatch,
  void *dispatch
) {
  HMODULE loader = LoadLibraryA("WebView2Loader.dll");
  if (loader == NULL) {
    return 2;
  }
  LepusaCreateCoreWebView2EnvironmentWithOptions create_environment =
    (LepusaCreateCoreWebView2EnvironmentWithOptions)GetProcAddress(
      loader,
      "CreateCoreWebView2EnvironmentWithOptions"
    );
  if (create_environment == NULL) {
    FreeLibrary(loader);
    return 2;
  }
  HMODULE ole32 = LoadLibraryA("Ole32.dll");
  if (ole32 == NULL) {
    FreeLibrary(loader);
    return 2;
  }
  LepusaWindowsCoInitializeEx co_initialize =
    (LepusaWindowsCoInitializeEx)GetProcAddress(ole32, "CoInitializeEx");
  LepusaWindowsCoUninitialize co_uninitialize =
    (LepusaWindowsCoUninitialize)GetProcAddress(ole32, "CoUninitialize");
  LepusaWindowsCoTaskMemFree co_task_mem_free =
    (LepusaWindowsCoTaskMemFree)GetProcAddress(ole32, "CoTaskMemFree");
  if (co_initialize == NULL ||
      co_uninitialize == NULL ||
      co_task_mem_free == NULL) {
    FreeLibrary(ole32);
    FreeLibrary(loader);
    return 2;
  }
  HRESULT co_result = co_initialize(NULL, COINIT_APARTMENTTHREADED);
  if (FAILED(co_result) && co_result != RPC_E_CHANGED_MODE) {
    FreeLibrary(ole32);
    FreeLibrary(loader);
    return 3;
  }
  HINSTANCE instance = GetModuleHandleW(NULL);
  if (!lepusa_windows_register_webview_class(instance)) {
    if (SUCCEEDED(co_result)) {
      co_uninitialize();
    }
    FreeLibrary(ole32);
    FreeLibrary(loader);
    return 4;
  }
  LepusaWindowsWebView2Context context;
  memset(&context, 0, sizeof(context));
  context.instance = instance;
  context.label = label;
  context.title = title;
  context.url = url;
  context.initialization_script = initialization_script;
  context.initial_open_packet = initial_open_packet;
  context.call_dispatch = call_dispatch;
  context.dispatch = dispatch;
  context.co_task_mem_free = co_task_mem_free;
  context.width = width > 0 ? width : 960;
  context.height = height > 0 ? height : 640;
  context.resizable = resizable != 0;
  context.result = S_OK;
  context.environment_handler.lpVtbl = &lepusa_windows_environment_handler_vtbl;
  context.environment_handler.ref_count = 1;
  context.environment_handler.context = &context;
  HRESULT create_result = create_environment(
    NULL,
    NULL,
    NULL,
    (ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *)
      &context.environment_handler
  );
  if (FAILED(create_result)) {
    context.result = create_result;
    PostQuitMessage(0);
  }
  MSG message;
  while (GetMessageW(&message, NULL, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  for (int i = 0; i < context.window_count; i++) {
    if (context.windows[i].webview != NULL) {
      context.windows[i].webview->lpVtbl->Release(context.windows[i].webview);
    }
    if (context.windows[i].controller != NULL) {
      context.windows[i].controller->lpVtbl->Release(
        context.windows[i].controller
      );
    }
    free(context.windows[i].title);
    free(context.windows[i].url);
    free(context.windows[i].initialization_script);
  }
  if (context.environment != NULL) {
    context.environment->lpVtbl->Release(context.environment);
  }
  if (SUCCEEDED(co_result)) {
    co_uninitialize();
  }
  FreeLibrary(ole32);
  FreeLibrary(loader);
  return SUCCEEDED(context.result) ? 0 : 5;
}
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

MOONBIT_FFI_EXPORT
int32_t lepusa_windows_run_webview(
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
  LepusaWindowsBytesCallback call_dispatch,
  void *dispatch,
  LepusaWindowsBytesCallback call_resolve_asset,
  void *resolve_asset
) {
#if defined(_WIN32)
  (void)label;
  (void)native_hook;
  (void)asset_protocol;
  (void)call_resolve_asset;
  (void)resolve_asset;
  return lepusa_windows_run_webview2_loop(
    label,
    title,
    url,
    initialization_script,
    initial_open_packet,
    width,
    height,
    resizable,
    call_dispatch,
    dispatch
  );
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
int32_t lepusa_windows_start_service(
  moonbit_bytes_t name,
  moonbit_bytes_t command_packet
) {
#if defined(_WIN32)
  char *service_name = lepusa_windows_cstr_from_bytes(name);
  char **argv = NULL;
  int argc = 0;
  if (service_name == NULL ||
      !lepusa_windows_parse_command_packet(command_packet, &argv, &argc)) {
    free(service_name);
    return 1;
  }
  char *command_line = lepusa_windows_command_line(argv, argc);
  lepusa_windows_free_argv(argv, argc);
  if (command_line == NULL) {
    free(service_name);
    return 1;
  }
  STARTUPINFOA startup;
  PROCESS_INFORMATION process;
  memset(&startup, 0, sizeof(startup));
  memset(&process, 0, sizeof(process));
  startup.cb = sizeof(startup);
  BOOL ok = CreateProcessA(
    NULL,
    command_line,
    NULL,
    NULL,
    FALSE,
    CREATE_NEW_PROCESS_GROUP | CREATE_NO_WINDOW,
    NULL,
    NULL,
    &startup,
    &process
  );
  free(command_line);
  if (!ok) {
    free(service_name);
    return 2;
  }
  CloseHandle(process.hThread);
  if (!lepusa_windows_track_service(service_name, process.hProcess)) {
    TerminateProcess(process.hProcess, 1);
    CloseHandle(process.hProcess);
    free(service_name);
    return 3;
  }
  lepusa_windows_install_service_cleanup_handlers();
  free(service_name);
  return 0;
#else
  (void)name;
  (void)command_packet;
  return 2;
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_windows_stop_service(moonbit_bytes_t name) {
#if defined(_WIN32)
  char *service_name = lepusa_windows_cstr_from_bytes(name);
  if (service_name == NULL) {
    return 2;
  }
  HANDLE process = lepusa_windows_untrack_service(service_name);
  free(service_name);
  if (process == NULL) {
    return 1;
  }
  DWORD code = 0;
  if (GetExitCodeProcess(process, &code) && code == STILL_ACTIVE) {
    TerminateProcess(process, 0);
    WaitForSingleObject(process, 1000);
  }
  CloseHandle(process);
  return 0;
#else
  (void)name;
  return 1;
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_windows_wait_until_ready(
  moonbit_bytes_t readiness_url,
  int32_t timeout_ms
) {
#if defined(_WIN32)
  char *url = lepusa_windows_cstr_from_bytes(readiness_url);
  char host[256];
  char port[16];
  char path[512];
  if (url == NULL ||
      !lepusa_windows_parse_http_url(url, host, sizeof(host), port, sizeof(port), path, sizeof(path))) {
    free(url);
    return 2;
  }
  free(url);
  if (!lepusa_windows_load_winsock()) {
    return 2;
  }
  WSADATA data;
  if (lepusa_windows_wsa_startup(MAKEWORD(2, 2), &data) != 0) {
    return 2;
  }
  ULONGLONG deadline = GetTickCount64() + (timeout_ms <= 0 ? 1 : (DWORD)timeout_ms);
  do {
    if (lepusa_windows_try_http_ready(host, port, path)) {
      lepusa_windows_wsa_cleanup();
      return 0;
    }
    Sleep(100);
  } while (GetTickCount64() < deadline);
  lepusa_windows_wsa_cleanup();
  return 1;
#else
  (void)readiness_url;
  (void)timeout_ms;
  return 2;
#endif
}
