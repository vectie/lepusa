///|
fn BundlePlan::platform_files(self : BundlePlan) -> Array[BundleFile] {
  match self.target {
    MacOS =>
      [
        BundleFile::new(
          path="\{self.bundle_name}/Contents/Info.plist",
          content=self.info_plist(),
        ),
        BundleFile::new(
          path="\{self.bundle_name}/Contents/MacOS/\{self.executable_name}",
          content=macos_launcher(),
          executable=true,
        ),
      ]
    Windows =>
      [
        BundleFile::new(
          path="\{self.executable_name}/app.manifest.xml",
          content=self.windows_manifest(),
        ),
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}-launcher.c",
          content=self.windows_native_launcher_source(),
        ),
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}.cmd",
          content=windows_launcher(),
        ),
      ]
    Linux =>
      [
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}.desktop",
          content=self.desktop_entry(),
        ),
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}",
          content=linux_launcher(),
          executable=true,
        ),
      ]
  }
}

///|
fn BundlePlan::info_plist(self : BundlePlan) -> String {
  let identifier = self.identifier().xml_escape()
  let product = self.metadata.product_name().xml_escape()
  let version = self.metadata.version().xml_escape()
  let executable = self.executable_name.xml_escape()
  [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" ",
    "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
    "<plist version=\"1.0\"><dict>",
    "<key>CFBundleIdentifier</key><string>\{identifier}</string>",
    "<key>CFBundleName</key><string>\{product}</string>",
    "<key>CFBundleDisplayName</key><string>\{product}</string>",
    "<key>CFBundleExecutable</key><string>\{executable}</string>",
    "<key>CFBundleShortVersionString</key><string>\{version}</string>",
    "<key>CFBundleVersion</key><string>\{version}</string>",
    if self.icon_path is Some(_) {
      "<key>CFBundleIconFile</key><string>AppIcon</string>"
    } else {
      ""
    },
    "</dict></plist>\n",
  ].join("")
}

///|
fn BundlePlan::windows_manifest(self : BundlePlan) -> String {
  let identifier = self.identifier().xml_escape()
  let product = self.metadata.product_name().xml_escape()
  [
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
    "<assembly xmlns=\"urn:schemas-microsoft-com:asm.v1\" manifestVersion=\"1.0\">",
    "<assemblyIdentity version=\"1.0.0.0\" processorArchitecture=\"*\" ",
    "name=\"\{identifier}\" type=\"win32\"/>",
    "<description>\{product}</description>",
    "</assembly>\n",
  ].join("")
}

///|
fn BundlePlan::desktop_entry(self : BundlePlan) -> String {
  [
    "[Desktop Entry]",
    "Type=Application",
    "Name=\{self.metadata.product_name()}",
    "Exec=\{self.executable_name}",
    "Icon=\{self.executable_name}",
    "Categories=Utility;",
    "",
  ].join("\n")
}

///|
fn macos_launcher() -> String {
  (
    #|#!/bin/sh
    #|APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
    #|RUNTIME="$APP_DIR/MacOS/lepusa-runtime"
    #|if [ ! -x "$RUNTIME" ]; then
    #|  RUNTIME=lepusa-runtime
    #|fi
    #|cleanup() {
    #|  trap - INT TERM HUP
    #|  if [ -n "${RUNTIME_PID:-}" ]; then
    #|    kill -TERM "$RUNTIME_PID" 2>/dev/null || true
    #|  fi
    #|  exit 130
    #|}
    #|trap cleanup INT TERM HUP
    #|"$RUNTIME" launch --manifest "$APP_DIR/Resources/lepusa/runtime.json" "$@" &
    #|RUNTIME_PID=$!
    #|wait "$RUNTIME_PID"
    #|STATUS=$?
    #|trap - INT TERM HUP
    #|exit "$STATUS"
    #|
  )
}

///|
fn windows_launcher() -> String {
  (
    #|@echo off
    #|set "APP_DIR=%~dp0"
    #|set "RUNTIME=%APP_DIR%lepusa-runtime.exe"
    #|if not exist "%RUNTIME%" set "RUNTIME=lepusa-runtime.exe"
    #|"%RUNTIME%" launch --manifest "%APP_DIR%lepusa\runtime.json" %*
    #|
  )
}

