#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__) || defined(__linux__)
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

#if defined(_WIN32)
#include <windows.h>
#endif

static char *lepusa_auto_launch_cstr_from_bytes(moonbit_bytes_t bytes) {
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

static int lepusa_auto_launch_file_exists(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return 0;
  }
#if defined(_WIN32)
  DWORD attributes = GetFileAttributesA(path);
  return attributes != INVALID_FILE_ATTRIBUTES;
#else
  return access(path, F_OK) == 0;
#endif
}

#if defined(__APPLE__) || defined(__linux__)
static int lepusa_auto_launch_ensure_dir(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return 0;
  }
  if (mkdir(path, 0700) == 0) {
    return 1;
  }
  return errno == EEXIST;
}

static char *lepusa_auto_launch_join3(
  const char *a,
  const char *b,
  const char *c
) {
  size_t len = strlen(a) + strlen(b) + strlen(c) + 1;
  char *out = (char *)malloc(len);
  if (out == NULL) {
    return NULL;
  }
  strcpy(out, a);
  strcat(out, b);
  strcat(out, c);
  return out;
}

static char *lepusa_auto_launch_shell_quote(const char *text) {
  size_t len = 2;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    len += *p == '\'' ? 4 : 1;
  }
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  out[offset++] = '\'';
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    if (*p == '\'') {
      memcpy(out + offset, "'\\''", 4);
      offset += 4;
    } else {
      out[offset++] = *p;
    }
  }
  out[offset++] = '\'';
  out[offset] = '\0';
  return out;
}

static char *lepusa_auto_launch_command_line(
  const char *executable,
  const char *arguments
) {
  char *quoted_executable = lepusa_auto_launch_shell_quote(executable);
  if (quoted_executable == NULL) {
    return NULL;
  }
  size_t len = strlen("exec ") + strlen(quoted_executable) +
    strlen(arguments == NULL ? "" : arguments) * 4 + 64;
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    free(quoted_executable);
    return NULL;
  }
  strcpy(out, "exec ");
  strcat(out, quoted_executable);
  free(quoted_executable);
  for (const char *start = arguments == NULL ? "" : arguments; *start != '\0';) {
    const char *end = strchr(start, '\n');
    size_t part_len = end == NULL ? strlen(start) : (size_t)(end - start);
    if (part_len > 0) {
      char *part = (char *)malloc(part_len + 1);
      if (part == NULL) {
        free(out);
        return NULL;
      }
      memcpy(part, start, part_len);
      part[part_len] = '\0';
      char *quoted = lepusa_auto_launch_shell_quote(part);
      free(part);
      if (quoted == NULL) {
        free(out);
        return NULL;
      }
      strcat(out, " ");
      strcat(out, quoted);
      free(quoted);
    }
    if (end == NULL) {
      break;
    }
    start = end + 1;
  }
  return out;
}

static char *lepusa_auto_launch_desktop_quote(const char *text) {
  size_t len = 2;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    len += (*p == '"' || *p == '\\' || *p == '`' || *p == '$') ? 2 : 1;
  }
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  out[offset++] = '"';
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    if (*p == '"' || *p == '\\' || *p == '`' || *p == '$') {
      out[offset++] = '\\';
    }
    out[offset++] = *p;
  }
  out[offset++] = '"';
  out[offset] = '\0';
  return out;
}

