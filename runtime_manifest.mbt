///|
pub struct RuntimeLaunchManifest {
  backend : String
  asset_protocol : String
  devtools : Bool
  bridge_url : String
  webviews : Array[RuntimeWebViewBoot]
  protocol_mappings : Array[RuntimeProtocolBinding]
  virtual_files : Array[RuntimeVirtualAsset]
  command_routes : Array[String]
  registered_routes : Array[String]
} derive(Debug, Eq)

///|
pub struct RuntimeWebViewBoot {
  label : String
  title : String
  url : String
  width : Int
  height : Int
  resizable : Bool
  title_bar : TitleBarStyle
  devtools : Bool
  asset_protocol : String
  bridge_global_name : String
  native_hook : String
  initialization_scripts : Array[String]
} derive(Debug, Eq)

///|
pub struct RuntimeProtocolBinding {
  window_label : String
  scheme : String
  root : String
} derive(Debug, Eq)

///|
pub struct RuntimeVirtualAsset {
  window_label : String
  path : String
  mime_type : String
  content : String
} derive(Debug, Eq)

///|
pub fn RuntimePlan::launch_manifest(
  self : RuntimePlan,
  registered_routes? : Array[String] = [],
) -> Result[RuntimeLaunchManifest, Array[String]] {
  let webviews : Array[RuntimeWebViewBoot] = []
  let protocol_mappings : Array[RuntimeProtocolBinding] = []
  let virtual_files : Array[RuntimeVirtualAsset] = []
  let problems : Array[String] = []
  for window in self.windows() {
    match
      self.bridge_script(config=BridgeConfig::new(window_label=window.label())) {
      Ok(bridge) =>
        webviews.push(RuntimeWebViewBoot::from_window(self, window, bridge))
      Err(bridge_problems) =>
        for problem in bridge_problems {
          problems.push(problem)
        }
    }
    for mapping in window.source().protocol_mappings() {
      protocol_mappings.push(
        RuntimeProtocolBinding::from_mapping(window.label(), mapping),
      )
    }
    for file in window.source().virtual_files() {
      virtual_files.push(RuntimeVirtualAsset::from_file(window.label(), file))
    }
  }
  if problems.is_empty() {
    Ok({
      backend: self.backend().name(),
      asset_protocol: self.asset_protocol(),
      devtools: self.devtools(),
      bridge_url: "\{self.asset_protocol()}://runtime/bridge.js",
      webviews,
      protocol_mappings,
      virtual_files,
      command_routes: self.command_routes(),
      registered_routes: registered_routes.copy(),
    })
  } else {
    Err(problems)
  }
}

///|
fn RuntimeWebViewBoot::from_window(
  runtime : RuntimePlan,
  window : ResolvedWindow,
  bridge : BridgeScript,
) -> RuntimeWebViewBoot {
  {
    label: window.label(),
    title: window.title(),
    url: window.url(),
    width: window.width(),
    height: window.height(),
    resizable: window.resizable(),
    title_bar: window.title_bar(),
    devtools: runtime.devtools(),
    asset_protocol: runtime.asset_protocol(),
    bridge_global_name: bridge.global_name(),
    native_hook: bridge.native_hook(),
    initialization_scripts: [bridge.source()],
  }
}

///|
fn RuntimeProtocolBinding::from_mapping(
  window_label : String,
  mapping : ProtocolMapping,
) -> RuntimeProtocolBinding {
  { window_label, scheme: mapping.scheme(), root: mapping.root() }
}

///|
fn RuntimeVirtualAsset::from_file(
  window_label : String,
  file : VirtualFile,
) -> RuntimeVirtualAsset {
  {
    window_label,
    path: file.path(),
    mime_type: mime_type_for_path(file.path()),
    content: file.content(),
  }
}

///|
pub fn RuntimeLaunchManifest::backend(self : RuntimeLaunchManifest) -> String {
  self.backend
}

///|
pub fn RuntimeLaunchManifest::asset_protocol(
  self : RuntimeLaunchManifest,
) -> String {
  self.asset_protocol
}

///|
pub fn RuntimeLaunchManifest::devtools(self : RuntimeLaunchManifest) -> Bool {
  self.devtools
}

///|
pub fn RuntimeLaunchManifest::bridge_url(
  self : RuntimeLaunchManifest,
) -> String {
  self.bridge_url
}

///|
pub fn RuntimeLaunchManifest::webviews(
  self : RuntimeLaunchManifest,
) -> Array[RuntimeWebViewBoot] {
  self.webviews.copy()
}

///|
pub fn RuntimeLaunchManifest::protocol_mappings(
  self : RuntimeLaunchManifest,
) -> Array[RuntimeProtocolBinding] {
  self.protocol_mappings.copy()
}

///|
pub fn RuntimeLaunchManifest::virtual_files(
  self : RuntimeLaunchManifest,
) -> Array[RuntimeVirtualAsset] {
  self.virtual_files.copy()
}

///|
pub fn RuntimeLaunchManifest::command_routes(
  self : RuntimeLaunchManifest,
) -> Array[String] {
  self.command_routes.copy()
}

///|
pub fn RuntimeLaunchManifest::registered_routes(
  self : RuntimeLaunchManifest,
) -> Array[String] {
  self.registered_routes.copy()
}

