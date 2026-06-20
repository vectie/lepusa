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
  preflight().launch_capability()
}

///|
pub fn preflight() -> @runtime.NativeBackendPreflight {
  @runtime.NativeBackendPreflight::new(
    platform="windows",
    webview_engine="WebView2",
    dependency_name="webview2-loader",
    dependency_available=available(),
    webview_creation_loop=false,
    sync_bridge_evaluate=false,
    async_bridge_drain=false,
    dependency_message="Windows WebView2 loader is not available",
    webview_creation_message="Windows WebView2 creation loop is unavailable",
    sync_bridge_evaluate_message="Windows WebView2 sync bridge response evaluation is unavailable",
    async_bridge_drain_message="Windows WebView2 async bridge drain/evaluate support is unavailable",
  )
}

///|
pub fn operation_executor() -> @runtime.NativeOperationExecutor {
  @runtime.NativeOperationExecutor::new(
    evaluate_script=fn(_) {
      NativeOperationSkipped(
        "Windows WebView2 script evaluation is unavailable until the creation loop lands",
      )
    },
    navigate_window=fn(_) {
      NativeOperationSkipped(
        "Windows native navigation is unavailable until the WebView2 creation loop lands",
      )
    },
    run_effect=fn(name) {
      NativeOperationSkipped("Windows native effect is not registered: \{name}")
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