static char *lepusa_auto_launch_desktop_command_line(
  const char *executable,
  const char *arguments
) {
  char *quoted_executable = lepusa_auto_launch_desktop_quote(executable);
  if (quoted_executable == NULL) {
    return NULL;
  }
  size_t len = strlen(quoted_executable) +
    strlen(arguments == NULL ? "" : arguments) * 3 + 64;
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    free(quoted_executable);
    return NULL;
  }
  strcpy(out, quoted_executable);
  free(quoted_executable);
  for (const char *start = arguments == NULL ? "" : arguments; *start != '\0';) {
    const char *end = strchr(start, '\n');
    size_t part_len = end == NULL ? strlen(start) : (size_t)(end - start);
    if (part_len > 0) {
      char *part = (char *)malloc(part_len + 1);
      if (part == NULL) {
        free(out);
        return NULL;
      }
      memcpy(part, start, part_len);
      part[part_len] = '\0';
      char *quoted = lepusa_auto_launch_desktop_quote(part);
      free(part);
      if (quoted == NULL) {
        free(out);
        return NULL;
      }
      strcat(out, " ");
      strcat(out, quoted);
      free(quoted);
    }
    if (end == NULL) {
      break;
    }
    start = end + 1;
  }
  return out;
}

static int lepusa_auto_launch_write_file(const char *path, const char *text) {
  FILE *file = fopen(path, "w");
  if (file == NULL) {
    return 0;
  }
  int ok = fputs(text, file) >= 0;
  ok = fclose(file) == 0 && ok;
  return ok;
}

static char *lepusa_auto_launch_xml_escape(const char *text) {
  size_t len = 0;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    switch (*p) {
      case '&': len += 5; break;
      case '<': len += 4; break;
      case '>': len += 4; break;
      case '"': len += 6; break;
      case '\'': len += 6; break;
      default: len += 1; break;
    }
  }
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    switch (*p) {
      case '&':
        memcpy(out + offset, "&amp;", 5);
        offset += 5;
        break;
      case '<':
        memcpy(out + offset, "&lt;", 4);
        offset += 4;
        break;
      case '>':
        memcpy(out + offset, "&gt;", 4);
        offset += 4;
        break;
      case '"':
        memcpy(out + offset, "&quot;", 6);
        offset += 6;
        break;
      case '\'':
        memcpy(out + offset, "&apos;", 6);
        offset += 6;
        break;
      default:
        out[offset++] = *p;
        break;
    }
  }
  out[offset] = '\0';
  return out;
}
#endif

#if defined(__APPLE__)
static char *lepusa_auto_launch_macos_path(const char *name) {
  const char *home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return NULL;
  }
  char *dir = lepusa_auto_launch_join3(home, "/", "Library/LaunchAgents");
  if (dir == NULL) {
    return NULL;
  }
  char *file = lepusa_auto_launch_join3("/", name, ".plist");
  char *path = file == NULL ? NULL : lepusa_auto_launch_join3(dir, file, "");
  free(dir);
  free(file);
  return path;
}

static int lepusa_auto_launch_macos_enable(
  const char *name,
  const char *executable,
  const char *arguments
) {
  const char *home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return 2;
  }
  char *library = lepusa_auto_launch_join3(home, "/", "Library");
  char *dir = lepusa_auto_launch_join3(home, "/", "Library/LaunchAgents");
  char *path = lepusa_auto_launch_macos_path(name);
  char *command = lepusa_auto_launch_command_line(executable, arguments);
  char *xml_name = lepusa_auto_launch_xml_escape(name);
  char *xml_command = lepusa_auto_launch_xml_escape(command);
  if (library == NULL || dir == NULL || path == NULL || command == NULL ||
      xml_name == NULL || xml_command == NULL) {
    free(library);
    free(dir);
    free(path);
    free(command);
    free(xml_name);
    free(xml_command);
    return 1;
  }
  if (!lepusa_auto_launch_ensure_dir(library) ||
      !lepusa_auto_launch_ensure_dir(dir)) {
    free(library);
    free(dir);
    free(path);
    free(command);
    free(xml_name);
    free(xml_command);
    return 1;
  }
  size_t len = strlen(xml_name) + strlen(xml_command) + 512;
  char *plist = (char *)malloc(len);
  if (plist == NULL) {
    free(library);
    free(dir);
    free(path);
    free(command);
    free(xml_name);
    free(xml_command);
    return 1;
  }
  snprintf(
    plist,
    len,
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
    "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
    "<plist version=\"1.0\"><dict>\n"
    "<key>Label</key><string>%s</string>\n"
    "<key>ProgramArguments</key><array>"
    "<string>/bin/sh</string><string>-c</string><string>%s</string>"
    "</array>\n"
    "<key>RunAtLoad</key><true/>\n"
    "</dict></plist>\n",
    xml_name,
    xml_command
  );
  int ok = lepusa_auto_launch_write_file(path, plist);
  free(library);
  free(dir);
  free(path);
  free(command);
  free(xml_name);
  free(xml_command);
  free(plist);
  return ok ? 0 : 1;
}
#endif

