///|
pub struct BundledWebView {
  label : String
  title : String
  url : String
  width : Int
  height : Int
  resizable : Bool
  title_bar : String
  devtools : Bool
  asset_protocol : String
  bridge_global_name : String
  native_hook : String
  event_dispatch_hook : String
  allowed_routes : Array[String]
  initialization_scripts : Array[String]
} derive(Debug, Eq)

///|
pub fn BundledRuntimeManifest::first_webview(
  self : BundledRuntimeManifest,
) -> Result[BundledWebView, String] {
  match self.webviews() {
    Ok(webviews) =>
      match webviews.get(0) {
        Some(webview) => Ok(webview)
        None => Err("runtime webviews must include at least one window")
      }
    Err(problem) => Err(problem)
  }
}

///|
pub fn BundledRuntimeManifest::webviews(
  self : BundledRuntimeManifest,
) -> Result[Array[BundledWebView], String] {
  let parsed : Array[BundledWebView] = []
  let values = optional_array(self.runtime, "webviews").unwrap_or([])
  if values.is_empty() {
    return Err("runtime webviews must include at least one window")
  }
  for value in values {
    match value {
      Object(webview) =>
        match self.parse_webview(webview) {
          Ok(parsed_webview) => parsed.push(parsed_webview)
          Err(problem) => return Err(problem)
        }
      _ => return Err("runtime webview must be a json object")
    }
  }
  Ok(parsed)
}

///|
fn BundledRuntimeManifest::parse_webview(
  self : BundledRuntimeManifest,
  webview : Map[String, Json],
) -> Result[BundledWebView, String] {
  match optional_string(webview, "url") {
    Some(url) if url != "" =>
      Ok({
        label: optional_string(webview, "label").unwrap_or("main"),
        title: optional_string(webview, "title").unwrap_or(
          optional_string(self.bundle, "productName").unwrap_or("Lepusa"),
        ),
        url,
        width: optional_int(webview, "width").unwrap_or(1000),
        height: optional_int(webview, "height").unwrap_or(720),
        resizable: optional_bool(webview, "resizable").unwrap_or(true),
        title_bar: optional_string(webview, "titleBar").unwrap_or("native"),
        devtools: optional_bool(webview, "devtools").unwrap_or(
          optional_bool(self.runtime, "devtools").unwrap_or(false),
        ),
        asset_protocol: optional_string(webview, "assetProtocol").unwrap_or(
          self.asset_protocol(),
        ),
        bridge_global_name: optional_string(webview, "bridgeGlobalName").unwrap_or(
          "lepusa",
        ),
        native_hook: optional_string(webview, "nativeHook").unwrap_or(
          "__lepusaInvoke",
        ),
        event_dispatch_hook: optional_string(webview, "eventDispatchHook").unwrap_or(
          "__lepusaDispatchEvent",
        ),
        allowed_routes: strings_from_json_array(
          optional_array(webview, "allowedRoutes").unwrap_or([]),
        ),
        initialization_scripts: optional_string_array(
          webview, "initializationScripts",
        ),
      })
    _ => Err("runtime webview url is required")
  }
}

///|
pub fn BundledRuntimeManifest::webview_count(
  self : BundledRuntimeManifest,
) -> Int {
  optional_array(self.runtime, "webviews").unwrap_or([]).length()
}

///|
pub fn BundledWebView::label(self : BundledWebView) -> String {
  self.label
}

///|
pub fn BundledWebView::title(self : BundledWebView) -> String {
  self.title
}

///|
pub fn BundledWebView::url(self : BundledWebView) -> String {
  self.url
}

///|
pub fn BundledWebView::width(self : BundledWebView) -> Int {
  self.width
}

///|
pub fn BundledWebView::height(self : BundledWebView) -> Int {
  self.height
}

///|
pub fn BundledWebView::resizable(self : BundledWebView) -> Bool {
  self.resizable
}

///|
pub fn BundledWebView::title_bar(self : BundledWebView) -> String {
  self.title_bar
}

///|
pub fn BundledWebView::devtools(self : BundledWebView) -> Bool {
  self.devtools
}

///|
pub fn BundledWebView::asset_protocol(self : BundledWebView) -> String {
  self.asset_protocol
}

///|
pub fn BundledWebView::bridge_global_name(self : BundledWebView) -> String {
  self.bridge_global_name
}

///|
pub fn BundledWebView::native_hook(self : BundledWebView) -> String {
  self.native_hook
}

///|
pub fn BundledWebView::event_dispatch_hook(self : BundledWebView) -> String {
  self.event_dispatch_hook
}

///|
pub fn BundledWebView::allowed_routes(self : BundledWebView) -> Array[String] {
  self.allowed_routes.copy()
}

///|
pub fn BundledWebView::initialization_scripts(
  self : BundledWebView,
) -> Array[String] {
  self.initialization_scripts.copy()
}

///|
fn optional_int(object : Map[String, Json], key : String) -> Int? {
  match object.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn optional_string_array(
  object : Map[String, Json],
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  match object.get(key) {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(value) => values.push(value)
          _ => ()
        }
      }
    _ => ()
  }
  values
}
