///|
pub struct RuntimeLaunchManifest {
  backend : String
  asset_protocol : String
  devtools : Bool
  bridge_url : String
  webviews : Array[RuntimeWebViewSpec]
  protocol_mappings : Array[RuntimeProtocolMapping]
  command_routes : Array[String]
  registered_routes : Array[String]
} derive(Debug, Eq)

///|
pub fn RuntimeHost::launch_manifest(
  self : RuntimeHost,
) -> Result[RuntimeLaunchManifest, Array[String]] {
  match self.snapshot() {
    Ok(session) =>
      match self.webviews() {
        Ok(webviews) =>
          Ok({
            backend: session.backend().name(),
            asset_protocol: session.asset_protocol(),
            devtools: session.devtools(),
            bridge_url: session.bridge_url(),
            webviews,
            protocol_mappings: session.protocol_mappings(),
            command_routes: session.command_routes(),
            registered_routes: session.registered_routes(),
          })
        Err(problems) => Err(problems)
      }
    Err(problems) => Err(problems)
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
) -> Array[RuntimeWebViewSpec] {
  self.webviews.copy()
}

///|
pub fn RuntimeLaunchManifest::protocol_mappings(
  self : RuntimeLaunchManifest,
) -> Array[RuntimeProtocolMapping] {
  self.protocol_mappings.copy()
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
    "\"devtools\":\{self.devtools.bool_json()},",
    "\"bridgeUrl\":\{self.bridge_url.json_string()},",
    "\"webviews\":[\{self.webviews.map(webview_manifest_json).join(",")}],",
    "\"protocolMappings\":[\{self.protocol_mappings.map(protocol_mapping_manifest_json).join(",")}],",
    "\"commandRoutes\":[\{self.command_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"registeredRoutes\":[\{self.registered_routes.map(fn(route) { route.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn webview_manifest_json(webview : RuntimeWebViewSpec) -> String {
  [
    "{",
    "\"label\":\{webview.label().json_string()},",
    "\"title\":\{webview.title().json_string()},",
    "\"url\":\{webview.url().json_string()},",
    "\"width\":\{webview.width()},",
    "\"height\":\{webview.height()},",
    "\"resizable\":\{webview.resizable().bool_json()},",
    "\"titleBar\":\{title_bar_name(webview.title_bar()).json_string()},",
    "\"devtools\":\{webview.devtools().bool_json()},",
    "\"assetProtocol\":\{webview.asset_protocol().json_string()},",
    "\"bridgeGlobalName\":\{webview.bridge_global_name().json_string()},",
    "\"nativeHook\":\{webview.native_hook().json_string()},",
    "\"initializationScripts\":[\{webview.initialization_scripts().map(fn(script) { script.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn protocol_mapping_manifest_json(mapping : RuntimeProtocolMapping) -> String {
  [
    "{",
    "\"windowLabel\":\{mapping.window_label().json_string()},",
    "\"scheme\":\{mapping.scheme().json_string()},",
    "\"root\":\{mapping.root().json_string()}",
    "}",
  ].join("")
}

///|
fn title_bar_name(style : @lepusa.TitleBarStyle) -> String {
  match style {
    Native => "native"
    Transparent => "transparent"
    Hidden => "hidden"
  }
}

///|
fn Bool::bool_json(self : Bool) -> String {
  if self {
    "true"
  } else {
    "false"
  }
}

///|
fn String::json_string(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
