#include <moonbit.h>
#include <string.h>

#if defined(_WIN32)
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

typedef struct {
  char *name;
  HANDLE process;
} LepusaWindowsServiceProcess;

static LepusaWindowsServiceProcess lepusa_windows_service_processes[64];

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
