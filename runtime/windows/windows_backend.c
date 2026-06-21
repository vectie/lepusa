#include <moonbit.h>
#include <string.h>

typedef moonbit_bytes_t (*LepusaWindowsBytesCallback)(void *, moonbit_bytes_t);

#if defined(_WIN32)
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <shellapi.h>
#include <objbase.h>

typedef HRESULT (WINAPI *LepusaWindowsDwmSetWindowAttribute)(
  HWND,
  DWORD,
  LPCVOID,
  DWORD
);

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
typedef struct ICoreWebView2WebResourceRequestedEventHandler
  ICoreWebView2WebResourceRequestedEventHandler;
typedef struct ICoreWebView2WebResourceRequestedEventArgs
  ICoreWebView2WebResourceRequestedEventArgs;
typedef struct ICoreWebView2WebResourceRequest
  ICoreWebView2WebResourceRequest;
typedef struct ICoreWebView2WebResourceResponse
  ICoreWebView2WebResourceResponse;
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
  void *CallDevToolsProtocolMethod;
  void *get_BrowserProcessId;
  void *get_CanGoBack;
  void *get_CanGoForward;
  void *GoBack;
  void *GoForward;
  void *GetDevToolsProtocolEventReceiver;
  void *Stop;
  void *add_NewWindowRequested;
  void *remove_NewWindowRequested;
  void *add_DocumentTitleChanged;
  void *remove_DocumentTitleChanged;
  void *get_DocumentTitle;
  void *AddHostObjectToScript;
  void *RemoveHostObjectFromScript;
  void *OpenDevToolsWindow;
  void *add_ContainsFullScreenElementChanged;
  void *remove_ContainsFullScreenElementChanged;
  void *get_ContainsFullScreenElement;
  HRESULT (STDMETHODCALLTYPE *add_WebResourceRequested)(
    ICoreWebView2 *,
    ICoreWebView2WebResourceRequestedEventHandler *,
    LepusaWindowsEventRegistrationToken *
  );
  void *remove_WebResourceRequested;
  HRESULT (STDMETHODCALLTYPE *AddWebResourceRequestedFilter)(
    ICoreWebView2 *,
    LPCWSTR,
    int
  );
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
  HRESULT (STDMETHODCALLTYPE *CreateWebResourceResponse)(
    ICoreWebView2Environment *,
    IStream *,
    int,
    LPCWSTR,
    LPCWSTR,
    ICoreWebView2WebResourceResponse **
  );
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

typedef struct ICoreWebView2WebResourceResponseVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2WebResourceResponse *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(ICoreWebView2WebResourceResponse *);
  ULONG (STDMETHODCALLTYPE *Release)(ICoreWebView2WebResourceResponse *);
  void *get_Content;
  void *put_Content;
  void *get_Headers;
  void *get_StatusCode;
  void *put_StatusCode;
  void *get_ReasonPhrase;
  void *put_ReasonPhrase;
} ICoreWebView2WebResourceResponseVtbl;

struct ICoreWebView2WebResourceResponse {
  const ICoreWebView2WebResourceResponseVtbl *lpVtbl;
};

typedef struct ICoreWebView2WebResourceRequestVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2WebResourceRequest *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(ICoreWebView2WebResourceRequest *);
  ULONG (STDMETHODCALLTYPE *Release)(ICoreWebView2WebResourceRequest *);
  HRESULT (STDMETHODCALLTYPE *get_Uri)(
    ICoreWebView2WebResourceRequest *,
    LPWSTR *
  );
  void *put_Uri;
  void *get_Method;
  void *put_Method;
  void *get_Content;
  void *put_Content;
  void *get_Headers;
} ICoreWebView2WebResourceRequestVtbl;

struct ICoreWebView2WebResourceRequest {
  const ICoreWebView2WebResourceRequestVtbl *lpVtbl;
};

typedef struct ICoreWebView2WebResourceRequestedEventArgsVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2WebResourceRequestedEventArgs *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(
    ICoreWebView2WebResourceRequestedEventArgs *
  );
  ULONG (STDMETHODCALLTYPE *Release)(
    ICoreWebView2WebResourceRequestedEventArgs *
  );
  HRESULT (STDMETHODCALLTYPE *get_Request)(
    ICoreWebView2WebResourceRequestedEventArgs *,
    ICoreWebView2WebResourceRequest **
  );
  void *get_Response;
  HRESULT (STDMETHODCALLTYPE *put_Response)(
    ICoreWebView2WebResourceRequestedEventArgs *,
    ICoreWebView2WebResourceResponse *
  );
  void *GetDeferral;
  void *get_ResourceContext;
} ICoreWebView2WebResourceRequestedEventArgsVtbl;

struct ICoreWebView2WebResourceRequestedEventArgs {
  const ICoreWebView2WebResourceRequestedEventArgsVtbl *lpVtbl;
};

typedef struct ICoreWebView2WebResourceRequestedEventHandlerVtbl {
  HRESULT (STDMETHODCALLTYPE *QueryInterface)(
    ICoreWebView2WebResourceRequestedEventHandler *,
    REFIID,
    void **
  );
  ULONG (STDMETHODCALLTYPE *AddRef)(
    ICoreWebView2WebResourceRequestedEventHandler *
  );
  ULONG (STDMETHODCALLTYPE *Release)(
    ICoreWebView2WebResourceRequestedEventHandler *
  );
  HRESULT (STDMETHODCALLTYPE *Invoke)(
    ICoreWebView2WebResourceRequestedEventHandler *,
    ICoreWebView2 *,
    ICoreWebView2WebResourceRequestedEventArgs *
  );
} ICoreWebView2WebResourceRequestedEventHandlerVtbl;

struct ICoreWebView2WebResourceRequestedEventHandler {
  const ICoreWebView2WebResourceRequestedEventHandlerVtbl *lpVtbl;
};

typedef HRESULT (WINAPI *LepusaCreateCoreWebView2EnvironmentWithOptions)(
  PCWSTR,
  PCWSTR,
  ICoreWebView2EnvironmentOptions *,
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *
);
typedef HRESULT (WINAPI *LepusaGetAvailableCoreWebView2BrowserVersionString)(
  PCWSTR,
  LPWSTR *
);
typedef HRESULT (WINAPI *LepusaWindowsCoInitializeEx)(LPVOID, DWORD);
typedef void (WINAPI *LepusaWindowsCoUninitialize)(void);
typedef void (WINAPI *LepusaWindowsCoTaskMemFree)(LPVOID);
typedef HRESULT (WINAPI *LepusaWindowsCreateStreamOnHGlobal)(
  HGLOBAL,
  BOOL,
  IStream **
);
typedef BOOL (WINAPI *LepusaWindowsShellNotifyIconW)(
  DWORD,
  PNOTIFYICONDATAW
);

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
static const IID lepusa_iid_web_resource_requested = {
  0xab00b74c,
  0x15f1,
  0x4646,
  { 0x80, 0xe8, 0xe7, 0x63, 0x41, 0xd2, 0x5d, 0x71 }
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
  UINT command_id;
  char id[128];
} LepusaWindowsMenuCommand;

typedef struct {
  UINT command_id;
  char id[128];
} LepusaWindowsTrayCommand;

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

typedef struct {
  const ICoreWebView2WebResourceRequestedEventHandlerVtbl *lpVtbl;
  LONG ref_count;
  LepusaWindowsWebView2Context *context;
  LepusaWindowsWindowSlot *slot;
} LepusaWindowsWebResourceRequestedHandler;

struct LepusaWindowsWindowSlot {
  char label[128];
  HWND hwnd;
  HMENU menu;
  int has_window_menu;
  ICoreWebView2Controller *controller;
  ICoreWebView2 *webview;
  wchar_t *title;
  wchar_t *url;
  wchar_t *initialization_script;
  wchar_t *asset_filter;
  char asset_protocol[64];
  int width;
  int height;
  int resizable;
  int fullscreen;
  DWORD restore_style;
  RECT restore_rect;
  LepusaWindowsEventRegistrationToken web_message_token;
  LepusaWindowsEventRegistrationToken web_resource_token;
  LepusaWindowsControllerCompletedHandler controller_handler;
  LepusaWindowsWebMessageReceivedHandler web_message_handler;
  LepusaWindowsWebResourceRequestedHandler web_resource_handler;
  LepusaWindowsWebView2Context *context;
};

typedef struct {
  char window_label[128];
  char callback[256];
} LepusaWindowsBridgeDrainRequest;

#define LEPUSA_WINDOWS_TRAY_MESSAGE (WM_APP + 0x521)

struct LepusaWindowsWebView2Context {
  HINSTANCE instance;
  ICoreWebView2Environment *environment;
  moonbit_bytes_t label;
  moonbit_bytes_t title;
  moonbit_bytes_t url;
  moonbit_bytes_t initialization_script;
  moonbit_bytes_t asset_protocol;
  int width;
  int height;
  int resizable;
  LepusaWindowsBytesCallback call_dispatch;
  void *dispatch;
  LepusaWindowsBytesCallback call_resolve_asset;
  void *resolve_asset;
  LepusaWindowsCoTaskMemFree co_task_mem_free;
  LepusaWindowsCreateStreamOnHGlobal create_stream_on_hglobal;
  HRESULT result;
  int live_windows;
  LepusaWindowsWindowSlot windows[32];
  int window_count;
  LepusaWindowsBridgeDrainRequest drain_requests[32];
  int drain_request_count;
  char *app_menu_payload;
  int32_t app_menu_payload_len;
  LepusaWindowsMenuCommand menu_commands[512];
  int menu_command_count;
  UINT next_menu_command_id;
  HMODULE shell32;
  LepusaWindowsShellNotifyIconW shell_notify_icon;
  NOTIFYICONDATAW tray_data;
  HICON tray_icon;
  int tray_icon_owned;
  HMENU tray_menu;
  int tray_added;
  int tray_visible;
  LepusaWindowsTrayCommand tray_commands[256];
  int tray_command_count;
  UINT next_tray_command_id;
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

static LepusaWindowsWindowSlot *lepusa_windows_primary_live_slot(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL) {
    return NULL;
  }
  for (int i = 0; i < context->window_count; i++) {
    if (context->windows[i].hwnd != NULL) {
      return &context->windows[i];
    }
  }
  return NULL;
}

