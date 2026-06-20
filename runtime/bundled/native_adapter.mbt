///|
pub fn BundledRuntimeManifest::initial_load_url(
  self : BundledRuntimeManifest,
  webview : BundledWebView,
) -> Result[String, String] {
  if @runtime.native_protocol_load_url(webview.url(), self.asset_protocol()) ||
    @runtime.native_direct_load_url(webview.url()) {
    Ok(webview.url())
  } else {
    @runtime.native_asset_load_url_from_json(
      self.resolve_asset_json(webview.url()),
    )
  }
}

///|
pub fn BundledRuntimeManifest::resolve_asset_protocol_packet_bytes(
  self : BundledRuntimeManifest,
  url : Bytes,
) -> Bytes {
  let input = @utf8.decode(url) catch { _ => "" }
  @runtime.native_asset_protocol_packet_from_json(
    self.resolve_asset_json(input),
  )
}

///|
pub fn BundledRuntimeManifest::bridge_dispatch_callback(
  self : BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  let runtime = BundledRuntime::new(self)
  fn(message : Bytes) { runtime.dispatch_bridge_script_bytes(message) }
}

///|
pub fn BundledRuntimeManifest::bridge_async_dispatch_callback(
  self : BundledRuntimeManifest,
) -> async (Bytes) -> Bytes {
  let runtime = BundledRuntime::new(self)
  message => runtime.dispatch_bridge_script_bytes_async(message)
}

///|
pub fn BundledRuntimeManifest::bridge_handoff_callback(
  self : BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  let runtime = BundledRuntime::new(self)
  fn(message : Bytes) { runtime.bridge_handoff_script_bytes(message) }
}

///|
pub fn BundledRuntimeManifest::bridge_scheduler(
  self : BundledRuntimeManifest,
  mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> @runtime.NativeBridgeScheduler {
  @runtime.NativeBridgeScheduler::new(
    sync_routes=self.registered_sync_routes(),
    async_routes=self.registered_async_routes(),
    mode~,
  )
}

///|
pub fn BundledRuntimeManifest::asset_protocol_resolver_callback(
  self : BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) { self.resolve_asset_protocol_packet_bytes(url) }
}

///|
pub fn BundledRuntimeManifest::webview_plan(
  self : BundledRuntimeManifest,
  webview : BundledWebView,
  initialization_script~ : String,
) -> Result[@runtime.NativeWebViewPlan, String] {
  match self.initial_load_url(webview) {
    Err(problem) => Err(problem)
    Ok(load_url) =>
      Ok(
        @runtime.NativeWebViewPlan::new(
          label=webview.label(),
          title=webview.title(),
          url=webview.url(),
          load_url~,
          initialization_script~,
          native_hook=webview.native_hook(),
          asset_protocol=self.asset_protocol(),
          width=webview.width(),
          height=webview.height(),
          resizable=webview.resizable(),
        ),
      )
  }
}
