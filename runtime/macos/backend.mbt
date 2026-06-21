///|
extern "c" fn backend_available() -> Int = "lepusa_macos_backend_available"

///|
extern "c" fn backend_engine_name() -> Bytes = "lepusa_macos_backend_engine_name"

///|
pub fn backend() -> @runtime.NativeBackend {
  @runtime.NativeBackend::new(
    name="macos",
    webview_engine=@utf8.decode_lossy(backend_engine_name()),
  )
}

///|
pub fn available() -> Bool {
  backend_available() == 1
}

///|
pub fn detect() -> Result[@runtime.NativeBackend, String] {
  if available() {
    Ok(backend())
  } else {
    Err("macOS Cocoa/WebKit backend is not available")
  }
}

///|
pub fn launch_capability() -> @runtime.NativeLaunchCapability {
  @runtime.NativeLaunchCapability::new(
    webview_creation=true,
    sync_bridge_evaluate=true,
    async_bridge_drain=true,
    max_webviews=0,
    webview_creation_message="macOS WKWebView creation loop is unavailable",
    sync_bridge_evaluate_message="macOS WKWebView sync bridge response evaluation is unavailable",
    async_bridge_drain_message="macOS WKWebView async bridge drain uses packetized event-loop requests",
  )
}

///|
pub fn preflight() -> @runtime.NativeBackendPreflight {
  @runtime.NativeBackendPreflight::new(
    platform="macos",
    webview_engine="WKWebView",
    dependency_name="wkwebview",
    dependency_available=available(),
    webview_creation_loop=true,
    sync_bridge_evaluate=true,
    async_bridge_drain=true,
    dependency_message="macOS Cocoa/WebKit backend is not available",
    webview_creation_message="macOS WKWebView creation loop is unavailable",
    sync_bridge_evaluate_message="macOS WKWebView sync bridge response evaluation is unavailable",
    async_bridge_drain_message="macOS WKWebView async bridge drain uses packetized event-loop requests",
  )
}

///|
pub fn operation_executor() -> @runtime.NativeOperationExecutor {
  @runtime.NativeOperationExecutor::new(
    open_window=fn(_) { NativeOperationExecuted },
    evaluate_script=fn(_) { NativeOperationExecuted },
    close_window=fn(_) { NativeOperationExecuted },
    navigate_window=fn(_) { NativeOperationExecuted },
    run_effect=fn(name) {
      NativeOperationSkipped("macOS native effect is not registered: \{name}")
    },
    control_window=fn(_) { NativeOperationExecuted },
    desktop_shell=fn(operation) {
      @runtime.native_desktop_shell_platform_status(
        operation,
        platform_name="macOS",
      )
    },
  )
}

///|
pub fn runtime(
  host : @runtime.RuntimeHost,
) -> Result[@runtime.NativeRuntime, Array[String]] {
  @runtime.NativeRuntime::new(backend(), host)
}

///|
pub fn detect_runtime(
  host : @runtime.RuntimeHost,
) -> Result[@runtime.NativeRuntime, Array[String]] {
  match detect() {
    Ok(backend) => @runtime.NativeRuntime::new(backend, host)
    Err(problem) => Err([problem])
  }
}