static void lepusa_windows_register_bridge_drain_request(
  LepusaWindowsWebView2Context *context,
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
  LepusaWindowsBridgeDrainRequest *request =
    &context->drain_requests[context->drain_request_count++];
  lepusa_windows_copy_label_range(
    request->window_label,
    sizeof(request->window_label),
    window_label,
    window_label_len
  );
  lepusa_windows_copy_label_range(
    request->callback,
    sizeof(request->callback),
    callback,
    callback_len
  );
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

static HRESULT STDMETHODCALLTYPE lepusa_windows_web_resource_query_interface(
  ICoreWebView2WebResourceRequestedEventHandler *self,
  REFIID riid,
  void **object
) {
  if (object == NULL) {
    return E_POINTER;
  }
  if (lepusa_windows_iid_equals(riid, &lepusa_iid_iunknown) ||
      lepusa_windows_iid_equals(riid, &lepusa_iid_web_resource_requested)) {
    *object = self;
    self->lpVtbl->AddRef(self);
    return S_OK;
  }
  *object = NULL;
  return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE lepusa_windows_web_resource_add_ref(
  ICoreWebView2WebResourceRequestedEventHandler *self
) {
  LepusaWindowsWebResourceRequestedHandler *handler =
    (LepusaWindowsWebResourceRequestedHandler *)self;
  return (ULONG)InterlockedIncrement(&handler->ref_count);
}

static ULONG STDMETHODCALLTYPE lepusa_windows_web_resource_release(
  ICoreWebView2WebResourceRequestedEventHandler *self
) {
  LepusaWindowsWebResourceRequestedHandler *handler =
    (LepusaWindowsWebResourceRequestedHandler *)self;
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

static void lepusa_windows_apply_evaluate_scripts_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
);

static void lepusa_windows_apply_bridge_drains_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
);

static void lepusa_windows_apply_navigation_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
);

static void lepusa_windows_apply_window_controls_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
);

static void lepusa_windows_process_bridge_drain_requests(
  LepusaWindowsWebView2Context *context
);

static void lepusa_windows_apply_operations_from_handoff_packet(
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
  lepusa_windows_apply_operations_from_handoff_packet(context, packet);
  lepusa_windows_process_bridge_drain_requests(context);
  return S_OK;
}

static wchar_t *lepusa_windows_wstr_from_range(const char *value, int32_t len) {
  int32_t safe_len = value == NULL || len < 0 ? 0 : len;
  if (safe_len == 0) {
    return (wchar_t *)calloc(1, sizeof(wchar_t));
  }
  int wide_len = MultiByteToWideChar(
    CP_UTF8,
    0,
    value,
    safe_len,
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
  if (MultiByteToWideChar(CP_UTF8, 0, value, safe_len, out, wide_len) != wide_len) {
    free(out);
    return NULL;
  }
  out[wide_len] = L'\0';
  return out;
}

static wchar_t *lepusa_windows_asset_filter_from_protocol(
  moonbit_bytes_t asset_protocol
) {
  if (asset_protocol == NULL || Moonbit_array_length(asset_protocol) <= 0) {
    return NULL;
  }
  char *protocol = lepusa_windows_cstr_from_bytes(asset_protocol);
  if (protocol == NULL || protocol[0] == '\0') {
    free(protocol);
    return NULL;
  }
  const char *template_text = "https://%s.localhost/*";
  int needed = snprintf(NULL, 0, template_text, protocol);
  if (needed < 0) {
    free(protocol);
    return NULL;
  }
  char *filter = (char *)malloc((size_t)needed + 1);
  if (filter == NULL) {
    free(protocol);
    return NULL;
  }
  snprintf(filter, (size_t)needed + 1, template_text, protocol);
  wchar_t *out = lepusa_windows_wstr_from_range(filter, needed);
  free(filter);
  free(protocol);
  return out;
}

static wchar_t *lepusa_windows_webview_url_from_asset_url(
  moonbit_bytes_t url,
  moonbit_bytes_t asset_protocol
) {
  if (url == NULL) {
    return NULL;
  }
  char *url_text = lepusa_windows_cstr_from_bytes(url);
  char *protocol = lepusa_windows_cstr_from_bytes(asset_protocol);
  if (url_text == NULL || protocol == NULL || protocol[0] == '\0') {
    wchar_t *out = lepusa_windows_wstr_from_bytes(url);
    free(url_text);
    free(protocol);
    return out;
  }
  int32_t protocol_len = Moonbit_array_length(asset_protocol);
  const char *scheme_suffix = "://";
  size_t scheme_len = (size_t)protocol_len + strlen(scheme_suffix);
  size_t url_len = strlen(url_text);
  if (url_len < scheme_len ||
      strncmp(url_text, protocol, (size_t)protocol_len) != 0 ||
      strncmp(url_text + protocol_len, scheme_suffix, strlen(scheme_suffix)) != 0) {
    wchar_t *out = lepusa_windows_wstr_from_bytes(url);
    free(url_text);
    free(protocol);
    return out;
  }
  const char *rest = url_text + scheme_len;
  const char *template_text = rest[0] == '/'
    ? "https://%s.localhost%s"
    : "https://%s.localhost/%s";
  int needed = snprintf(NULL, 0, template_text, protocol, rest);
  if (needed < 0) {
    free(url_text);
    free(protocol);
    return lepusa_windows_wstr_from_bytes(url);
  }
  char *webview_url = (char *)malloc((size_t)needed + 1);
  if (webview_url == NULL) {
    free(url_text);
    free(protocol);
    return NULL;
  }
  snprintf(webview_url, (size_t)needed + 1, template_text, protocol, rest);
  wchar_t *out = lepusa_windows_wstr_from_range(webview_url, needed);
  free(webview_url);
  free(url_text);
  free(protocol);
  return out;
}

static moonbit_bytes_t lepusa_windows_resolver_url_from_webview_url(
  moonbit_bytes_t url,
  const char *protocol
) {
  if (url == NULL || protocol == NULL || protocol[0] == '\0') {
    return url;
  }
  char *url_text = lepusa_windows_cstr_from_bytes(url);
  if (url_text == NULL) {
    return url;
  }
  const char *prefixes[2] = { "https://", "http://" };
  const char *rest = NULL;
  size_t url_len = strlen(url_text);
  for (int i = 0; i < 2 && rest == NULL; i++) {
    size_t prefix_len = strlen(prefixes[i]);
    size_t protocol_len = strlen(protocol);
    size_t domain_end = prefix_len + protocol_len + 10;
    if (url_len >= domain_end &&
        strncmp(url_text, prefixes[i], prefix_len) == 0 &&
        strncmp(url_text + prefix_len, protocol, protocol_len) == 0 &&
        strncmp(
          url_text + prefix_len + protocol_len,
          ".localhost",
          10
        ) == 0 &&
        (url_text[domain_end] == '\0' || url_text[domain_end] == '/')) {
      const char *path = url_text + domain_end;
      rest = path[0] == '/' ? path + 1 : path;
    }
  }
  if (rest == NULL) {
    free(url_text);
    return url;
  }
  size_t protocol_len = strlen(protocol);
  size_t rest_len = strlen(rest);
  size_t out_len = protocol_len + 3 + rest_len;
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)out_len, 0);
  memcpy(out, protocol, protocol_len);
  memcpy(out + protocol_len, "://", 3);
  if (rest_len > 0) {
    memcpy(out + protocol_len + 3, rest, rest_len);
  }
  free(url_text);
  return out;
}

static char *lepusa_windows_next_packet_line(
  char **cursor
) {
  if (cursor == NULL || *cursor == NULL) {
    return NULL;
  }
  char *start = *cursor;
  char *newline = strchr(start, '\n');
  if (newline == NULL) {
    *cursor = NULL;
    return start;
  }
  *newline = '\0';
  *cursor = newline + 1;
  return start;
}

static char *lepusa_windows_response_headers(const char *mime_type) {
  const char *safe_mime =
    mime_type == NULL || mime_type[0] == '\0'
      ? "application/octet-stream"
      : mime_type;
  const char *template_text =
    "Content-Type: %s\r\nAccess-Control-Allow-Origin: *";
  int needed = snprintf(NULL, 0, template_text, safe_mime);
  if (needed < 0) {
    return NULL;
  }
  char *headers = (char *)malloc((size_t)needed + 1);
  if (headers == NULL) {
    return NULL;
  }
  snprintf(headers, (size_t)needed + 1, template_text, safe_mime);
  return headers;
}

static int lepusa_windows_read_file_body(
  const char *path,
  char **data_out,
  int64_t *len_out
) {
  if (path == NULL || data_out == NULL || len_out == NULL) {
    return 0;
  }
  wchar_t *wide_path = lepusa_windows_wstr_from_range(
    path,
    (int32_t)strlen(path)
  );
  if (wide_path == NULL) {
    return 0;
  }
  HANDLE file = CreateFileW(
    wide_path,
    GENERIC_READ,
    FILE_SHARE_READ,
    NULL,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    NULL
  );
  free(wide_path);
  if (file == INVALID_HANDLE_VALUE) {
    return 0;
  }
  LARGE_INTEGER size;
  if (!GetFileSizeEx(file, &size) || size.QuadPart < 0 || size.QuadPart > INT32_MAX) {
    CloseHandle(file);
    return 0;
  }
  char *data = (char *)malloc((size_t)size.QuadPart + 1);
  if (data == NULL) {
    CloseHandle(file);
    return 0;
  }
  DWORD read_total = 0;
  BOOL ok = ReadFile(file, data, (DWORD)size.QuadPart, &read_total, NULL);
  CloseHandle(file);
  if (!ok || read_total != (DWORD)size.QuadPart) {
    free(data);
    return 0;
  }
  data[size.QuadPart] = '\0';
  *data_out = data;
  *len_out = (int64_t)size.QuadPart;
  return 1;
}