///|
fn BundlePlan::windows_native_launcher_source(self : BundlePlan) -> String {
  let product = self.metadata.product_name().c_string_escape()
  (
    #|#define UNICODE
    #|#define _UNICODE
    #|#include <windows.h>
    #|#include <shellapi.h>
    #|#include <stdlib.h>
    #|#include <wchar.h>
    #|
    #|static wchar_t *lepusa_join_path(const wchar_t *left, const wchar_t *right) {
    #|  size_t left_len = wcslen(left);
    #|  size_t right_len = wcslen(right);
    #|  int needs_slash = left_len > 0 && left[left_len - 1] != L'\\';
    #|  wchar_t *out = (wchar_t *)calloc(left_len + right_len + (needs_slash ? 2 : 1), sizeof(wchar_t));
    #|  if (out == NULL) {
    #|    return NULL;
    #|  }
    #|  wcscpy(out, left);
    #|  if (needs_slash) {
    #|    wcscat(out, L"\\");
    #|  }
    #|  wcscat(out, right);
    #|  return out;
    #|}
    #|
    #|static wchar_t *lepusa_app_dir(void) {
    #|  DWORD cap = MAX_PATH;
    #|  for (;;) {
    #|    wchar_t *buffer = (wchar_t *)calloc(cap, sizeof(wchar_t));
    #|    if (buffer == NULL) {
    #|      return NULL;
    #|    }
    #|    DWORD len = GetModuleFileNameW(NULL, buffer, cap);
    #|    if (len == 0) {
    #|      free(buffer);
    #|      return NULL;
    #|    }
    #|    if (len < cap - 1) {
    #|      wchar_t *slash = wcsrchr(buffer, L'\\');
    #|      if (slash != NULL) {
    #|        *slash = L'\0';
    #|      }
    #|      return buffer;
    #|    }
    #|    free(buffer);
    #|    cap *= 2;
    #|  }
    #|}
    #|
    #|static int lepusa_file_exists(const wchar_t *path) {
    #|  DWORD attributes = GetFileAttributesW(path);
    #|  return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_DIRECTORY);
    #|}
    #|
    #|int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR command_line, int show_command) {
    #|  (void)instance;
    #|  (void)previous;
    #|  (void)show_command;
    #|  wchar_t *app_dir = lepusa_app_dir();
    #|  if (app_dir == NULL) {
    #|    MessageBoxW(NULL, L"Could not resolve application directory.", L"__LEPUSA_PRODUCT__", MB_ICONERROR);
    #|    return 1;
    #|  }
    #|  wchar_t *runtime = lepusa_join_path(app_dir, L"lepusa-runtime.exe");
    #|  wchar_t *manifest = lepusa_join_path(app_dir, L"lepusa\\runtime.json");
    #|  if (runtime == NULL || manifest == NULL) {
    #|    free(app_dir);
    #|    free(runtime);
    #|    free(manifest);
    #|    return 1;
    #|  }
    #|  const wchar_t *runtime_exe = lepusa_file_exists(runtime) ? runtime : L"lepusa-runtime.exe";
    #|  size_t command_len = wcslen(runtime_exe) + wcslen(manifest) + wcslen(command_line == NULL ? L"" : command_line) + 64;
    #|  wchar_t *command = (wchar_t *)calloc(command_len, sizeof(wchar_t));
    #|  if (command == NULL) {
    #|    free(app_dir);
    #|    free(runtime);
    #|    free(manifest);
    #|    return 1;
    #|  }
    #|  swprintf(command, command_len, L"\"%ls\" launch --manifest \"%ls\" %ls", runtime_exe, manifest, command_line == NULL ? L"" : command_line);
    #|  STARTUPINFOW startup;
    #|  PROCESS_INFORMATION process;
    #|  ZeroMemory(&startup, sizeof(startup));
    #|  ZeroMemory(&process, sizeof(process));
    #|  startup.cb = sizeof(startup);
    #|  BOOL created = CreateProcessW(NULL, command, NULL, NULL, FALSE, 0, NULL, app_dir, &startup, &process);
    #|  if (!created) {
    #|    MessageBoxW(NULL, L"Could not start lepusa-runtime.exe.", L"__LEPUSA_PRODUCT__", MB_ICONERROR);
    #|    free(app_dir);
    #|    free(runtime);
    #|    free(manifest);
    #|    free(command);
    #|    return 1;
    #|  }
    #|  WaitForSingleObject(process.hProcess, INFINITE);
    #|  DWORD exit_code = 1;
    #|  GetExitCodeProcess(process.hProcess, &exit_code);
    #|  CloseHandle(process.hThread);
    #|  CloseHandle(process.hProcess);
    #|  free(app_dir);
    #|  free(runtime);
    #|  free(manifest);
    #|  free(command);
    #|  return (int)exit_code;
    #|}
    #|
  ).replace_all(old="__LEPUSA_PRODUCT__", new=product)
}

///|
fn linux_launcher() -> String {
  (
    #|#!/bin/sh
    #|APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    #|RUNTIME="$APP_DIR/lepusa-runtime"
    #|if [ ! -x "$RUNTIME" ]; then
    #|  RUNTIME=lepusa-runtime
    #|fi
    #|cleanup() {
    #|  trap - INT TERM HUP
    #|  if [ -n "${RUNTIME_PID:-}" ]; then
    #|    kill -TERM "$RUNTIME_PID" 2>/dev/null || true
    #|  fi
    #|  exit 130
    #|}
    #|trap cleanup INT TERM HUP
    #|"$RUNTIME" launch --manifest "$APP_DIR/lepusa/runtime.json" "$@" &
    #|RUNTIME_PID=$!
    #|wait "$RUNTIME_PID"
    #|STATUS=$?
    #|trap - INT TERM HUP
    #|exit "$STATUS"
    #|
  )
}

///|
fn String::xml_escape(self : String) -> String {
  self
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}

///|
fn String::c_string_escape(self : String) -> String {
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
}
