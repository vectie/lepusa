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
#include <io.h>
#endif

static moonbit_bytes_t lepusa_file_dialog_packet(
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

static moonbit_bytes_t lepusa_file_dialog_packet_text(
  const char *status,
  const char *body
) {
  return lepusa_file_dialog_packet(status, body, strlen(body));
}

static char *lepusa_file_dialog_cstr_from_bytes(moonbit_bytes_t bytes) {
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

static char *lepusa_file_dialog_json_escape(const char *text) {
  size_t len = 2;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    unsigned char ch = (unsigned char)*p;
    if (ch == '"' || ch == '\\') {
      len += 2;
    } else if (ch == '\n' || ch == '\r' || ch == '\t') {
      len += 2;
    } else {
      len += 1;
    }
  }
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  out[offset++] = '"';
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    switch (*p) {
      case '"': out[offset++] = '\\'; out[offset++] = '"'; break;
      case '\\': out[offset++] = '\\'; out[offset++] = '\\'; break;
      case '\n': out[offset++] = '\\'; out[offset++] = 'n'; break;
      case '\r': out[offset++] = '\\'; out[offset++] = 'r'; break;
      case '\t': out[offset++] = '\\'; out[offset++] = 't'; break;
      default: out[offset++] = *p; break;
    }
  }
  out[offset++] = '"';
  out[offset] = '\0';
  return out;
}

static char *lepusa_file_dialog_paths_json(const char *paths) {
  size_t capacity = strlen(paths == NULL ? "" : paths) * 2 + 8;
  char *out = (char *)malloc(capacity);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  out[offset++] = '[';
  const char *cursor = paths == NULL ? "" : paths;
  while (*cursor != '\0') {
    const char *line_end = strchr(cursor, '\n');
    size_t line_len = line_end == NULL ? strlen(cursor) : (size_t)(line_end - cursor);
    if (line_len > 0) {
      char *line = (char *)malloc(line_len + 1);
      if (line == NULL) {
        free(out);
        return NULL;
      }
      memcpy(line, cursor, line_len);
      line[line_len] = '\0';
      char *escaped = lepusa_file_dialog_json_escape(line);
      free(line);
      if (escaped == NULL) {
        free(out);
        return NULL;
      }
      size_t escaped_len = strlen(escaped);
      if (offset + escaped_len + 3 >= capacity) {
        capacity = (offset + escaped_len + 3) * 2;
        char *grown = (char *)realloc(out, capacity);
        if (grown == NULL) {
          free(escaped);
          free(out);
          return NULL;
        }
        out = grown;
      }
      if (offset > 1) {
        out[offset++] = ',';
      }
      memcpy(out + offset, escaped, escaped_len);
      offset += escaped_len;
      free(escaped);
    }
    if (line_end == NULL) {
      break;
    }
    cursor = line_end + 1;
  }
  out[offset++] = ']';
  out[offset] = '\0';
  return out;
}

static char *lepusa_file_dialog_selected_json(
  const char *action,
  const char *path,
  int multiple
) {
  char *action_json = lepusa_file_dialog_json_escape(action);
  char *path_json = multiple
    ? lepusa_file_dialog_paths_json(path)
    : lepusa_file_dialog_json_escape(path);
  if (action_json == NULL || path_json == NULL) {
    free(action_json);
    free(path_json);
    return NULL;
  }
  const char *template_single =
    "{\"action\":%s,\"status\":\"selected\",\"native\":true,"
    "\"cancelled\":false,\"path\":%s}";
  const char *template_multi =
    "{\"action\":%s,\"status\":\"selected\",\"native\":true,"
    "\"cancelled\":false,\"paths\":%s}";
  const char *template_text = multiple ? template_multi : template_single;
  int needed = snprintf(NULL, 0, template_text, action_json, path_json);
  if (needed < 0) {
    free(action_json);
    free(path_json);
    return NULL;
  }
  char *out = (char *)malloc((size_t)needed + 1);
  if (out != NULL) {
    snprintf(out, (size_t)needed + 1, template_text, action_json, path_json);
  }
  free(action_json);
  free(path_json);
  return out;
}

