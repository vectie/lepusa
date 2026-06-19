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