static HRESULT lepusa_windows_create_resource_response(
  LepusaWindowsWebView2Context *context,
  const char *mime_type,
  const char *body,
  int64_t body_len,
  int status,
  const wchar_t *reason,
  ICoreWebView2WebResourceResponse **response_out
) {
  if (context == NULL ||
      context->environment == NULL ||
      context->create_stream_on_hglobal == NULL ||
      response_out == NULL ||
      body_len < 0 ||
      body_len > INT32_MAX) {
    return E_INVALIDARG;
  }
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, (SIZE_T)(body_len > 0 ? body_len : 1));
  if (memory == NULL) {
    return E_OUTOFMEMORY;
  }
  if (body_len > 0) {
    void *locked = GlobalLock(memory);
    if (locked == NULL) {
      GlobalFree(memory);
      return E_OUTOFMEMORY;
    }
    memcpy(locked, body, (size_t)body_len);
    GlobalUnlock(memory);
  }
  IStream *stream = NULL;
  HRESULT stream_result = context->create_stream_on_hglobal(
    memory,
    TRUE,
    &stream
  );
  if (FAILED(stream_result) || stream == NULL) {
    GlobalFree(memory);
    return stream_result;
  }
  char *headers = lepusa_windows_response_headers(mime_type);
  wchar_t *wide_headers = headers == NULL
    ? NULL
    : lepusa_windows_wstr_from_range(headers, (int32_t)strlen(headers));
  free(headers);
  if (wide_headers == NULL) {
    stream->lpVtbl->Release(stream);
    return E_OUTOFMEMORY;
  }
  HRESULT response_result = context->environment->lpVtbl->CreateWebResourceResponse(
    context->environment,
    stream,
    status,
    reason,
    wide_headers,
    response_out
  );
  free(wide_headers);
  stream->lpVtbl->Release(stream);
  return response_result;
}

static void lepusa_windows_set_resource_text_response(
  LepusaWindowsWebView2Context *context,
  ICoreWebView2WebResourceRequestedEventArgs *args,
  int status,
  const wchar_t *reason,
  const char *message
) {
  if (context == NULL || args == NULL || message == NULL) {
    return;
  }
  ICoreWebView2WebResourceResponse *response = NULL;
  HRESULT result = lepusa_windows_create_resource_response(
    context,
    "text/plain",
    message,
    (int64_t)strlen(message),
    status,
    reason,
    &response
  );
  if (SUCCEEDED(result) && response != NULL) {
    args->lpVtbl->put_Response(args, response);
    response->lpVtbl->Release(response);
  }
}

static void lepusa_windows_apply_evaluate_scripts_from_handoff_packet(
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
    if (!lepusa_windows_range_equals(
          record.kind,
          record.kind_len,
          "evaluate-script"
        ) ||
        record.url_len <= 0) {
      continue;
    }
    LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
      context,
      record.window,
      record.window_len
    );
    if (slot != NULL && slot->webview != NULL) {
      moonbit_bytes_t script = lepusa_windows_bytes_from_range(
        record.url,
        record.url_len
      );
      lepusa_windows_execute_script_bytes(slot, script);
    }
  }
}

static void lepusa_windows_apply_bridge_drains_from_handoff_packet(
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
    if (!lepusa_windows_range_equals(
          record.kind,
          record.kind_len,
          "drain-bridge-window"
        )) {
      continue;
    }
    lepusa_windows_register_bridge_drain_request(
      context,
      record.window,
      record.window_len,
      record.action,
      record.action_len
    );
  }
}

static void lepusa_windows_apply_navigation_from_handoff_packet(
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
    if (!lepusa_windows_range_equals(
          record.kind,
          record.kind_len,
          "navigate-window"
        ) ||
        record.url_len <= 0) {
      continue;
    }
    LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
      context,
      record.window,
      record.window_len
    );
    if (slot == NULL || slot->webview == NULL) {
      continue;
    }
    wchar_t *url = lepusa_windows_wstr_from_range(record.url, record.url_len);
    if (url == NULL) {
      continue;
    }
    slot->webview->lpVtbl->Navigate(slot->webview, url);
    free(url);
  }
}

static moonbit_bytes_t lepusa_windows_bridge_drain_request_message(
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

static void lepusa_windows_process_bridge_drain_requests(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL ||
      context->call_dispatch == NULL ||
      context->dispatch == NULL ||
      context->drain_request_count <= 0) {
    return;
  }
  int rounds = 0;
  while (context->drain_request_count > 0 && rounds++ < 32) {
    LepusaWindowsBridgeDrainRequest requests[32];
    int request_count = context->drain_request_count;
    if (request_count > 32) {
      request_count = 32;
    }
    for (int i = 0; i < request_count; i++) {
      requests[i] = context->drain_requests[i];
    }
    context->drain_request_count = 0;
    for (int i = 0; i < request_count; i++) {
      moonbit_bytes_t request = lepusa_windows_bridge_drain_request_message(
        requests[i].window_label
      );
      moonbit_bytes_t packet = context->call_dispatch(context->dispatch, request);
      moonbit_bytes_t script =
        lepusa_windows_immediate_script_from_handoff_packet(packet);
      LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
        context,
        requests[i].window_label,
        (int32_t)strlen(requests[i].window_label)
      );
      lepusa_windows_execute_script_bytes(slot, script);
      lepusa_windows_apply_operations_from_handoff_packet(context, packet);
    }
  }
}

static void lepusa_windows_set_resource_packet_response(
  LepusaWindowsWebView2Context *context,
  ICoreWebView2WebResourceRequestedEventArgs *args,
  moonbit_bytes_t packet
) {
  if (context == NULL || args == NULL || packet == NULL) {
    lepusa_windows_set_resource_text_response(
      context,
      args,
      404,
      L"Not Found",
      "asset resolution failed"
    );
    return;
  }
  char *packet_text = lepusa_windows_cstr_from_bytes(packet);
  char *cursor = packet_text;
  char *status = lepusa_windows_next_packet_line(&cursor);
  if (packet_text == NULL || status == NULL || strcmp(status, "ok") != 0) {
    lepusa_windows_set_resource_text_response(
      context,
      args,
      404,
      L"Not Found",
      cursor == NULL ? "asset resolution failed" : cursor
    );
    free(packet_text);
    return;
  }
  char *kind = lepusa_windows_next_packet_line(&cursor);
  char *mime_type = lepusa_windows_next_packet_line(&cursor);
  char *body = cursor == NULL ? "" : cursor;
  if (kind == NULL || mime_type == NULL) {
    lepusa_windows_set_resource_text_response(
      context,
      args,
      500,
      L"Malformed Asset Packet",
      "malformed asset packet"
    );
    free(packet_text);
    return;
  }
  ICoreWebView2WebResourceResponse *response = NULL;
  if (strcmp(kind, "virtual") == 0) {
    HRESULT result = lepusa_windows_create_resource_response(
      context,
      mime_type,
      body,
      (int64_t)strlen(body),
      200,
      L"OK",
      &response
    );
    if (SUCCEEDED(result) && response != NULL) {
      args->lpVtbl->put_Response(args, response);
      response->lpVtbl->Release(response);
    }
  } else if (strcmp(kind, "file") == 0) {
    char *data = NULL;
    int64_t data_len = 0;
    if (lepusa_windows_read_file_body(body, &data, &data_len)) {
      HRESULT result = lepusa_windows_create_resource_response(
        context,
        mime_type,
        data,
        data_len,
        200,
        L"OK",
        &response
      );
      if (SUCCEEDED(result) && response != NULL) {
        args->lpVtbl->put_Response(args, response);
        response->lpVtbl->Release(response);
      }
      free(data);
    } else {
      lepusa_windows_set_resource_text_response(
        context,
        args,
        404,
        L"Not Found",
        "asset file could not be read"
      );
    }
  } else {
    lepusa_windows_set_resource_text_response(
      context,
      args,
      500,
      L"Unsupported Asset Packet",
      "unsupported asset packet kind"
    );
  }
  free(packet_text);
}

