#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__) || defined(__linux__)
#include <unistd.h>
#endif

#if defined(_WIN32)
#include <windows.h>
#endif

static moonbit_bytes_t lepusa_clipboard_bytes(const char *text, size_t len) {
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  memcpy(bytes, text, len);
  return bytes;
}

static moonbit_bytes_t lepusa_clipboard_packet(
  const char *status,
  const char *body,
  size_t body_len
) {
  size_t status_len = strlen(status);
  size_t total = status_len + 1 + body_len;
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)total, 0);
  memcpy(bytes, status, status_len);
  bytes[status_len] = '\n';
  if (body_len > 0) {
    memcpy(bytes + status_len + 1, body, body_len);
  }
  return bytes;
}

static char *lepusa_clipboard_cstr_from_bytes(
  moonbit_bytes_t bytes,
  size_t *len_out
) {
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
  if (len_out != NULL) {
    *len_out = (size_t)len;
  }
  return out;
}

#if defined(__APPLE__) || defined(__linux__)
static char *lepusa_clipboard_read_command(
  const char *command,
  size_t *len_out
) {
  FILE *pipe = popen(command, "r");
  if (pipe == NULL) {
    return NULL;
  }
  size_t capacity = 4096;
  size_t len = 0;
  char *buffer = (char *)malloc(capacity);
  if (buffer == NULL) {
    pclose(pipe);
    return NULL;
  }
  for (;;) {
    if (len == capacity) {
      capacity *= 2;
      char *grown = (char *)realloc(buffer, capacity);
      if (grown == NULL) {
        free(buffer);
        pclose(pipe);
        return NULL;
      }
      buffer = grown;
    }
    size_t n = fread(buffer + len, 1, capacity - len, pipe);
    len += n;
    if (n == 0) {
      break;
    }
  }
  int status = pclose(pipe);
  if (status != 0) {
    free(buffer);
    return NULL;
  }
  *len_out = len;
  return buffer;
}

static int32_t lepusa_clipboard_write_command(
  const char *command,
  const char *text,
  size_t len
) {
  FILE *pipe = popen(command, "w");
  if (pipe == NULL) {
    return 2;
  }
  size_t written = len == 0 ? 0 : fwrite(text, 1, len, pipe);
  int status = pclose(pipe);
  return written == len && status == 0 ? 0 : 1;
}
#endif

#if defined(_WIN32)
static moonbit_bytes_t lepusa_clipboard_windows_read_text(void) {
  if (!OpenClipboard(NULL)) {
    return lepusa_clipboard_packet("err", "native clipboard open failed", 28);
  }
  HANDLE data = GetClipboardData(CF_UNICODETEXT);
  if (data == NULL) {
    CloseClipboard();
    return lepusa_clipboard_packet("ok", "", 0);
  }
  WCHAR *wide = (WCHAR *)GlobalLock(data);
  if (wide == NULL) {
    CloseClipboard();
    return lepusa_clipboard_packet("err", "native clipboard read failed", 28);
  }
  int len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);
  if (len <= 0) {
    GlobalUnlock(data);
    CloseClipboard();
    return lepusa_clipboard_packet("err", "native clipboard decode failed", 30);
  }
  char *utf8 = (char *)malloc((size_t)len);
  if (utf8 == NULL) {
    GlobalUnlock(data);
    CloseClipboard();
    return lepusa_clipboard_packet("err", "native clipboard allocation failed", 34);
  }
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, utf8, len, NULL, NULL);
  size_t text_len = strlen(utf8);
  moonbit_bytes_t packet = lepusa_clipboard_packet("ok", utf8, text_len);
  free(utf8);
  GlobalUnlock(data);
  CloseClipboard();
  return packet;
}

static int32_t lepusa_clipboard_windows_write_text(
  const char *text,
  size_t len
) {
  int wide_len = MultiByteToWideChar(
    CP_UTF8,
    0,
    text,
    (int)len,
    NULL,
    0
  );
  if (wide_len < 0) {
    return 1;
  }
  HGLOBAL memory = GlobalAlloc(
    GMEM_MOVEABLE,
    ((size_t)wide_len + 1) * sizeof(WCHAR)
  );
  if (memory == NULL) {
    return 1;
  }
  WCHAR *wide = (WCHAR *)GlobalLock(memory);
  if (wide == NULL) {
    GlobalFree(memory);
    return 1;
  }
  if (wide_len > 0) {
    MultiByteToWideChar(CP_UTF8, 0, text, (int)len, wide, wide_len);
  }
  wide[wide_len] = L'\0';
  GlobalUnlock(memory);
  if (!OpenClipboard(NULL)) {
    GlobalFree(memory);
    return 1;
  }
  EmptyClipboard();
  if (SetClipboardData(CF_UNICODETEXT, memory) == NULL) {
    CloseClipboard();
    GlobalFree(memory);
    return 1;
  }
  CloseClipboard();
  return 0;
}
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_clipboard_available(void) {
#if defined(__APPLE__)
  return access("/usr/bin/pbcopy", X_OK) == 0 &&
    access("/usr/bin/pbpaste", X_OK) == 0;
#elif defined(__linux__)
  return system(
    "command -v wl-copy >/dev/null 2>&1 || "
    "command -v xclip >/dev/null 2>&1 || "
    "command -v xsel >/dev/null 2>&1"
  ) == 0;
#elif defined(_WIN32)
  return 1;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_clipboard_read_text(void) {
#if defined(__APPLE__)
  size_t len = 0;
  char *text = lepusa_clipboard_read_command("/usr/bin/pbpaste", &len);
  if (text == NULL) {
    return lepusa_clipboard_packet("err", "native clipboard read failed", 28);
  }
  moonbit_bytes_t packet = lepusa_clipboard_packet("ok", text, len);
  free(text);
  return packet;
#elif defined(__linux__)
  size_t len = 0;
  char *text = lepusa_clipboard_read_command(
    "wl-paste -n 2>/dev/null || "
    "xclip -selection clipboard -o 2>/dev/null || "
    "xsel --clipboard --output 2>/dev/null",
    &len
  );
  if (text == NULL) {
    return lepusa_clipboard_packet("err", "native clipboard read failed", 28);
  }
  moonbit_bytes_t packet = lepusa_clipboard_packet("ok", text, len);
  free(text);
  return packet;
#elif defined(_WIN32)
  return lepusa_clipboard_windows_read_text();
#else
  return lepusa_clipboard_packet("err", "native clipboard is unavailable", 31);
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_clipboard_write_text(moonbit_bytes_t text) {
  size_t len = 0;
  char *value = lepusa_clipboard_cstr_from_bytes(text, &len);
  if (value == NULL) {
    return 1;
  }
#if defined(__APPLE__)
  int32_t result = lepusa_clipboard_write_command("/usr/bin/pbcopy", value, len);
#elif defined(__linux__)
  int32_t result = lepusa_clipboard_write_command(
    "wl-copy 2>/dev/null || "
    "xclip -selection clipboard 2>/dev/null || "
    "xsel --clipboard --input 2>/dev/null",
    value,
    len
  );
#elif defined(_WIN32)
  int32_t result = lepusa_clipboard_windows_write_text(value, len);
#else
  int32_t result = 2;
#endif
  free(value);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_clipboard_clear(void) {
  moonbit_bytes_t empty = lepusa_clipboard_bytes("", 0);
  return lepusa_clipboard_write_text(empty);
}