#if defined(__linux__)
static char *lepusa_auto_launch_linux_path(const char *name) {
  const char *home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return NULL;
  }
  char *dir = lepusa_auto_launch_join3(home, "/", ".config/autostart");
  if (dir == NULL) {
    return NULL;
  }
  char *file = lepusa_auto_launch_join3("/", name, ".desktop");
  char *path = file == NULL ? NULL : lepusa_auto_launch_join3(dir, file, "");
  free(dir);
  free(file);
  return path;
}

static int lepusa_auto_launch_linux_enable(
  const char *name,
  const char *executable,
  const char *arguments,
  int open_hidden
) {
  const char *home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return 2;
  }
  char *config = lepusa_auto_launch_join3(home, "/", ".config");
  char *dir = lepusa_auto_launch_join3(home, "/", ".config/autostart");
  char *path = lepusa_auto_launch_linux_path(name);
  char *command = lepusa_auto_launch_desktop_command_line(
    executable,
    arguments
  );
  if (config == NULL || dir == NULL || path == NULL || command == NULL) {
    free(config);
    free(dir);
    free(path);
    free(command);
    return 1;
  }
  if (!lepusa_auto_launch_ensure_dir(config) ||
      !lepusa_auto_launch_ensure_dir(dir)) {
    free(config);
    free(dir);
    free(path);
    free(command);
    return 1;
  }
  size_t len = strlen(name) + strlen(command) + 256;
  char *desktop = (char *)malloc(len);
  if (desktop == NULL) {
    free(config);
    free(dir);
    free(path);
    free(command);
    return 1;
  }
  snprintf(
    desktop,
    len,
    "[Desktop Entry]\n"
    "Type=Application\n"
    "Name=%s\n"
    "Exec=%s\n"
    "Terminal=false\n"
    "X-GNOME-Autostart-enabled=true\n"
    "X-Lepusa-OpenHidden=%s\n",
    name,
    command,
    open_hidden ? "true" : "false"
  );
  int ok = lepusa_auto_launch_write_file(path, desktop);
  free(config);
  free(dir);
  free(path);
  free(command);
  free(desktop);
  return ok ? 0 : 1;
}
#endif