static char *lepusa_file_dialog_cancelled_json(const char *action) {
  char *action_json = lepusa_file_dialog_json_escape(action);
  if (action_json == NULL) {
    return NULL;
  }
  const char *template_text =
    "{\"action\":%s,\"status\":\"cancelled\",\"native\":true,"
    "\"cancelled\":true}";
  int needed = snprintf(NULL, 0, template_text, action_json);
  if (needed < 0) {
    free(action_json);
    return NULL;
  }
  char *out = (char *)malloc((size_t)needed + 1);
  if (out != NULL) {
    snprintf(out, (size_t)needed + 1, template_text, action_json);
  }
  free(action_json);
  return out;
}

static void lepusa_file_dialog_trim_newlines(char *text) {
  if (text == NULL) {
    return;
  }
  size_t len = strlen(text);
  while (len > 0 && (text[len - 1] == '\n' || text[len - 1] == '\r')) {
    text[--len] = '\0';
  }
}

#if defined(__APPLE__) || defined(__linux__)
static char *lepusa_file_dialog_shell_quote(const char *text) {
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

static char *lepusa_file_dialog_read_command(
  const char *command,
  int *exit_code_out
) {
  FILE *pipe = popen(command, "r");
  if (pipe == NULL) {
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  size_t capacity = 4096;
  size_t len = 0;
  char *buffer = (char *)malloc(capacity);
  if (buffer == NULL) {
    pclose(pipe);
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  for (;;) {
    if (len + 1 >= capacity) {
      capacity *= 2;
      char *grown = (char *)realloc(buffer, capacity);
      if (grown == NULL) {
        free(buffer);
        pclose(pipe);
        if (exit_code_out != NULL) {
          *exit_code_out = 1;
        }
        return NULL;
      }
      buffer = grown;
    }
    size_t n = fread(buffer + len, 1, capacity - len - 1, pipe);
    len += n;
    if (n == 0) {
      break;
    }
  }
  buffer[len] = '\0';
  int status = pclose(pipe);
  if (exit_code_out != NULL) {
    *exit_code_out = status;
  }
  return buffer;
}
#endif

#if defined(__APPLE__)
static char *lepusa_file_dialog_applescript_quote(const char *text) {
  size_t len = 2;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    len += (*p == '"' || *p == '\\') ? 2 : 1;
  }
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  out[offset++] = '"';
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    if (*p == '"' || *p == '\\') {
      out[offset++] = '\\';
    }
    out[offset++] = *p;
  }
  out[offset++] = '"';
  out[offset] = '\0';
  return out;
}

static char *lepusa_file_dialog_macos_script(
  const char *action,
  const char *initial_path,
  const char *suggested_name
) {
  char *path = lepusa_file_dialog_applescript_quote(initial_path);
  char *name = lepusa_file_dialog_applescript_quote(suggested_name);
  if (path == NULL || name == NULL) {
    free(path);
    free(name);
    return NULL;
  }
  const char *default_location =
    initial_path != NULL && initial_path[0] != '\0'
      ? " default location POSIX file %s"
      : "%s";
  const char *template_text = NULL;
  if (strcmp(action, "openFiles") == 0) {
    template_text =
      "set chosen to choose file with multiple selections allowed%s\n"
      "set out to \"\"\n"
      "repeat with itemRef in chosen\n"
      "set out to out & POSIX path of itemRef & linefeed\n"
      "end repeat\n"
      "return out\n";
  } else if (strcmp(action, "openDirectory") == 0) {
    template_text = "return POSIX path of (choose folder%s)\n";
  } else if (strcmp(action, "saveFile") == 0) {
    template_text =
      "return POSIX path of (choose file name default name %s%s)\n";
  } else {
    template_text = "return POSIX path of (choose file%s)\n";
  }
  int needed = 0;
  char *location = NULL;
  if (initial_path != NULL && initial_path[0] != '\0') {
    needed = snprintf(NULL, 0, default_location, path);
    location = (char *)malloc((size_t)needed + 1);
    if (location != NULL) {
      snprintf(location, (size_t)needed + 1, default_location, path);
    }
  } else {
    location = (char *)malloc(1);
    if (location != NULL) {
      location[0] = '\0';
    }
  }
  if (location == NULL) {
    free(path);
    free(name);
    return NULL;
  }
  if (strcmp(action, "saveFile") == 0) {
    needed = snprintf(NULL, 0, template_text, name, location);
  } else {
    needed = snprintf(NULL, 0, template_text, location);
  }
  char *script = needed < 0 ? NULL : (char *)malloc((size_t)needed + 1);
  if (script != NULL) {
    if (strcmp(action, "saveFile") == 0) {
      snprintf(script, (size_t)needed + 1, template_text, name, location);
    } else {
      snprintf(script, (size_t)needed + 1, template_text, location);
    }
  }
  free(location);
  free(path);
  free(name);
  return script;
}

static char *lepusa_file_dialog_macos_pick(
  const char *action,
  const char *initial_path,
  const char *suggested_name,
  int *exit_code_out
) {
  char template_path[] = "/tmp/lepusa-file-dialog-XXXXXX";
  int fd = mkstemp(template_path);
  if (fd < 0) {
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  char *script = lepusa_file_dialog_macos_script(
    action,
    initial_path,
    suggested_name
  );
  if (script == NULL) {
    close(fd);
    unlink(template_path);
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  FILE *file = fdopen(fd, "w");
  if (file == NULL) {
    close(fd);
    unlink(template_path);
    free(script);
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  fputs(script, file);
  fclose(file);
  free(script);
  char *quoted_path = lepusa_file_dialog_shell_quote(template_path);
  if (quoted_path == NULL) {
    unlink(template_path);
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  int needed = snprintf(NULL, 0, "/usr/bin/osascript %s", quoted_path);
  char *command = needed < 0 ? NULL : (char *)malloc((size_t)needed + 1);
  if (command != NULL) {
    snprintf(command, (size_t)needed + 1, "/usr/bin/osascript %s", quoted_path);
  }
  free(quoted_path);
  char *out = command == NULL
    ? NULL
    : lepusa_file_dialog_read_command(command, exit_code_out);
  free(command);
  unlink(template_path);
  return out;
}
#endif

#if defined(__linux__)
static char *lepusa_file_dialog_linux_command(
  const char *action,
  const char *initial_path,
  const char *suggested_name
) {
  char *filename = NULL;
  const char *seed = strcmp(action, "saveFile") == 0 &&
    suggested_name != NULL &&
    suggested_name[0] != '\0'
      ? suggested_name
      : initial_path;
  if (seed != NULL && seed[0] != '\0') {
    filename = lepusa_file_dialog_shell_quote(seed);
    if (filename == NULL) {
      return NULL;
    }
  }
  const char *mode = "";
  if (strcmp(action, "openFiles") == 0) {
    mode = " --multiple --separator='\\n'";
  } else if (strcmp(action, "openDirectory") == 0) {
    mode = " --directory";
  } else if (strcmp(action, "saveFile") == 0) {
    mode = " --save --confirm-overwrite";
  }
  const char *template_text = filename == NULL
    ? "zenity --file-selection%s"
    : "zenity --file-selection%s --filename=%s";
  int needed = filename == NULL
    ? snprintf(NULL, 0, template_text, mode)
    : snprintf(NULL, 0, template_text, mode, filename);
  char *command = needed < 0 ? NULL : (char *)malloc((size_t)needed + 1);
  if (command != NULL) {
    if (filename == NULL) {
      snprintf(command, (size_t)needed + 1, template_text, mode);
    } else {
      snprintf(command, (size_t)needed + 1, template_text, mode, filename);
    }
  }
  free(filename);
  return command;
}
#endif

#if defined(_WIN32)
static char *lepusa_file_dialog_read_command_windows(
  const char *command,
  int *exit_code_out
) {
  FILE *pipe = _popen(command, "r");
  if (pipe == NULL) {
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  size_t capacity = 4096;
  size_t len = 0;
  char *buffer = (char *)malloc(capacity);
  if (buffer == NULL) {
    _pclose(pipe);
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  for (;;) {
    if (len + 1 >= capacity) {
      capacity *= 2;
      char *grown = (char *)realloc(buffer, capacity);
      if (grown == NULL) {
        free(buffer);
        _pclose(pipe);
        if (exit_code_out != NULL) {
          *exit_code_out = 1;
        }
        return NULL;
      }
      buffer = grown;
    }
    size_t n = fread(buffer + len, 1, capacity - len - 1, pipe);
    len += n;
    if (n == 0) {
      break;
    }
  }
  buffer[len] = '\0';
  int status = _pclose(pipe);
  if (exit_code_out != NULL) {
    *exit_code_out = status;
  }
  return buffer;
}

static char *lepusa_file_dialog_powershell_quote(const char *text) {
  size_t len = 2;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    len += *p == '\'' ? 2 : 1;
  }
  char *out = (char *)malloc(len + 1);
  if (out == NULL) {
    return NULL;
  }
  size_t offset = 0;
  out[offset++] = '\'';
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    if (*p == '\'') {
      out[offset++] = '\'';
    }
    out[offset++] = *p;
  }
  out[offset++] = '\'';
  out[offset] = '\0';
  return out;
}

static char *lepusa_file_dialog_windows_script(
  const char *action,
  const char *initial_path,
  const char *suggested_name
) {
  char *path = lepusa_file_dialog_powershell_quote(initial_path);
  char *name = lepusa_file_dialog_powershell_quote(suggested_name);
  if (path == NULL || name == NULL) {
    free(path);
    free(name);
    return NULL;
  }
  const char *template_text = NULL;
  if (strcmp(action, "openDirectory") == 0) {
    template_text =
      "Add-Type -AssemblyName System.Windows.Forms\n"
      "$d = New-Object System.Windows.Forms.FolderBrowserDialog\n"
      "if (%s -ne '') { $d.SelectedPath = %s }\n"
      "if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) "
      "{ Write-Output $d.SelectedPath } else { exit 10 }\n";
  } else if (strcmp(action, "saveFile") == 0) {
    template_text =
      "Add-Type -AssemblyName System.Windows.Forms\n"
      "$d = New-Object System.Windows.Forms.SaveFileDialog\n"
      "if (%s -ne '') { $d.InitialDirectory = %s }\n"
      "if (%s -ne '') { $d.FileName = %s }\n"
      "if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) "
      "{ Write-Output $d.FileName } else { exit 10 }\n";
  } else {
    template_text =
      "Add-Type -AssemblyName System.Windows.Forms\n"
      "$d = New-Object System.Windows.Forms.OpenFileDialog\n"
      "if (%s -ne '') { $d.InitialDirectory = %s }\n"
      "$d.Multiselect = %s\n"
      "if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) "
      "{ Write-Output ($d.FileNames -join \"`n\") } else { exit 10 }\n";
  }
  int needed = 0;
  if (strcmp(action, "saveFile") == 0) {
    needed = snprintf(NULL, 0, template_text, path, path, name, name);
  } else if (strcmp(action, "openDirectory") == 0) {
    needed = snprintf(NULL, 0, template_text, path, path);
  } else {
    needed = snprintf(
      NULL,
      0,
      template_text,
      path,
      path,
      strcmp(action, "openFiles") == 0 ? "$true" : "$false"
    );
  }
  char *script = needed < 0 ? NULL : (char *)malloc((size_t)needed + 1);
  if (script != NULL) {
    if (strcmp(action, "saveFile") == 0) {
      snprintf(script, (size_t)needed + 1, template_text, path, path, name, name);
    } else if (strcmp(action, "openDirectory") == 0) {
      snprintf(script, (size_t)needed + 1, template_text, path, path);
    } else {
      snprintf(
        script,
        (size_t)needed + 1,
        template_text,
        path,
        path,
        strcmp(action, "openFiles") == 0 ? "$true" : "$false"
      );
    }
  }
  free(path);
  free(name);
  return script;
}

static char *lepusa_file_dialog_windows_pick(
  const char *action,
  const char *initial_path,
  const char *suggested_name,
  int *exit_code_out
) {
  char temp_dir[MAX_PATH];
  char temp_path[MAX_PATH];
  if (GetTempPathA(MAX_PATH, temp_dir) == 0 ||
      GetTempFileNameA(temp_dir, "lfg", 0, temp_path) == 0) {
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  char *script = lepusa_file_dialog_windows_script(
    action,
    initial_path,
    suggested_name
  );
  FILE *file = script == NULL ? NULL : fopen(temp_path, "w");
  if (script == NULL || file == NULL) {
    free(script);
    DeleteFileA(temp_path);
    if (exit_code_out != NULL) {
      *exit_code_out = 1;
    }
    return NULL;
  }
  fputs(script, file);
  fclose(file);
  free(script);
  int needed = snprintf(
    NULL,
    0,
    "powershell -NoProfile -STA -ExecutionPolicy Bypass -File \"%s\"",
    temp_path
  );
  char *command = needed < 0 ? NULL : (char *)malloc((size_t)needed + 1);
  if (command != NULL) {
    snprintf(
      command,
      (size_t)needed + 1,
      "powershell -NoProfile -STA -ExecutionPolicy Bypass -File \"%s\"",
      temp_path
    );
  }
  char *out = command == NULL
    ? NULL
    : lepusa_file_dialog_read_command_windows(command, exit_code_out);
  free(command);
  DeleteFileA(temp_path);
  return out;
}
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_file_dialog_available(void) {
#if defined(__APPLE__)
  return access("/usr/bin/osascript", X_OK) == 0;
#elif defined(__linux__)
  return system("command -v zenity >/dev/null 2>&1") == 0;
#elif defined(_WIN32)
  return SearchPathA(NULL, "powershell.exe", NULL, 0, NULL, NULL) > 0;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepusa_file_dialog_pick(
  moonbit_bytes_t action,
  moonbit_bytes_t initial_path,
  moonbit_bytes_t suggested_name
) {
  char *action_text = lepusa_file_dialog_cstr_from_bytes(action);
  char *initial_text = lepusa_file_dialog_cstr_from_bytes(initial_path);
  char *suggested_text = lepusa_file_dialog_cstr_from_bytes(suggested_name);
  if (action_text == NULL || action_text[0] == '\0') {
    free(action_text);
    free(initial_text);
    free(suggested_text);
    return lepusa_file_dialog_packet_text(
      "err",
      "native file dialog action is required"
    );
  }
  if (lepusa_file_dialog_available() != 1) {
    free(action_text);
    free(initial_text);
    free(suggested_text);
    return lepusa_file_dialog_packet_text(
      "err",
      "native file dialog is unavailable"
    );
  }
  int exit_code = 1;
  char *selection = NULL;
#if defined(__APPLE__)
  selection = lepusa_file_dialog_macos_pick(
    action_text,
    initial_text == NULL ? "" : initial_text,
    suggested_text == NULL || suggested_text[0] == '\0'
      ? "untitled"
      : suggested_text,
    &exit_code
  );
#elif defined(__linux__)
  char *command = lepusa_file_dialog_linux_command(
    action_text,
    initial_text == NULL ? "" : initial_text,
    suggested_text == NULL ? "" : suggested_text
  );
  selection = command == NULL
    ? NULL
    : lepusa_file_dialog_read_command(command, &exit_code);
  free(command);
#elif defined(_WIN32)
  selection = lepusa_file_dialog_windows_pick(
    action_text,
    initial_text == NULL ? "" : initial_text,
    suggested_text == NULL || suggested_text[0] == '\0'
      ? "untitled"
      : suggested_text,
    &exit_code
  );
#else
  (void)initial_text;
  (void)suggested_text;
  exit_code = 2;
#endif
  moonbit_bytes_t packet = NULL;
  if (selection != NULL && exit_code == 0) {
    lepusa_file_dialog_trim_newlines(selection);
    char *json = lepusa_file_dialog_selected_json(
      action_text,
      selection,
      strcmp(action_text, "openFiles") == 0
    );
    packet = json == NULL
      ? lepusa_file_dialog_packet_text(
          "err",
          "native file dialog allocation failed"
        )
      : lepusa_file_dialog_packet("ok", json, strlen(json));
    free(json);
  } else if (exit_code != 1) {
    char *json = lepusa_file_dialog_cancelled_json(action_text);
    packet = json == NULL
      ? lepusa_file_dialog_packet_text(
          "err",
          "native file dialog allocation failed"
        )
      : lepusa_file_dialog_packet("ok", json, strlen(json));
    free(json);
  } else {
    packet = lepusa_file_dialog_packet_text(
      "err",
      "native file dialog failed"
    );
  }
  free(selection);
  free(action_text);
  free(initial_text);
  free(suggested_text);
  return packet;
}
