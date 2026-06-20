#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__) || defined(__linux__)
#include <spawn.h>
#include <sys/wait.h>
extern char **environ;
#endif

#if defined(_WIN32)
#include <shellapi.h>
#include <windows.h>
#endif

static char *lepusa_opener_cstr_from_bytes(moonbit_bytes_t bytes) {
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
static int32_t lepusa_opener_spawn(char *const argv[]) {
  pid_t pid = 0;
  int status = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
  if (status != 0) {
    return 1;
  }
  return 0;
}

static char *lepusa_opener_parent_dir(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return NULL;
  }
  const char *slash = strrchr(path, '/');
  if (slash == NULL) {
    char *dot = (char *)malloc(2);
    if (dot != NULL) {
      strcpy(dot, ".");
    }
    return dot;
  }
  size_t len = slash == path ? 1 : (size_t)(slash - path);
  char *dir = (char *)malloc(len + 1);
  if (dir == NULL) {
    return NULL;
  }
  memcpy(dir, path, len);
  dir[len] = '\0';
  return dir;
}
#endif

#if defined(_WIN32)
static int32_t lepusa_opener_shell_execute(
  const char *operation,
  const char *target,
  const char *parameters
) {
  HINSTANCE result = ShellExecuteA(
    NULL,
    operation,
    target,
    parameters,
    NULL,
    SW_SHOWNORMAL
  );
  return ((INT_PTR)result) > 32 ? 0 : 1;
}
#endif

MOONBIT_FFI_EXPORT
int32_t lepusa_opener_open_url(moonbit_bytes_t target) {
  char *value = lepusa_opener_cstr_from_bytes(target);
  if (value == NULL || value[0] == '\0') {
    free(value);
    return 1;
  }
#if defined(__APPLE__)
  char *argv[] = { "open", value, NULL };
  int32_t result = lepusa_opener_spawn(argv);
#elif defined(__linux__)
  char *argv[] = { "xdg-open", value, NULL };
  int32_t result = lepusa_opener_spawn(argv);
#elif defined(_WIN32)
  int32_t result = lepusa_opener_shell_execute("open", value, NULL);
#else
  int32_t result = 2;
#endif
  free(value);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_opener_open_path(moonbit_bytes_t target) {
  char *value = lepusa_opener_cstr_from_bytes(target);
  if (value == NULL || value[0] == '\0') {
    free(value);
    return 1;
  }
#if defined(__APPLE__)
  char *argv[] = { "open", value, NULL };
  int32_t result = lepusa_opener_spawn(argv);
#elif defined(__linux__)
  char *argv[] = { "xdg-open", value, NULL };
  int32_t result = lepusa_opener_spawn(argv);
#elif defined(_WIN32)
  int32_t result = lepusa_opener_shell_execute("open", value, NULL);
#else
  int32_t result = 2;
#endif
  free(value);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t lepusa_opener_reveal_path(moonbit_bytes_t target) {
  char *value = lepusa_opener_cstr_from_bytes(target);
  if (value == NULL || value[0] == '\0') {
    free(value);
    return 1;
  }
#if defined(__APPLE__)
  char *argv[] = { "open", "-R", value, NULL };
  int32_t result = lepusa_opener_spawn(argv);
#elif defined(__linux__)
  char *dir = lepusa_opener_parent_dir(value);
  if (dir == NULL) {
    free(value);
    return 1;
  }
  char *argv[] = { "xdg-open", dir, NULL };
  int32_t result = lepusa_opener_spawn(argv);
  free(dir);
#elif defined(_WIN32)
  char *parameters = (char *)malloc(strlen(value) + 12);
  if (parameters == NULL) {
    free(value);
    return 1;
  }
  strcpy(parameters, "/select,\"");
  strcat(parameters, value);
  strcat(parameters, "\"");
  int32_t result = lepusa_opener_shell_execute("open", "explorer.exe", parameters);
  free(parameters);
#else
  int32_t result = 2;
#endif
  free(value);
  return result;
}