static HRESULT STDMETHODCALLTYPE lepusa_windows_web_resource_invoke(
  ICoreWebView2WebResourceRequestedEventHandler *self,
  ICoreWebView2 *sender,
  ICoreWebView2WebResourceRequestedEventArgs *args
) {
  (void)sender;
  LepusaWindowsWebResourceRequestedHandler *handler =
    (LepusaWindowsWebResourceRequestedHandler *)self;
  LepusaWindowsWebView2Context *context = handler->context;
  if (context == NULL ||
      args == NULL ||
      context->call_resolve_asset == NULL ||
      context->resolve_asset == NULL) {
    return S_OK;
  }
  ICoreWebView2WebResourceRequest *request = NULL;
  HRESULT request_result = args->lpVtbl->get_Request(args, &request);
  if (FAILED(request_result) || request == NULL) {
    lepusa_windows_set_resource_text_response(
      context,
      args,
      404,
      L"Not Found",
      "asset request is unavailable"
    );
    return S_OK;
  }
  LPWSTR uri = NULL;
  HRESULT uri_result = request->lpVtbl->get_Uri(request, &uri);
  request->lpVtbl->Release(request);
  if (FAILED(uri_result) || uri == NULL) {
    lepusa_windows_set_resource_text_response(
      context,
      args,
      404,
      L"Not Found",
      "asset request url is unavailable"
    );
    return S_OK;
  }
  moonbit_bytes_t webview_url = lepusa_windows_bytes_from_wstr(uri);
  if (context->co_task_mem_free != NULL) {
    context->co_task_mem_free(uri);
  }
  if (webview_url == NULL) {
    lepusa_windows_set_resource_text_response(
      context,
      args,
      404,
      L"Not Found",
      "asset request url could not be decoded"
    );
    return S_OK;
  }
  moonbit_bytes_t url = lepusa_windows_resolver_url_from_webview_url(
    webview_url,
    handler->slot == NULL ? NULL : handler->slot->asset_protocol
  );
  moonbit_bytes_t packet = context->call_resolve_asset(
    context->resolve_asset,
    url
  );
  lepusa_windows_set_resource_packet_response(context, args, packet);
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
  if (context->call_resolve_asset != NULL &&
      context->resolve_asset != NULL &&
      slot->asset_filter != NULL &&
      slot->asset_filter[0] != L'\0') {
    slot->webview->lpVtbl->AddWebResourceRequestedFilter(
      slot->webview,
      slot->asset_filter,
      0
    );
    slot->webview->lpVtbl->add_WebResourceRequested(
      slot->webview,
      (ICoreWebView2WebResourceRequestedEventHandler *)
        &slot->web_resource_handler,
      &slot->web_resource_token
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

static const ICoreWebView2WebResourceRequestedEventHandlerVtbl
  lepusa_windows_web_resource_handler_vtbl = {
    lepusa_windows_web_resource_query_interface,
    lepusa_windows_web_resource_add_ref,
    lepusa_windows_web_resource_release,
    lepusa_windows_web_resource_invoke
  };

static HMENU lepusa_windows_menu_from_payload(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
);

static void lepusa_windows_set_slot_menu(
  LepusaWindowsWindowSlot *slot,
  HMENU menu
);

static LepusaWindowsWindowSlot *lepusa_windows_create_window_slot(
  LepusaWindowsWebView2Context *context,
  const char *label,
  int32_t label_len,
  moonbit_bytes_t title,
  moonbit_bytes_t url,
  moonbit_bytes_t initialization_script,
  moonbit_bytes_t asset_protocol,
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
  lepusa_windows_copy_label_range(
    slot->asset_protocol,
    sizeof(slot->asset_protocol),
    asset_protocol == NULL ? NULL : (const char *)asset_protocol,
    asset_protocol == NULL ? 0 : Moonbit_array_length(asset_protocol)
  );
  slot->url = lepusa_windows_webview_url_from_asset_url(url, asset_protocol);
  slot->initialization_script = lepusa_windows_wstr_from_bytes(
    initialization_script
  );
  slot->asset_filter = lepusa_windows_asset_filter_from_protocol(asset_protocol);
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
  slot->web_resource_handler.lpVtbl = &lepusa_windows_web_resource_handler_vtbl;
  slot->web_resource_handler.ref_count = 1;
  slot->web_resource_handler.context = context;
  slot->web_resource_handler.slot = slot;
  if (slot->title == NULL ||
      slot->url == NULL ||
      slot->initialization_script == NULL) {
    free(slot->title);
    free(slot->url);
    free(slot->initialization_script);
    free(slot->asset_filter);
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
    free(slot->asset_filter);
    memset(slot, 0, sizeof(*slot));
    return NULL;
  }
  context->window_count++;
  context->live_windows++;
  SetWindowLongPtrW(slot->hwnd, GWLP_USERDATA, (LONG_PTR)slot);
  if (context->app_menu_payload != NULL && !slot->has_window_menu) {
    HMENU menu = lepusa_windows_menu_from_payload(
      context,
      context->app_menu_payload,
      context->app_menu_payload_len
    );
    lepusa_windows_set_slot_menu(slot, menu);
  }
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
  moonbit_bytes_t asset_protocol = lepusa_windows_bytes_from_range(
    record->asset_protocol,
    record->asset_protocol_len
  );
  (void)lepusa_windows_create_window_slot(
    context,
    record->window,
    record->window_len,
    title,
    url,
    initialization_script,
    asset_protocol,
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

static void lepusa_windows_set_window_content_size(
  LepusaWindowsWindowSlot *slot,
  int width,
  int height
) {
  if (slot == NULL || slot->hwnd == NULL || width <= 0 || height <= 0) {
    return;
  }
  DWORD style = (DWORD)GetWindowLongPtrW(slot->hwnd, GWL_STYLE);
  RECT rect = { 0, 0, width, height };
  AdjustWindowRect(&rect, style, FALSE);
  SetWindowPos(
    slot->hwnd,
    NULL,
    0,
    0,
    rect.right - rect.left,
    rect.bottom - rect.top,
    SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE
  );
}

static void lepusa_windows_set_window_fullscreen(
  LepusaWindowsWindowSlot *slot,
  int fullscreen
) {
  if (slot == NULL || slot->hwnd == NULL) {
    return;
  }
  if (fullscreen && !slot->fullscreen) {
    slot->restore_style = (DWORD)GetWindowLongPtrW(slot->hwnd, GWL_STYLE);
    GetWindowRect(slot->hwnd, &slot->restore_rect);
    HMONITOR monitor = MonitorFromWindow(slot->hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info;
    memset(&info, 0, sizeof(info));
    info.cbSize = sizeof(info);
    if (!GetMonitorInfoW(monitor, &info)) {
      return;
    }
    DWORD fullscreen_style = slot->restore_style &
      ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    SetWindowLongPtrW(slot->hwnd, GWL_STYLE, (LONG_PTR)fullscreen_style);
    SetWindowPos(
      slot->hwnd,
      HWND_TOP,
      info.rcMonitor.left,
      info.rcMonitor.top,
      info.rcMonitor.right - info.rcMonitor.left,
      info.rcMonitor.bottom - info.rcMonitor.top,
      SWP_FRAMECHANGED | SWP_SHOWWINDOW
    );
    slot->fullscreen = 1;
  } else if (!fullscreen && slot->fullscreen) {
    SetWindowLongPtrW(slot->hwnd, GWL_STYLE, (LONG_PTR)slot->restore_style);
    SetWindowPos(
      slot->hwnd,
      NULL,
      slot->restore_rect.left,
      slot->restore_rect.top,
      slot->restore_rect.right - slot->restore_rect.left,
      slot->restore_rect.bottom - slot->restore_rect.top,
      SWP_FRAMECHANGED | SWP_NOZORDER | SWP_SHOWWINDOW
    );
    slot->fullscreen = 0;
  }
}

static void lepusa_windows_apply_window_control(
  LepusaWindowsWindowSlot *slot,
  LepusaWindowsNativeOperationRecord *record
) {
  if (slot == NULL || record == NULL || slot->hwnd == NULL) {
    return;
  }
  if (lepusa_windows_range_equals(record->action, record->action_len, "setTitle")) {
    wchar_t *title = lepusa_windows_wstr_from_range(
      record->title,
      record->title_len
    );
    if (title != NULL) {
      SetWindowTextW(slot->hwnd, title);
      free(title);
    }
  } else if (lepusa_windows_range_equals(
               record->action,
               record->action_len,
               "setSize"
             )) {
    int width = 0;
    int height = 0;
    if (lepusa_windows_parse_record_int(record->width, record->width_len, &width) &&
        lepusa_windows_parse_record_int(
          record->height,
          record->height_len,
          &height
        )) {
      lepusa_windows_set_window_content_size(slot, width, height);
    }
  } else if (lepusa_windows_range_equals(
               record->action,
               record->action_len,
               "setPosition"
             )) {
    int x = 0;
    int y = 0;
    if (lepusa_windows_parse_record_int(record->x, record->x_len, &x) &&
        lepusa_windows_parse_record_int(record->y, record->y_len, &y)) {
      SetWindowPos(
        slot->hwnd,
        NULL,
        x,
        y,
        0,
        0,
        SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
      );
    }
  } else if (lepusa_windows_range_equals(
               record->action,
               record->action_len,
               "setFullscreen"
             )) {
    int fullscreen = 0;
    if (lepusa_windows_parse_record_bool(
          record->fullscreen,
          record->fullscreen_len,
          &fullscreen
        )) {
      lepusa_windows_set_window_fullscreen(slot, fullscreen);
    }
  } else if (lepusa_windows_range_equals(record->action, record->action_len, "show")) {
    ShowWindow(slot->hwnd, SW_SHOW);
  } else if (lepusa_windows_range_equals(record->action, record->action_len, "focus")) {
    ShowWindow(slot->hwnd, SW_SHOW);
    SetForegroundWindow(slot->hwnd);
    SetFocus(slot->hwnd);
  } else if (lepusa_windows_range_equals(record->action, record->action_len, "hide")) {
    ShowWindow(slot->hwnd, SW_HIDE);
  } else if (lepusa_windows_range_equals(
               record->action,
               record->action_len,
               "minimize"
             )) {
    ShowWindow(slot->hwnd, SW_MINIMIZE);
  } else if (lepusa_windows_range_equals(
               record->action,
               record->action_len,
               "maximize"
             )) {
    ShowWindow(slot->hwnd, SW_MAXIMIZE);
  } else if (lepusa_windows_range_equals(
               record->action,
               record->action_len,
               "unmaximize"
             )) {
    ShowWindow(slot->hwnd, SW_RESTORE);
  } else if (lepusa_windows_range_equals(record->action, record->action_len, "close")) {
    DestroyWindow(slot->hwnd);
  }
}

static void lepusa_windows_apply_window_controls_from_handoff_packet(
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
  int closed = 0;
  for (int32_t i = 0; i < count; i++) {
    LepusaWindowsNativeOperationRecord record;
    if (!lepusa_windows_read_native_operation_record(&cursor, end, &record)) {
      return;
    }
    LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
      context,
      record.window,
      record.window_len
    );
    if (slot == NULL || slot->hwnd == NULL) {
      continue;
    }
    if (lepusa_windows_range_equals(record.kind, record.kind_len, "close-window")) {
      if (!closed) {
        DestroyWindow(slot->hwnd);
        closed = 1;
      }
      continue;
    }
    if (lepusa_windows_range_equals(
          record.kind,
          record.kind_len,
          "window-control"
        )) {
      lepusa_windows_apply_window_control(slot, &record);
    }
  }
}

static void lepusa_windows_close_all_windows(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL) {
    return;
  }
  for (int i = context->window_count - 1; i >= 0; i--) {
    HWND hwnd = context->windows[i].hwnd;
    if (hwnd != NULL) {
      DestroyWindow(hwnd);
    }
  }
}

static int lepusa_windows_spawn_current_process(void) {
  LPWSTR command_line = GetCommandLineW();
  if (command_line == NULL || command_line[0] == L'\0') {
    return 0;
  }
  size_t length = wcslen(command_line);
  wchar_t *mutable_command_line =
    (wchar_t *)calloc(length + 1, sizeof(wchar_t));
  if (mutable_command_line == NULL) {
    return 0;
  }
  memcpy(
    mutable_command_line,
    command_line,
    (length + 1) * sizeof(wchar_t)
  );
  STARTUPINFOW startup;
  PROCESS_INFORMATION process;
  memset(&startup, 0, sizeof(startup));
  memset(&process, 0, sizeof(process));
  startup.cb = sizeof(startup);
  BOOL ok = CreateProcessW(
    NULL,
    mutable_command_line,
    NULL,
    NULL,
    FALSE,
    0,
    NULL,
    NULL,
    &startup,
    &process
  );
  free(mutable_command_line);
  if (!ok) {
    return 0;
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return 1;
}

static int lepusa_windows_app_shell_action_equals(
  const char *action,
  int32_t action_len,
  const char *name
) {
  size_t name_len = strlen(name);
  return lepusa_windows_range_equals(action, action_len, name) ||
    (action != NULL &&
     action_len == (int32_t)(name_len + 4) &&
     memcmp(action, "app.", 4) == 0 &&
     memcmp(action + 4, name, name_len) == 0);
}

static int lepusa_windows_range_contains_text(
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

static int lepusa_windows_theme_payload_prefers_dark(
  const char *payload,
  int32_t payload_len,
  int *dark_out
) {
  if (dark_out == NULL) {
    return 0;
  }
  if (payload_len <= 0 ||
      lepusa_windows_range_contains_text(payload, payload_len, "system") ||
      lepusa_windows_range_contains_text(payload, payload_len, "light")) {
    *dark_out = 0;
    return 1;
  }
  if (lepusa_windows_range_contains_text(payload, payload_len, "dark")) {
    *dark_out = 1;
    return 1;
  }
  return 0;
}

static void lepusa_windows_apply_window_dark_mode(HWND hwnd, int prefer_dark) {
  if (hwnd == NULL) {
    return;
  }
  HMODULE dwmapi = LoadLibraryA("dwmapi.dll");
  if (dwmapi == NULL) {
    return;
  }
  LepusaWindowsDwmSetWindowAttribute set_window_attribute =
    (LepusaWindowsDwmSetWindowAttribute)GetProcAddress(
      dwmapi,
      "DwmSetWindowAttribute"
    );
  if (set_window_attribute != NULL) {
    BOOL enabled = prefer_dark ? TRUE : FALSE;
    HRESULT result = set_window_attribute(
      hwnd,
      20,
      &enabled,
      sizeof(enabled)
    );
    if (FAILED(result)) {
      (void)set_window_attribute(hwnd, 19, &enabled, sizeof(enabled));
    }
  }
  FreeLibrary(dwmapi);
}

static void lepusa_windows_apply_app_theme(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
) {
  int prefer_dark = 0;
  if (context == NULL ||
      !lepusa_windows_theme_payload_prefers_dark(payload, payload_len, &prefer_dark)) {
    return;
  }
  for (int i = 0; i < context->window_count; i++) {
    if (context->windows[i].hwnd != NULL) {
      lepusa_windows_apply_window_dark_mode(
        context->windows[i].hwnd,
        prefer_dark
      );
    }
  }
}

static const char *lepusa_windows_json_skip_space(const char *cursor, const char *end) {
  while (cursor < end && isspace((unsigned char)*cursor)) {
    cursor++;
  }
  return cursor;
}

static const char *lepusa_windows_json_string_end(const char *cursor, const char *end) {
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

static const char *lepusa_windows_json_value_end(const char *cursor, const char *end) {
  cursor = lepusa_windows_json_skip_space(cursor, end);
  if (cursor >= end) {
    return NULL;
  }
  if (*cursor == '"') {
    return lepusa_windows_json_string_end(cursor, end);
  }
  if (*cursor == '{' || *cursor == '[') {
    char open = *cursor;
    char close = open == '{' ? '}' : ']';
    int depth = 1;
    cursor++;
    while (cursor < end) {
      if (*cursor == '"') {
        cursor = lepusa_windows_json_string_end(cursor, end);
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

static int lepusa_windows_json_find_member_value(
  const char *object,
  const char *end,
  const char *name,
  const char **value_out,
  const char **value_end_out
) {
  if (object == NULL || end == NULL || name == NULL || value_out == NULL || value_end_out == NULL) {
    return 0;
  }
  const char *cursor = lepusa_windows_json_skip_space(object, end);
  if (cursor >= end || *cursor != '{') {
    return 0;
  }
  cursor++;
  size_t name_len = strlen(name);
  while (cursor < end) {
    cursor = lepusa_windows_json_skip_space(cursor, end);
    if (cursor >= end || *cursor == '}') {
      return 0;
    }
    const char *key_start = cursor;
    const char *key_end = lepusa_windows_json_string_end(cursor, end);
    if (key_end == NULL) {
      return 0;
    }
    cursor = lepusa_windows_json_skip_space(key_end, end);
    if (cursor >= end || *cursor != ':') {
      return 0;
    }
    cursor++;
    const char *value = lepusa_windows_json_skip_space(cursor, end);
    const char *value_end = lepusa_windows_json_value_end(value, end);
    if (value_end == NULL) {
      return 0;
    }
    if ((size_t)(key_end - key_start - 2) == name_len &&
        memcmp(key_start + 1, name, name_len) == 0) {
      *value_out = value;
      *value_end_out = value_end;
      return 1;
    }
    cursor = lepusa_windows_json_skip_space(value_end, end);
    if (cursor < end && *cursor == ',') {
      cursor++;
    }
  }
  return 0;
}

static int lepusa_windows_json_member_string_range(
  const char *object,
  const char *end,
  const char *field,
  const char **value_out,
  int32_t *value_len_out
) {
  const char *value = NULL;
  const char *value_end = NULL;
  if (!lepusa_windows_json_find_member_value(object, end, field, &value, &value_end)) {
    return 0;
  }
  value = lepusa_windows_json_skip_space(value, value_end);
  const char *string_end = lepusa_windows_json_string_end(value, value_end);
  if (string_end == NULL) {
    return 0;
  }
  *value_out = value + 1;
  *value_len_out = (int32_t)(string_end - value - 2);
  return 1;
}

static int lepusa_windows_json_bool_value(
  const char *value,
  const char *end,
  int *out
) {
  if (out == NULL) {
    return 0;
  }
  value = lepusa_windows_json_skip_space(value, end);
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

static int lepusa_windows_json_member_bool(
  const char *object,
  const char *end,
  const char *field,
  int fallback
) {
  const char *value = NULL;
  const char *value_end = NULL;
  int out = fallback;
  if (lepusa_windows_json_find_member_value(object, end, field, &value, &value_end)) {
    lepusa_windows_json_bool_value(value, value_end, &out);
  }
  return out;
}

static char *lepusa_windows_cstr_from_range(const char *value, int32_t len);

static char *lepusa_windows_json_string_value_to_cstr(
  const char *value,
  const char *end
) {
  value = lepusa_windows_json_skip_space(value, end);
  if (value >= end || *value != '"') {
    return NULL;
  }
  const char *value_end = lepusa_windows_json_string_end(value, end);
  if (value_end == NULL || value_end > end) {
    return NULL;
  }
  return lepusa_windows_cstr_from_range(
    value + 1,
    (int32_t)(value_end - value - 2)
  );
}

static char *lepusa_windows_json_payload_string(
  const char *payload,
  int32_t payload_len,
  const char *field
) {
  if (payload == NULL || payload_len <= 0) {
    return NULL;
  }
  const char *end = payload + payload_len;
  const char *cursor = lepusa_windows_json_skip_space(payload, end);
  if (cursor < end && *cursor == '"') {
    return lepusa_windows_json_string_value_to_cstr(cursor, end);
  }
  const char *value = NULL;
  const char *value_end = NULL;
  if (lepusa_windows_json_find_member_value(cursor, end, field, &value, &value_end)) {
    return lepusa_windows_json_string_value_to_cstr(value, value_end);
  }
  return NULL;
}

static int lepusa_windows_json_payload_bool(
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
  const char *cursor = lepusa_windows_json_skip_space(payload, end);
  if (lepusa_windows_json_bool_value(cursor, end, &value)) {
    return value;
  }
  const char *member = NULL;
  const char *member_end = NULL;
  if (lepusa_windows_json_find_member_value(cursor, end, field, &member, &member_end)) {
    lepusa_windows_json_bool_value(member, member_end, &value);
  }
  return value;
}

static char *lepusa_windows_cstr_from_range(const char *value, int32_t len) {
  int32_t safe_len = value == NULL || len < 0 ? 0 : len;
  char *out = (char *)malloc((size_t)safe_len + 1);
  if (out == NULL) {
    return NULL;
  }
  if (safe_len > 0) {
    memcpy(out, value, (size_t)safe_len);
  }
  out[safe_len] = '\0';
  return out;
}

static int lepusa_windows_menu_action_equals(
  const char *action,
  int32_t action_len,
  const char *name
) {
  size_t name_len = strlen(name);
  return lepusa_windows_range_equals(action, action_len, name) ||
    (action != NULL &&
     action_len == (int32_t)(name_len + 5) &&
     memcmp(action, "menu.", 5) == 0 &&
     memcmp(action + 5, name, name_len) == 0);
}

static UINT lepusa_windows_register_menu_command(
  LepusaWindowsWebView2Context *context,
  const char *id,
  int32_t id_len
) {
  if (context == NULL || id == NULL || id_len <= 0 || context->menu_command_count >= 512) {
    return 0;
  }
  if (context->next_menu_command_id < 1000) {
    context->next_menu_command_id = 1000;
  }
  UINT command_id = context->next_menu_command_id++;
  LepusaWindowsMenuCommand *command =
    &context->menu_commands[context->menu_command_count++];
  command->command_id = command_id;
  lepusa_windows_copy_label_range(
    command->id,
    sizeof(command->id),
    id,
    id_len
  );
  return command_id;
}

static const char *lepusa_windows_menu_command_id(
  LepusaWindowsWebView2Context *context,
  UINT command_id
) {
  if (context == NULL) {
    return NULL;
  }
  for (int i = 0; i < context->menu_command_count; i++) {
    if (context->menu_commands[i].command_id == command_id) {
      return context->menu_commands[i].id;
    }
  }
  return NULL;
}

static char *lepusa_windows_json_string_literal_from_cstr(const char *value) {
  if (value == NULL) {
    return NULL;
  }
  size_t value_len = strlen(value);
  char *escaped = (char *)malloc(value_len * 6 + 3);
  if (escaped == NULL) {
    return NULL;
  }
  size_t pos = 0;
  escaped[pos++] = '"';
  for (const char *p = value; *p != '\0'; p++) {
    unsigned char ch = (unsigned char)*p;
    if (ch == '"' || ch == '\\') {
      escaped[pos++] = '\\';
      escaped[pos++] = (char)ch;
    } else {
      escaped[pos++] = (char)ch;
    }
  }
  escaped[pos++] = '"';
  escaped[pos] = '\0';
  return escaped;
}

static void lepusa_windows_dispatch_id_event(
  LepusaWindowsWindowSlot *slot,
  const char *event,
  const char *id
) {
  if (slot == NULL ||
      slot->webview == NULL ||
      event == NULL ||
      id == NULL ||
      id[0] == '\0') {
    return;
  }
  const char *template_text =
    "(globalThis[\"__lepusaDispatchEvent\"]||(()=>false))({name:%s,payload:JSON.stringify({id:%s})});";
  char *event_literal = lepusa_windows_json_string_literal_from_cstr(event);
  char *id_literal = lepusa_windows_json_string_literal_from_cstr(id);
  if (event_literal == NULL || id_literal == NULL) {
    free(event_literal);
    free(id_literal);
    return;
  }
  int needed = snprintf(NULL, 0, template_text, event_literal, id_literal);
  if (needed >= 0) {
    char *script = (char *)malloc((size_t)needed + 1);
    if (script != NULL) {
      snprintf(
        script,
        (size_t)needed + 1,
        template_text,
        event_literal,
        id_literal
      );
      wchar_t *wide_script = lepusa_windows_wstr_from_range(
        script,
        (int32_t)strlen(script)
      );
      if (wide_script != NULL) {
        slot->webview->lpVtbl->ExecuteScript(slot->webview, wide_script, NULL);
        free(wide_script);
      }
      free(script);
    }
  }
  free(event_literal);
  free(id_literal);
}

static void lepusa_windows_dispatch_menu_click(
  LepusaWindowsWindowSlot *slot,
  const char *id
) {
  lepusa_windows_dispatch_id_event(slot, "menu.onItemClick", id);
}

static HMENU lepusa_windows_menu_from_array(
  LepusaWindowsWebView2Context *context,
  const char *array,
  const char *array_end,
  int depth
) {
  if (context == NULL || array == NULL || depth > 8) {
    return NULL;
  }
  const char *cursor = lepusa_windows_json_skip_space(array, array_end);
  if (cursor >= array_end || *cursor != '[') {
    return NULL;
  }
  HMENU menu = depth == 0 ? CreateMenu() : CreatePopupMenu();
  if (menu == NULL) {
    return NULL;
  }
  cursor++;
  while (cursor < array_end) {
    cursor = lepusa_windows_json_skip_space(cursor, array_end);
    if (cursor >= array_end || *cursor == ']') {
      return menu;
    }
    if (*cursor == ',') {
      cursor++;
      continue;
    }
    const char *item_end = lepusa_windows_json_value_end(cursor, array_end);
    if (item_end == NULL) {
      return menu;
    }
    if (cursor < item_end && *cursor == '{') {
      const char *kind = NULL;
      int32_t kind_len = 0;
      const char *label = NULL;
      int32_t label_len = 0;
      (void)lepusa_windows_json_member_string_range(
        cursor,
        item_end,
        "kind",
        &kind,
        &kind_len
      );
      if (lepusa_windows_range_equals(kind, kind_len, "separator")) {
        AppendMenuW(menu, MF_SEPARATOR, 0, NULL);
      } else if (lepusa_windows_json_member_string_range(
                   cursor,
                   item_end,
                   "label",
                   &label,
                   &label_len
                 )) {
        wchar_t *label_text = lepusa_windows_wstr_from_range(label, label_len);
        if (label_text != NULL) {
          UINT flags = MF_STRING;
          if (!lepusa_windows_json_member_bool(cursor, item_end, "enabled", 1)) {
            flags |= MF_GRAYED;
          }
          if (lepusa_windows_range_equals(kind, kind_len, "check") &&
              lepusa_windows_json_member_bool(cursor, item_end, "checked", 0)) {
            flags |= MF_CHECKED;
          }
          if (lepusa_windows_range_equals(kind, kind_len, "submenu")) {
            const char *children = NULL;
            const char *children_end = NULL;
            if (lepusa_windows_json_find_member_value(
                  cursor,
                  item_end,
                  "items",
                  &children,
                  &children_end
                )) {
              HMENU submenu = lepusa_windows_menu_from_array(
                context,
                children,
                children_end,
                depth + 1
              );
              if (submenu != NULL) {
                AppendMenuW(menu, flags | MF_POPUP, (UINT_PTR)submenu, label_text);
              }
            }
          } else {
            const char *id = NULL;
            int32_t id_len = 0;
            UINT command_id = lepusa_windows_json_member_string_range(
              cursor,
              item_end,
              "id",
              &id,
              &id_len
            )
              ? lepusa_windows_register_menu_command(context, id, id_len)
              : 0;
            if (command_id != 0) {
              AppendMenuW(menu, flags, command_id, label_text);
            }
          }
          free(label_text);
        }
      }
    }
    cursor = lepusa_windows_json_skip_space(item_end, array_end);
    if (cursor < array_end && *cursor == ',') {
      cursor++;
    }
  }
  return menu;
}

static HMENU lepusa_windows_menu_from_payload(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL || payload == NULL || payload_len <= 0) {
    return NULL;
  }
  const char *end = payload + payload_len;
  const char *items = lepusa_windows_json_skip_space(payload, end);
  const char *items_end = end;
  const char *member = NULL;
  const char *member_end = NULL;
  if (items < end && *items == '{' &&
      lepusa_windows_json_find_member_value(items, end, "items", &member, &member_end)) {
    items = member;
    items_end = member_end;
  }
  return lepusa_windows_menu_from_array(context, items, items_end, 0);
}

static void lepusa_windows_set_slot_menu(
  LepusaWindowsWindowSlot *slot,
  HMENU menu
) {
  if (slot == NULL || slot->hwnd == NULL) {
    if (menu != NULL) {
      DestroyMenu(menu);
    }
    return;
  }
  HMENU old_menu = slot->menu;
  slot->menu = menu;
  SetMenu(slot->hwnd, menu);
  DrawMenuBar(slot->hwnd);
  if (old_menu != NULL) {
    DestroyMenu(old_menu);
  }
}

static void lepusa_windows_apply_app_menu_to_windows(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL || context->app_menu_payload == NULL) {
    return;
  }
  for (int i = 0; i < context->window_count; i++) {
    LepusaWindowsWindowSlot *slot = &context->windows[i];
    if (slot->hwnd != NULL && !slot->has_window_menu) {
      HMENU menu = lepusa_windows_menu_from_payload(
        context,
        context->app_menu_payload,
        context->app_menu_payload_len
      );
      lepusa_windows_set_slot_menu(slot, menu);
    }
  }
}

static void lepusa_windows_set_app_menu(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL || payload == NULL || payload_len <= 0) {
    return;
  }
  char *copy = lepusa_windows_cstr_from_range(payload, payload_len);
  if (copy == NULL) {
    return;
  }
  free(context->app_menu_payload);
  context->app_menu_payload = copy;
  context->app_menu_payload_len = payload_len;
  lepusa_windows_apply_app_menu_to_windows(context);
}

static void lepusa_windows_clear_app_menu(LepusaWindowsWebView2Context *context) {
  if (context == NULL) {
    return;
  }
  free(context->app_menu_payload);
  context->app_menu_payload = NULL;
  context->app_menu_payload_len = 0;
  for (int i = 0; i < context->window_count; i++) {
    LepusaWindowsWindowSlot *slot = &context->windows[i];
    if (slot->hwnd != NULL && !slot->has_window_menu) {
      lepusa_windows_set_slot_menu(slot, NULL);
    }
  }
}

static void lepusa_windows_set_window_menu(
  LepusaWindowsWebView2Context *context,
  const char *label,
  int32_t label_len,
  const char *payload,
  int32_t payload_len
) {
  LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
    context,
    label,
    label_len
  );
  if (slot == NULL) {
    return;
  }
  HMENU menu = lepusa_windows_menu_from_payload(context, payload, payload_len);
  if (menu != NULL) {
    slot->has_window_menu = 1;
    lepusa_windows_set_slot_menu(slot, menu);
  }
}

static void lepusa_windows_clear_window_menu(
  LepusaWindowsWebView2Context *context,
  const char *label,
  int32_t label_len
) {
  LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
    context,
    label,
    label_len
  );
  if (slot == NULL) {
    return;
  }
  slot->has_window_menu = 0;
  if (context != NULL && context->app_menu_payload != NULL) {
    HMENU menu = lepusa_windows_menu_from_payload(
      context,
      context->app_menu_payload,
      context->app_menu_payload_len
    );
    lepusa_windows_set_slot_menu(slot, menu);
  } else {
    lepusa_windows_set_slot_menu(slot, NULL);
  }
}

static int lepusa_windows_tray_action_equals(
  const char *action,
  int32_t action_len,
  const char *name
) {
  size_t name_len = strlen(name);
  return lepusa_windows_range_equals(action, action_len, name) ||
    (action != NULL &&
     action_len == (int32_t)(name_len + 5) &&
     memcmp(action, "tray.", 5) == 0 &&
     memcmp(action + 5, name, name_len) == 0);
}

static int lepusa_windows_ensure_shell_notify_icon(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL) {
    return 0;
  }
  if (context->shell_notify_icon != NULL) {
    return 1;
  }
  if (context->shell32 == NULL) {
    context->shell32 = LoadLibraryA("Shell32.dll");
  }
  if (context->shell32 == NULL) {
    return 0;
  }
  context->shell_notify_icon =
    (LepusaWindowsShellNotifyIconW)GetProcAddress(
      context->shell32,
      "Shell_NotifyIconW"
    );
  return context->shell_notify_icon != NULL;
}

static HICON lepusa_windows_default_tray_icon(void) {
  return LoadIconW(NULL, IDI_APPLICATION);
}

static void lepusa_windows_reset_tray_commands(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL) {
    return;
  }
  context->tray_command_count = 0;
  context->next_tray_command_id = 20000;
}

static UINT lepusa_windows_register_tray_command(
  LepusaWindowsWebView2Context *context,
  const char *id,
  int32_t id_len
) {
  if (context == NULL || id == NULL || id_len <= 0 || context->tray_command_count >= 256) {
    return 0;
  }
  if (context->next_tray_command_id < 20000) {
    context->next_tray_command_id = 20000;
  }
  UINT command_id = context->next_tray_command_id++;
  LepusaWindowsTrayCommand *command =
    &context->tray_commands[context->tray_command_count++];
  command->command_id = command_id;
  lepusa_windows_copy_label_range(
    command->id,
    sizeof(command->id),
    id,
    id_len
  );
  return command_id;
}

static const char *lepusa_windows_tray_command_id(
  LepusaWindowsWebView2Context *context,
  UINT command_id
) {
  if (context == NULL) {
    return NULL;
  }
  for (int i = 0; i < context->tray_command_count; i++) {
    if (context->tray_commands[i].command_id == command_id) {
      return context->tray_commands[i].id;
    }
  }
  return NULL;
}

static void lepusa_windows_dispatch_tray_click(
  LepusaWindowsWebView2Context *context,
  const char *id
) {
  LepusaWindowsWindowSlot *slot = lepusa_windows_primary_live_slot(context);
  lepusa_windows_dispatch_id_event(slot, "tray.onMenuItemClick", id);
}

static void lepusa_windows_remove_tray(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL) {
    return;
  }
  if (context->tray_added && lepusa_windows_ensure_shell_notify_icon(context)) {
    context->shell_notify_icon(NIM_DELETE, &context->tray_data);
  }
  context->tray_added = 0;
  context->tray_visible = 0;
}

static int lepusa_windows_ensure_tray(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL || !lepusa_windows_ensure_shell_notify_icon(context)) {
    return 0;
  }
  LepusaWindowsWindowSlot *slot = lepusa_windows_primary_live_slot(context);
  if (slot == NULL || slot->hwnd == NULL) {
    return 0;
  }
  if (context->tray_icon == NULL) {
    context->tray_icon = lepusa_windows_default_tray_icon();
    context->tray_icon_owned = 0;
  }
  if (!context->tray_added) {
    context->tray_data.cbSize = sizeof(context->tray_data);
    context->tray_data.hWnd = slot->hwnd;
    context->tray_data.uID = 1;
    context->tray_data.uCallbackMessage = LEPUSA_WINDOWS_TRAY_MESSAGE;
    context->tray_data.uFlags = NIF_MESSAGE | NIF_ICON;
    context->tray_data.hIcon = context->tray_icon;
    if (context->tray_data.szTip[0] != L'\0') {
      context->tray_data.uFlags |= NIF_TIP;
    }
    if (!context->shell_notify_icon(NIM_ADD, &context->tray_data)) {
      return 0;
    }
    context->tray_added = 1;
    context->tray_visible = 1;
  } else if (context->tray_data.hWnd != slot->hwnd) {
    context->tray_data.hWnd = slot->hwnd;
    context->tray_data.uFlags = NIF_MESSAGE;
    context->shell_notify_icon(NIM_MODIFY, &context->tray_data);
  }
  return 1;
}

static void lepusa_windows_set_tray_icon(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL) {
    return;
  }
  char *icon_path = lepusa_windows_json_payload_string(
    payload,
    payload_len,
    "iconPath"
  );
  HICON icon = NULL;
  int icon_owned = 0;
  if (icon_path != NULL) {
    wchar_t *wide_path = lepusa_windows_wstr_from_range(
      icon_path,
      (int32_t)strlen(icon_path)
    );
    if (wide_path != NULL) {
      icon = (HICON)LoadImageW(
        NULL,
        wide_path,
        IMAGE_ICON,
        0,
        0,
        LR_LOADFROMFILE | LR_DEFAULTSIZE
      );
      if (icon != NULL) {
        icon_owned = 1;
      }
      free(wide_path);
    }
  }
  free(icon_path);
  if (icon == NULL) {
    icon = lepusa_windows_default_tray_icon();
    icon_owned = 0;
  }
  if (icon == NULL) {
    return;
  }
  if (context->tray_icon_owned && context->tray_icon != NULL) {
    DestroyIcon(context->tray_icon);
  }
  context->tray_icon = icon;
  context->tray_icon_owned = icon_owned;
  if (lepusa_windows_ensure_tray(context) && context->tray_added) {
    context->tray_data.uFlags = NIF_ICON;
    context->tray_data.hIcon = context->tray_icon;
    context->shell_notify_icon(NIM_MODIFY, &context->tray_data);
  }
}

static void lepusa_windows_set_tray_tooltip(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL) {
    return;
  }
  if (!lepusa_windows_ensure_tray(context)) {
    return;
  }
  char *tooltip = lepusa_windows_json_payload_string(
    payload,
    payload_len,
    "tooltip"
  );
  if (tooltip == NULL) {
    return;
  }
  wchar_t *wide_tooltip = lepusa_windows_wstr_from_range(
    tooltip,
    (int32_t)strlen(tooltip)
  );
  free(tooltip);
  if (wide_tooltip == NULL) {
    return;
  }
  wcsncpy(
    context->tray_data.szTip,
    wide_tooltip,
    sizeof(context->tray_data.szTip) / sizeof(context->tray_data.szTip[0]) - 1
  );
  context->tray_data.szTip[
    sizeof(context->tray_data.szTip) / sizeof(context->tray_data.szTip[0]) - 1
  ] = L'\0';
  free(wide_tooltip);
  if (context->tray_added) {
    context->tray_data.uFlags = NIF_TIP;
    context->shell_notify_icon(NIM_MODIFY, &context->tray_data);
  }
}

static HMENU lepusa_windows_tray_menu_from_array(
  LepusaWindowsWebView2Context *context,
  const char *array,
  const char *array_end
) {
  if (context == NULL || array == NULL) {
    return NULL;
  }
  const char *cursor = lepusa_windows_json_skip_space(array, array_end);
  if (cursor >= array_end || *cursor != '[') {
    return NULL;
  }
  HMENU menu = CreatePopupMenu();
  if (menu == NULL) {
    return NULL;
  }
  cursor++;
  while (cursor < array_end) {
    cursor = lepusa_windows_json_skip_space(cursor, array_end);
    if (cursor >= array_end || *cursor == ']') {
      return menu;
    }
    if (*cursor == ',') {
      cursor++;
      continue;
    }
    const char *item_end = lepusa_windows_json_value_end(cursor, array_end);
    if (item_end == NULL) {
      return menu;
    }
    if (cursor < item_end && *cursor == '{') {
      const char *kind = NULL;
      int32_t kind_len = 0;
      const char *label = NULL;
      int32_t label_len = 0;
      const char *id = NULL;
      int32_t id_len = 0;
      (void)lepusa_windows_json_member_string_range(
        cursor,
        item_end,
        "kind",
        &kind,
        &kind_len
      );
      if (lepusa_windows_range_equals(kind, kind_len, "separator")) {
        AppendMenuW(menu, MF_SEPARATOR, 0, NULL);
      } else if (lepusa_windows_json_member_string_range(
                   cursor,
                   item_end,
                   "label",
                   &label,
                   &label_len
                 )) {
        wchar_t *label_text = lepusa_windows_wstr_from_range(label, label_len);
        if (label_text != NULL) {
          UINT flags = MF_STRING;
          if (!lepusa_windows_json_member_bool(cursor, item_end, "enabled", 1)) {
            flags |= MF_GRAYED;
          }
          if (lepusa_windows_range_equals(kind, kind_len, "check") &&
              lepusa_windows_json_member_bool(cursor, item_end, "checked", 0)) {
            flags |= MF_CHECKED;
          }
          UINT command_id = lepusa_windows_json_member_string_range(
            cursor,
            item_end,
            "id",
            &id,
            &id_len
          )
            ? lepusa_windows_register_tray_command(context, id, id_len)
            : 0;
          if (command_id != 0) {
            AppendMenuW(menu, flags, command_id, label_text);
          }
          free(label_text);
        }
      }
    }
    cursor = lepusa_windows_json_skip_space(item_end, array_end);
    if (cursor < array_end && *cursor == ',') {
      cursor++;
    }
  }
  return menu;
}

static void lepusa_windows_set_tray_menu(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
) {
  if (context == NULL || payload == NULL || payload_len <= 0) {
    return;
  }
  const char *end = payload + payload_len;
  const char *items = lepusa_windows_json_skip_space(payload, end);
  const char *items_end = end;
  const char *member = NULL;
  const char *member_end = NULL;
  if (items < end && *items == '{' &&
      lepusa_windows_json_find_member_value(items, end, "items", &member, &member_end)) {
    items = member;
    items_end = member_end;
  }
  lepusa_windows_reset_tray_commands(context);
  HMENU menu = lepusa_windows_tray_menu_from_array(context, items, items_end);
  if (menu == NULL) {
    return;
  }
  if (context->tray_menu != NULL) {
    DestroyMenu(context->tray_menu);
  }
  context->tray_menu = menu;
  (void)lepusa_windows_ensure_tray(context);
}

static void lepusa_windows_show_tray_menu(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL || context->tray_menu == NULL) {
    return;
  }
  LepusaWindowsWindowSlot *slot = lepusa_windows_primary_live_slot(context);
  if (slot == NULL || slot->hwnd == NULL) {
    return;
  }
  POINT point;
  GetCursorPos(&point);
  SetForegroundWindow(slot->hwnd);
  TrackPopupMenu(
    context->tray_menu,
    TPM_RIGHTBUTTON | TPM_LEFTALIGN | TPM_BOTTOMALIGN,
    point.x,
    point.y,
    0,
    slot->hwnd,
    NULL
  );
  PostMessageW(slot->hwnd, WM_NULL, 0, 0);
}