#if defined(_WIN32)
static char *lepusa_auto_launch_windows_command(
  const char *executable,
  const char *arguments
) {
  size_t len = strlen(executable) + strlen(arguments == NULL ? "" : arguments) +
    64;
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  strcpy(out, "\"");
  strcat(out, executable);
  strcat(out, "\"");
  for (const char *start = arguments == NULL ? "" : arguments; *start != '\0';) {
    const char *end = strchr(start, '\n');
    size_t part_len = end == NULL ? strlen(start) : (size_t)(end - start);
    if (part_len > 0) {
      strcat(out, " ");
      strncat(out, start, part_len);
    }
    if (end == NULL) {
      break;
    }
    start = end + 1;
  }
  return out;
}
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_auto_launch_available(void) {
#if defined(__APPLE__) || defined(__linux__) || defined(_WIN32)
  return 1;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_auto_launch_status(moonbit_bytes_t name) {
  char *name_text = lepusa_auto_launch_cstr_from_bytes(name);
  if (name_text == NULL || name_text[0] == '\0') {
    free(name_text);
    return 1;
  }
#if defined(__APPLE__)
  char *path = lepusa_auto_launch_macos_path(name_text);
  int32_t result = path == NULL ? 2 : (lepusa_auto_launch_file_exists(path) ? 1 : 0);
  free(path);
#elif defined(__linux__)
  char *path = lepusa_auto_launch_linux_path(name_text);
  int32_t result = path == NULL ? 2 : (lepusa_auto_launch_file_exists(path) ? 1 : 0);
  free(path);
#elif defined(_WIN32)
  HKEY key = NULL;
  LONG opened = RegOpenKeyExA(
    HKEY_CURRENT_USER,
    "Software\\Microsoft\\Windows\\CurrentVersion\\Run",
    0,
    KEY_QUERY_VALUE,
    &key
  );
  int32_t result = 0;
  if (opened == ERROR_SUCCESS) {
    result = RegQueryValueExA(key, name_text, NULL, NULL, NULL, NULL) ==
      ERROR_SUCCESS ? 1 : 0;
    RegCloseKey(key);
  }
#else
  int32_t result = 2;
#endif
  free(name_text);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_auto_launch_set(
  moonbit_bytes_t name,
  moonbit_bytes_t executable,
  moonbit_bytes_t arguments,
  int32_t open_hidden,
  int32_t enabled
) {
  char *name_text = lepusa_auto_launch_cstr_from_bytes(name);
  char *executable_text = lepusa_auto_launch_cstr_from_bytes(executable);
  char *arguments_text = lepusa_auto_launch_cstr_from_bytes(arguments);
  if (name_text == NULL || name_text[0] == '\0' || arguments_text == NULL) {
    free(name_text);
    free(executable_text);
    free(arguments_text);
    return 1;
  }
  if (enabled && (executable_text == NULL || executable_text[0] == '\0')) {
    free(name_text);
    free(executable_text);
    free(arguments_text);
    return 1;
  }
#if defined(__APPLE__)
  char *path = lepusa_auto_launch_macos_path(name_text);
  int32_t result = enabled
    ? lepusa_auto_launch_macos_enable(name_text, executable_text, arguments_text)
    : (path == NULL || remove(path) == 0 || errno == ENOENT ? 0 : 1);
  free(path);
#elif defined(__linux__)
  char *path = lepusa_auto_launch_linux_path(name_text);
  int32_t result = enabled
    ? lepusa_auto_launch_linux_enable(
        name_text,
        executable_text,
        arguments_text,
        open_hidden != 0
      )
    : (path == NULL || remove(path) == 0 || errno == ENOENT ? 0 : 1);
  free(path);
#elif defined(_WIN32)
  HKEY key = NULL;
  LONG opened = RegCreateKeyExA(
    HKEY_CURRENT_USER,
    "Software\\Microsoft\\Windows\\CurrentVersion\\Run",
    0,
    NULL,
    0,
    KEY_SET_VALUE,
    NULL,
    &key,
    NULL
  );
  int32_t result = 1;
  if (opened == ERROR_SUCCESS) {
    if (enabled) {
      char *command = lepusa_auto_launch_windows_command(
        executable_text,
        arguments_text
      );
      if (command != NULL) {
        result = RegSetValueExA(
          key,
          name_text,
          0,
          REG_SZ,
          (const BYTE *)command,
          (DWORD)(strlen(command) + 1)
        ) == ERROR_SUCCESS ? 0 : 1;
        free(command);
      }
    } else {
      LONG deleted = RegDeleteValueA(key, name_text);
      result = deleted == ERROR_SUCCESS || deleted == ERROR_FILE_NOT_FOUND ? 0 : 1;
    }
    RegCloseKey(key);
  }
#else
  int32_t result = 2;
#endif
  free(name_text);
  free(executable_text);
  free(arguments_text);
  return result;
}
