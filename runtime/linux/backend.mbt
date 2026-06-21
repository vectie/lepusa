///|
extern "c" fn backend_available() -> Int = "lepusa_linux_backend_available"

///|
extern "c" fn backend_engine_name() -> Bytes = "lepusa_linux_backend_engine_name"

///|
pub fn backend() -> @runtime.NativeBackend {
  @runtime.NativeBackend::new(
    name="linux",
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
    Err("Linux WebKitGTK backend is not available")
  }
}

///|
pub fn launch_capability() -> @runtime.NativeLaunchCapability {
  @runtime.NativeLaunchCapability::new(
    webview_creation=true,
    sync_bridge_evaluate=true,
    async_bridge_drain=false,
    max_webviews=0,
    webview_creation_message="Linux WebKitGTK launch loop is unavailable",
    sync_bridge_evaluate_message="Linux WebKitGTK sync bridge response evaluation is unavailable",
    async_bridge_drain_message="Linux WebKitGTK async bridge drain/evaluate support needs an async MoonBit-to-native callback ABI",
  )
}

///|
pub fn preflight() -> @runtime.NativeBackendPreflight {
  @runtime.NativeBackendPreflight::new(
    platform="linux",
    webview_engine="WebKitGTK",
    dependency_name="webkitgtk",
    dependency_available=available(),
    webview_creation_loop=true,
    sync_bridge_evaluate=true,
    async_bridge_drain=false,
    dependency_message="Linux WebKitGTK backend is not available",
    webview_creation_message="Linux WebKitGTK launch loop is unavailable",
    sync_bridge_evaluate_message="Linux WebKitGTK sync bridge response evaluation is unavailable",
    async_bridge_drain_message="Linux WebKitGTK async bridge drain/evaluate support is unavailable",
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
      NativeOperationSkipped("Linux native effect is not registered: \{name}")
    },
    control_window=fn(_) { NativeOperationExecuted },
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
