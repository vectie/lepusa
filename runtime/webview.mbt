///|
pub struct RuntimeWebViewSpec {
  label : String
  title : String
  url : String
  width : Int
  height : Int
  resizable : Bool
  title_bar : @lepusa.TitleBarStyle
  devtools : Bool
  asset_protocol : String
  bridge_global_name : String
  native_hook : String
  event_dispatch_hook : String
  allowed_routes : Array[String]
  initialization_scripts : Array[String]
} derive(Debug, Eq)

///|
pub fn RuntimeHost::webviews(
  self : RuntimeHost,
) -> Result[Array[RuntimeWebViewSpec], Array[String]] {
  let specs : Array[RuntimeWebViewSpec] = []
  match self.launch_manifest() {
    Ok(manifest) => {
      for webview in manifest.webviews() {
        specs.push(RuntimeWebViewSpec::from_boot(webview))
      }
      Ok(specs)
    }
    Err(problems) => Err(problems)
  }
}

///|
fn RuntimeWebViewSpec::from_boot(
  webview : @lepusa.RuntimeWebViewBoot,
) -> RuntimeWebViewSpec {
  {
    label: webview.label(),
    title: webview.title(),
    url: webview.url(),
    width: webview.width(),
    height: webview.height(),
    resizable: webview.resizable(),
    title_bar: webview.title_bar(),
    devtools: webview.devtools(),
    asset_protocol: webview.asset_protocol(),
    bridge_global_name: webview.bridge_global_name(),
    native_hook: webview.native_hook(),
    event_dispatch_hook: webview.event_dispatch_hook(),
    allowed_routes: webview.allowed_routes(),
    initialization_scripts: webview.initialization_scripts(),
  }
}

///|
pub fn RuntimeWebViewSpec::label(self : RuntimeWebViewSpec) -> String {
  self.label
}

///|
pub fn RuntimeWebViewSpec::title(self : RuntimeWebViewSpec) -> String {
  self.title
}

///|
pub fn RuntimeWebViewSpec::url(self : RuntimeWebViewSpec) -> String {
  self.url
}

///|
pub fn RuntimeWebViewSpec::width(self : RuntimeWebViewSpec) -> Int {
  self.width
}

///|
pub fn RuntimeWebViewSpec::height(self : RuntimeWebViewSpec) -> Int {
  self.height
}

///|
pub fn RuntimeWebViewSpec::resizable(self : RuntimeWebViewSpec) -> Bool {
  self.resizable
}

///|
pub fn RuntimeWebViewSpec::title_bar(
  self : RuntimeWebViewSpec,
) -> @lepusa.TitleBarStyle {
  self.title_bar
}

///|
pub fn RuntimeWebViewSpec::devtools(self : RuntimeWebViewSpec) -> Bool {
  self.devtools
}

///|
pub fn RuntimeWebViewSpec::asset_protocol(self : RuntimeWebViewSpec) -> String {
  self.asset_protocol
}

///|
pub fn RuntimeWebViewSpec::bridge_global_name(
  self : RuntimeWebViewSpec,
) -> String {
  self.bridge_global_name
}

///|
pub fn RuntimeWebViewSpec::native_hook(self : RuntimeWebViewSpec) -> String {
  self.native_hook
}

///|
pub fn RuntimeWebViewSpec::event_dispatch_hook(
  self : RuntimeWebViewSpec,
) -> String {
  self.event_dispatch_hook
}

///|
pub fn RuntimeWebViewSpec::allowed_routes(
  self : RuntimeWebViewSpec,
) -> Array[String] {
  self.allowed_routes.copy()
}

///|
pub fn RuntimeWebViewSpec::initialization_scripts(
  self : RuntimeWebViewSpec,
) -> Array[String] {
  self.initialization_scripts.copy()
}

///|
pub fn RuntimeWebViewSpec::to_json(self : RuntimeWebViewSpec) -> String {
  [
    "{",
    "\"label\":\{self.label.json_string()},",
    "\"title\":\{self.title.json_string()},",
    "\"url\":\{self.url.json_string()},",
    "\"width\":\{self.width},",
    "\"height\":\{self.height},",
    "\"resizable\":\{self.resizable.json_bool()},",
    "\"titleBar\":\{self.title_bar.native_manifest_name().json_string()},",
    "\"devtools\":\{self.devtools.json_bool()},",
    "\"assetProtocol\":\{self.asset_protocol.json_string()},",
    "\"bridgeGlobalName\":\{self.bridge_global_name.json_string()},",
    "\"nativeHook\":\{self.native_hook.json_string()},",
    "\"eventDispatchHook\":\{self.event_dispatch_hook.json_string()},",
    "\"allowedRoutes\":[\{self.allowed_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"initializationScripts\":[\{self.initialization_scripts.map(fn(script) { script.json_string() }).join(",")}]",
    "}",
  ].join("")
}