///|
pub fn RuntimeLaunchManifest::to_json(self : RuntimeLaunchManifest) -> String {
  [
    "{",
    "\"backend\":\{self.backend.json_string()},",
    "\"assetProtocol\":\{self.asset_protocol.json_string()},",
    "\"devtools\":\{self.devtools.json_bool()},",
    "\"bridgeUrl\":\{self.bridge_url.json_string()},",
    "\"webviews\":[\{self.webviews.map(runtime_webview_boot_json).join(",")}],",
    "\"protocolMappings\":[\{self.protocol_mappings.map(runtime_protocol_binding_json).join(",")}],",
    "\"virtualFiles\":[\{self.virtual_files.map(runtime_virtual_asset_json).join(",")}],",
    "\"commandRoutes\":[\{self.command_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"registeredRoutes\":[\{self.registered_routes.map(fn(route) { route.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn RuntimeWebViewBoot::label(self : RuntimeWebViewBoot) -> String {
  self.label
}

///|
pub fn RuntimeWebViewBoot::title(self : RuntimeWebViewBoot) -> String {
  self.title
}

///|
pub fn RuntimeWebViewBoot::url(self : RuntimeWebViewBoot) -> String {
  self.url
}

///|
pub fn RuntimeWebViewBoot::width(self : RuntimeWebViewBoot) -> Int {
  self.width
}

///|
pub fn RuntimeWebViewBoot::height(self : RuntimeWebViewBoot) -> Int {
  self.height
}

///|
pub fn RuntimeWebViewBoot::resizable(self : RuntimeWebViewBoot) -> Bool {
  self.resizable
}

///|
pub fn RuntimeWebViewBoot::title_bar(
  self : RuntimeWebViewBoot,
) -> TitleBarStyle {
  self.title_bar
}

///|
pub fn RuntimeWebViewBoot::devtools(self : RuntimeWebViewBoot) -> Bool {
  self.devtools
}

///|
pub fn RuntimeWebViewBoot::asset_protocol(self : RuntimeWebViewBoot) -> String {
  self.asset_protocol
}

///|
pub fn RuntimeWebViewBoot::bridge_global_name(
  self : RuntimeWebViewBoot,
) -> String {
  self.bridge_global_name
}

///|
pub fn RuntimeWebViewBoot::native_hook(self : RuntimeWebViewBoot) -> String {
  self.native_hook
}

///|
pub fn RuntimeWebViewBoot::initialization_scripts(
  self : RuntimeWebViewBoot,
) -> Array[String] {
  self.initialization_scripts.copy()
}

///|
pub fn RuntimeProtocolBinding::window_label(
  self : RuntimeProtocolBinding,
) -> String {
  self.window_label
}

///|
pub fn RuntimeProtocolBinding::scheme(self : RuntimeProtocolBinding) -> String {
  self.scheme
}

///|
pub fn RuntimeProtocolBinding::root(self : RuntimeProtocolBinding) -> String {
  self.root
}

///|
pub fn RuntimeVirtualAsset::window_label(self : RuntimeVirtualAsset) -> String {
  self.window_label
}

///|
pub fn RuntimeVirtualAsset::path(self : RuntimeVirtualAsset) -> String {
  self.path
}

///|
pub fn RuntimeVirtualAsset::mime_type(self : RuntimeVirtualAsset) -> String {
  self.mime_type
}

///|
pub fn RuntimeVirtualAsset::content(self : RuntimeVirtualAsset) -> String {
  self.content
}

///|
fn runtime_webview_boot_json(webview : RuntimeWebViewBoot) -> String {
  [
    "{",
    "\"label\":\{webview.label().json_string()},",
    "\"title\":\{webview.title().json_string()},",
    "\"url\":\{webview.url().json_string()},",
    "\"width\":\{webview.width()},",
    "\"height\":\{webview.height()},",
    "\"resizable\":\{webview.resizable().json_bool()},",
    "\"titleBar\":\{webview.title_bar().manifest_name().json_string()},",
    "\"devtools\":\{webview.devtools().json_bool()},",
    "\"assetProtocol\":\{webview.asset_protocol().json_string()},",
    "\"bridgeGlobalName\":\{webview.bridge_global_name().json_string()},",
    "\"nativeHook\":\{webview.native_hook().json_string()},",
    "\"initializationScripts\":[\{webview.initialization_scripts().map(fn(script) { script.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn runtime_protocol_binding_json(binding : RuntimeProtocolBinding) -> String {
  [
    "{",
    "\"windowLabel\":\{binding.window_label().json_string()},",
    "\"scheme\":\{binding.scheme().json_string()},",
    "\"root\":\{binding.root().json_string()}",
    "}",
  ].join("")
}

///|
fn runtime_virtual_asset_json(asset : RuntimeVirtualAsset) -> String {
  [
    "{",
    "\"windowLabel\":\{asset.window_label().json_string()},",
    "\"path\":\{asset.path().json_string()},",
    "\"mimeType\":\{asset.mime_type().json_string()},",
    "\"content\":\{asset.content().json_string()}",
    "}",
  ].join("")
}

///|
fn mime_type_for_path(path : String) -> String {
  if path.has_suffix(".html") || path.has_suffix(".htm") {
    "text/html"
  } else if path.has_suffix(".js") || path.has_suffix(".mjs") {
    "application/javascript"
  } else if path.has_suffix(".css") {
    "text/css"
  } else if path.has_suffix(".json") {
    "application/json"
  } else if path.has_suffix(".svg") {
    "image/svg+xml"
  } else if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".jpg") || path.has_suffix(".jpeg") {
    "image/jpeg"
  } else if path.has_suffix(".wasm") {
    "application/wasm"
  } else {
    "application/octet-stream"
  }
}
