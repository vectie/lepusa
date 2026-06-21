///|
extern "c" fn backend_available() -> Int = "lepusa_windows_backend_available"

///|
extern "c" fn backend_engine_name() -> Bytes = "lepusa_windows_backend_engine_name"

///|
pub fn backend() -> @runtime.NativeBackend {
  @runtime.NativeBackend::new(
    name="windows",
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
    Err("Windows WebView2 backend is not available")
  }
}

///|
pub fn launch_capability() -> @runtime.NativeLaunchCapability {
  let preflight = preflight()
  @runtime.NativeLaunchCapability::new(
    webview_creation=preflight.can_launch(),
    sync_bridge_evaluate=preflight.can_launch() &&
      preflight.sync_bridge_evaluate(),
    async_bridge_drain=preflight.async_bridge_drain(),
    max_webviews=0,
    webview_creation_message=preflight.problem(),
    sync_bridge_evaluate_message="Windows WebView2 sync bridge response evaluation requires the WebView2 launch loop",
    async_bridge_drain_message="Windows WebView2 async bridge drain uses packetized event-loop requests",
  )
}

///|
pub fn preflight() -> @runtime.NativeBackendPreflight {
  @runtime.NativeBackendPreflight::new(
    platform="windows",
    webview_engine="WebView2",
    dependency_name="webview2-loader",
    dependency_available=available(),
    webview_creation_loop=true,
    sync_bridge_evaluate=true,
    async_bridge_drain=true,
    dependency_message="Windows WebView2 loader or runtime is not available",
    webview_creation_message="Windows WebView2 creation loop requires WebView2Loader.dll and the WebView2 Runtime",
    sync_bridge_evaluate_message="Windows WebView2 sync bridge response evaluation requires the WebView2 launch loop",
    async_bridge_drain_message="Windows WebView2 async bridge drain uses packetized event-loop requests",
  )
}

///|
pub fn operation_executor() -> @runtime.NativeOperationExecutor {
  @runtime.NativeOperationExecutor::new(
    open_window=fn(_) { NativeOperationExecuted },
    close_window=fn(_) { NativeOperationExecuted },
    evaluate_script=fn(_) { NativeOperationExecuted },
    drain_bridge=fn(_) { NativeOperationExecuted },
    navigate_window=fn(_) { NativeOperationExecuted },
    control_window=fn(_) { NativeOperationExecuted },
    run_effect=fn(name) {
      NativeOperationSkipped("Windows native effect is not registered: \{name}")
    },
    desktop_shell=fn(operation) {
      if operation.domain() == "menu" &&
        (
          operation.action() == "setAppMenu" ||
          operation.action() == "clearAppMenu" ||
          operation.action() == "setWindowMenu" ||
          operation.action() == "clearWindowMenu"
        ) {
        NativeOperationExecuted
      } else if operation.domain() == "tray" &&
        (
          operation.action() == "setIcon" ||
          operation.action() == "setTooltip" ||
          operation.action() == "setMenu" ||
          operation.action() == "showMenu" ||
          operation.action() == "setVisible" ||
          operation.action() == "destroy"
        ) {
        NativeOperationExecuted
      } else {
        @runtime.native_desktop_shell_platform_status(
          operation,
          platform_name="Windows",
        )
      }
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
