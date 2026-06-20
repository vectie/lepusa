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