static void lepusa_windows_set_tray_visible(
  LepusaWindowsWebView2Context *context,
  const char *payload,
  int32_t payload_len
) {
  int visible = lepusa_windows_json_payload_bool(
    payload,
    payload_len,
    "visible",
    1
  );
  if (visible) {
    (void)lepusa_windows_ensure_tray(context);
  } else {
    lepusa_windows_remove_tray(context);
  }
}

static void lepusa_windows_destroy_tray(
  LepusaWindowsWebView2Context *context
) {
  if (context == NULL) {
    return;
  }
  lepusa_windows_remove_tray(context);
  if (context->tray_menu != NULL) {
    DestroyMenu(context->tray_menu);
    context->tray_menu = NULL;
  }
  if (context->tray_icon_owned && context->tray_icon != NULL) {
    DestroyIcon(context->tray_icon);
  }
  context->tray_icon = NULL;
  context->tray_icon_owned = 0;
  lepusa_windows_reset_tray_commands(context);
}

static void lepusa_windows_apply_desktop_shell_from_handoff_packet(
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
    if (!lepusa_windows_range_equals(
          record.kind,
          record.kind_len,
          "desktop-shell"
        )) {
      continue;
    }
    if (lepusa_windows_menu_action_equals(record.action, record.action_len, "setAppMenu")) {
      lepusa_windows_set_app_menu(context, record.url, record.url_len);
      continue;
    }
    if (lepusa_windows_menu_action_equals(record.action, record.action_len, "clearAppMenu")) {
      lepusa_windows_clear_app_menu(context);
      continue;
    }
    if (lepusa_windows_menu_action_equals(record.action, record.action_len, "setWindowMenu")) {
      lepusa_windows_set_window_menu(
        context,
        record.window,
        record.window_len,
        record.url,
        record.url_len
      );
      continue;
    }
    if (lepusa_windows_menu_action_equals(record.action, record.action_len, "clearWindowMenu")) {
      lepusa_windows_clear_window_menu(
        context,
        record.window,
        record.window_len
      );
      continue;
    }
    if (lepusa_windows_tray_action_equals(record.action, record.action_len, "setIcon")) {
      lepusa_windows_set_tray_icon(context, record.url, record.url_len);
      continue;
    }
    if (lepusa_windows_tray_action_equals(record.action, record.action_len, "setTooltip")) {
      lepusa_windows_set_tray_tooltip(context, record.url, record.url_len);
      continue;
    }
    if (lepusa_windows_tray_action_equals(record.action, record.action_len, "setMenu")) {
      lepusa_windows_set_tray_menu(context, record.url, record.url_len);
      continue;
    }
    if (lepusa_windows_tray_action_equals(record.action, record.action_len, "showMenu")) {
      lepusa_windows_show_tray_menu(context);
      continue;
    }
    if (lepusa_windows_tray_action_equals(record.action, record.action_len, "setVisible")) {
      lepusa_windows_set_tray_visible(context, record.url, record.url_len);
      continue;
    }
    if (lepusa_windows_tray_action_equals(record.action, record.action_len, "destroy")) {
      lepusa_windows_destroy_tray(context);
      continue;
    }
    if (lepusa_windows_app_shell_action_equals(record.action, record.action_len, "restart")) {
      if (lepusa_windows_spawn_current_process()) {
        lepusa_windows_close_all_windows(context);
      }
      continue;
    }
    if (lepusa_windows_app_shell_action_equals(record.action, record.action_len, "exit")) {
      lepusa_windows_close_all_windows(context);
      continue;
    }
    if (lepusa_windows_app_shell_action_equals(record.action, record.action_len, "setTheme")) {
      lepusa_windows_apply_app_theme(context, record.url, record.url_len);
      continue;
    }
    LepusaWindowsWindowSlot *slot = lepusa_windows_find_window_slot(
      context,
      record.window,
      record.window_len
    );
    if (slot == NULL || slot->hwnd == NULL) {
      continue;
    }
    if (lepusa_windows_app_shell_action_equals(record.action, record.action_len, "show")) {
      ShowWindow(slot->hwnd, SW_SHOW);
      SetForegroundWindow(slot->hwnd);
    } else if (lepusa_windows_app_shell_action_equals(record.action, record.action_len, "hide")) {
      ShowWindow(slot->hwnd, SW_HIDE);
    }
  }
}

