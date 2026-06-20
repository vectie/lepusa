#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__) || defined(__linux__)
#include <spawn.h>
#include <unistd.h>
extern char **environ;
#endif

static char *lepusa_notification_cstr_from_bytes(moonbit_bytes_t bytes) {
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

#if defined(__APPLE__) || defined(__linux__)
static int32_t lepusa_notification_spawn(char *const argv[]) {
  pid_t pid = 0;
  int status = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
  return status == 0 ? 0 : 1;
}
#endif

#if defined(__APPLE__)
static char *lepusa_notification_applescript_escape(const char *text) {
  size_t len = 0;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    len += (*p == '"' || *p == '\\') ? 2 : 1;
  }
  char *escaped = (char *)malloc(len + 1);
  if (escaped == NULL) {
    return NULL;
  }
  size_t offset = 0;
  for (const char *p = text == NULL ? "" : text; *p != '\0'; p++) {
    if (*p == '"' || *p == '\\') {
      escaped[offset++] = '\\';
    }
    escaped[offset++] = *p;
  }
  escaped[offset] = '\0';
  return escaped;
}

static char *lepusa_notification_applescript(
  const char *title,
  const char *body
) {
  char *escaped_title = lepusa_notification_applescript_escape(title);
  char *escaped_body = lepusa_notification_applescript_escape(body);
  if (escaped_title == NULL || escaped_body == NULL) {
    free(escaped_title);
    free(escaped_body);
    return NULL;
  }
  const char *prefix = "display notification \"";
  const char *middle = "\" with title \"";
  const char *suffix = "\"";
  size_t len = strlen(prefix) +
    strlen(escaped_body) +
    strlen(middle) +
    strlen(escaped_title) +
    strlen(suffix);
  char *script = (char *)malloc(len + 1);
  if (script != NULL) {
    strcpy(script, prefix);
    strcat(script, escaped_body);
    strcat(script, middle);
    strcat(script, escaped_title);
    strcat(script, suffix);
  }
  free(escaped_title);
  free(escaped_body);
  return script;
}
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_notification_available(void) {
#if defined(__APPLE__)
  return access("/usr/bin/osascript", X_OK) == 0;
#elif defined(__linux__)
  return system("command -v notify-send >/dev/null 2>&1") == 0;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t lepusa_notification_show(
  moonbit_bytes_t title,
  moonbit_bytes_t body
) {
  char *title_text = lepusa_notification_cstr_from_bytes(title);
  char *body_text = lepusa_notification_cstr_from_bytes(body);
  if (title_text == NULL || body_text == NULL || title_text[0] == '\0') {
    free(title_text);
    free(body_text);
    return 1;
  }
  if (lepusa_notification_available() != 1) {
    free(title_text);
    free(body_text);
    return 2;
  }
#if defined(__APPLE__)
  char *script = lepusa_notification_applescript(title_text, body_text);
  if (script == NULL) {
    free(title_text);
    free(body_text);
    return 1;
  }
  char *argv[] = { "/usr/bin/osascript", "-e", script, NULL };
  int32_t result = lepusa_notification_spawn(argv);
  free(script);
#elif defined(__linux__)
  char *argv[] = { "notify-send", title_text, body_text, NULL };
  int32_t result = lepusa_notification_spawn(argv);
#else
  int32_t result = 2;
#endif
  free(title_text);
  free(body_text);
  return result;
}