static void lepusa_windows_apply_operations_from_handoff_packet(
  LepusaWindowsWebView2Context *context,
  moonbit_bytes_t packet
) {
  lepusa_windows_apply_evaluate_scripts_from_handoff_packet(context, packet);
  lepusa_windows_apply_bridge_drains_from_handoff_packet(context, packet);
  lepusa_windows_apply_open_windows_from_handoff_packet(context, packet);
  lepusa_windows_apply_navigation_from_handoff_packet(context, packet);
  lepusa_windows_apply_window_controls_from_handoff_packet(context, packet);
  lepusa_windows_apply_desktop_shell_from_handoff_packet(context, packet);
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
    context->asset_protocol,
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
  case WM_COMMAND:
    if (slot != NULL && slot->context != NULL) {
      UINT command_id = LOWORD(wparam);
      const char *tray_item_id = lepusa_windows_tray_command_id(
        slot->context,
        command_id
      );
      if (tray_item_id != NULL) {
        lepusa_windows_dispatch_tray_click(slot->context, tray_item_id);
        return 0;
      }
      const char *item_id = lepusa_windows_menu_command_id(
        slot->context,
        command_id
      );
      if (item_id != NULL) {
        lepusa_windows_dispatch_menu_click(slot, item_id);
        return 0;
      }
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
  case LEPUSA_WINDOWS_TRAY_MESSAGE:
    if (slot != NULL && slot->context != NULL) {
      if (lparam == WM_LBUTTONUP ||
          lparam == WM_RBUTTONUP ||
          lparam == WM_CONTEXTMENU) {
        lepusa_windows_show_tray_menu(slot->context);
        return 0;
      }
    }
    return 0;
  case WM_CLOSE:
    DestroyWindow(hwnd);
    return 0;
  case WM_DESTROY:
    if (slot != NULL && slot->menu != NULL) {
      DestroyMenu(slot->menu);
      slot->menu = NULL;
    }
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
  HMODULE loader = LoadLibraryA("WebView2Loader.dll");
  if (loader == NULL) {
    return 20;
  }
  LepusaCreateCoreWebView2EnvironmentWithOptions create_environment =
    (LepusaCreateCoreWebView2EnvironmentWithOptions)GetProcAddress(
      loader,
      "CreateCoreWebView2EnvironmentWithOptions"
    );
  LepusaGetAvailableCoreWebView2BrowserVersionString get_available_version =
    (LepusaGetAvailableCoreWebView2BrowserVersionString)GetProcAddress(
      loader,
      "GetAvailableCoreWebView2BrowserVersionString"
    );
  if (create_environment == NULL || get_available_version == NULL) {
    FreeLibrary(loader);
    return 21;
  }
  HMODULE ole32 = LoadLibraryA("Ole32.dll");
  if (ole32 == NULL) {
    FreeLibrary(loader);
    return 23;
  }
  LepusaWindowsCoInitializeEx co_initialize =
    (LepusaWindowsCoInitializeEx)GetProcAddress(ole32, "CoInitializeEx");
  LepusaWindowsCoUninitialize co_uninitialize =
    (LepusaWindowsCoUninitialize)GetProcAddress(ole32, "CoUninitialize");
  LepusaWindowsCoTaskMemFree co_task_mem_free =
    (LepusaWindowsCoTaskMemFree)GetProcAddress(ole32, "CoTaskMemFree");
  LepusaWindowsCreateStreamOnHGlobal create_stream_on_hglobal =
    (LepusaWindowsCreateStreamOnHGlobal)GetProcAddress(
      ole32,
      "CreateStreamOnHGlobal"
    );
  if (co_initialize == NULL ||
      co_uninitialize == NULL ||
      co_task_mem_free == NULL ||
      create_stream_on_hglobal == NULL) {
    FreeLibrary(ole32);
    FreeLibrary(loader);
    return 24;
  }
  LPWSTR webview2_version = NULL;
  HRESULT version_result = get_available_version(NULL, &webview2_version);
  int has_webview2_runtime = SUCCEEDED(version_result) &&
    webview2_version != NULL;
  if (webview2_version != NULL) {
    co_task_mem_free(webview2_version);
  }
  if (!has_webview2_runtime) {
    FreeLibrary(ole32);
    FreeLibrary(loader);
    return 22;
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
  context.asset_protocol = asset_protocol;
  context.initial_open_packet = initial_open_packet;
  context.call_dispatch = call_dispatch;
  context.dispatch = dispatch;
  context.call_resolve_asset = call_resolve_asset;
  context.resolve_asset = resolve_asset;
  context.co_task_mem_free = co_task_mem_free;
  context.create_stream_on_hglobal = create_stream_on_hglobal;
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
  lepusa_windows_destroy_tray(&context);
  for (int i = 0; i < context.window_count; i++) {
    if (context.windows[i].menu != NULL) {
      DestroyMenu(context.windows[i].menu);
    }
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
    free(context.windows[i].asset_filter);
  }
  free(context.app_menu_payload);
  if (context.environment != NULL) {
    context.environment->lpVtbl->Release(context.environment);
  }
  if (SUCCEEDED(co_result)) {
    co_uninitialize();
  }
  if (context.shell32 != NULL) {
    FreeLibrary(context.shell32);
  }
  FreeLibrary(ole32);
  FreeLibrary(loader);
  return SUCCEEDED(context.result) ? 0 : 5;
}
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_windows_backend_available(void) {
#if defined(_WIN32)
  HMODULE loader = LoadLibraryA("WebView2Loader.dll");
  if (loader == NULL) {
    return 0;
  }
  LepusaCreateCoreWebView2EnvironmentWithOptions create_environment =
    (LepusaCreateCoreWebView2EnvironmentWithOptions)GetProcAddress(
      loader,
      "CreateCoreWebView2EnvironmentWithOptions"
    );
  LepusaGetAvailableCoreWebView2BrowserVersionString get_available_version =
    (LepusaGetAvailableCoreWebView2BrowserVersionString)GetProcAddress(
      loader,
      "GetAvailableCoreWebView2BrowserVersionString"
    );
  if (create_environment == NULL || get_available_version == NULL) {
    FreeLibrary(loader);
    return 0;
  }
  HMODULE ole32 = LoadLibraryA("Ole32.dll");
  if (ole32 == NULL) {
    FreeLibrary(loader);
    return 0;
  }
  LepusaWindowsCoTaskMemFree co_task_mem_free =
    (LepusaWindowsCoTaskMemFree)GetProcAddress(ole32, "CoTaskMemFree");
  if (co_task_mem_free == NULL) {
    FreeLibrary(ole32);
    FreeLibrary(loader);
    return 0;
  }
  LPWSTR webview2_version = NULL;
  HRESULT result = get_available_version(NULL, &webview2_version);
  int available = SUCCEEDED(result) && webview2_version != NULL;
  if (webview2_version != NULL) {
    co_task_mem_free(webview2_version);
  }
  FreeLibrary(ole32);
  FreeLibrary(loader);
  if (!available) {
    return 0;
  }
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
  (void)native_hook;
  return lepusa_windows_run_webview2_loop(
    label,
    title,
    url,
    initialization_script,
    asset_protocol,
    initial_open_packet,
    width,
    height,
    resizable,
    call_dispatch,
    dispatch,
    call_resolve_asset,
    resolve_asset
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
