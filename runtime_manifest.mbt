///|
pub struct RuntimeLaunchManifest {
  backend : String
  asset_protocol : String
  devtools : Bool
  bridge_url : String
  webviews : Array[RuntimeWebViewBoot]
  protocol_mappings : Array[RuntimeProtocolBinding]
  virtual_files : Array[RuntimeVirtualAsset]
  startup_actions : Array[RuntimeAction]
  lifecycle_hooks : Array[RuntimeLifecycleHook]
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
  event_dispatch_hook : String
  allowed_routes : Array[String]
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
pub(all) enum RuntimeLaunchAssetBody {
  LaunchVirtualContent(String)
  LaunchLocalFile(String)
} derive(Debug, Eq)

///|
pub struct RuntimeLaunchAsset {
  url : String
  mime_type : String
  body : RuntimeLaunchAssetBody
} derive(Debug, Eq)

///|
struct ParsedLaunchAssetUrl {
  scheme : String
  authority : String
  path : String
} derive(Debug, Eq)

///|
pub fn RuntimePlan::launch_manifest(
  self : RuntimePlan,
  registered_routes? : Array[String] = [],
) -> Result[RuntimeLaunchManifest, Array[String]] {
  let webviews : Array[RuntimeWebViewBoot] = []
  let protocol_mappings : Array[RuntimeProtocolBinding] = []
  let virtual_files : Array[RuntimeVirtualAsset] = []
  let startup_actions : Array[RuntimeAction] = []
  let lifecycle_hooks : Array[RuntimeLifecycleHook] = []
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
  match self.startup_actions() {
    Ok(actions) =>
      for action in actions {
        startup_actions.push(action)
      }
    Err(action_problems) =>
      for problem in action_problems {
        problems.push(problem)
      }
  }
  match self.lifecycle_hooks() {
    Ok(hooks) =>
      for hook in hooks {
        lifecycle_hooks.push(hook)
      }
    Err(hook_problems) =>
      for problem in hook_problems {
        problems.push(problem)
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
      startup_actions,
      lifecycle_hooks,
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
    event_dispatch_hook: bridge.event_dispatch_hook(),
    allowed_routes: bridge.routes(),
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
pub fn RuntimeLaunchManifest::startup_actions(
  self : RuntimeLaunchManifest,
) -> Array[RuntimeAction] {
  self.startup_actions.copy()
}

///|
pub fn RuntimeLaunchManifest::lifecycle_hooks(
  self : RuntimeLaunchManifest,
) -> Array[RuntimeLifecycleHook] {
  self.lifecycle_hooks.copy()
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
    "\"startupActions\":[\{self.startup_actions.map(fn(action) { action.to_json() }).join(",")}],",
    "\"lifecycleHooks\":[\{self.lifecycle_hooks.map(fn(hook) { hook.to_json() }).join(",")}],",
    "\"commandRoutes\":[\{self.command_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"registeredRoutes\":[\{self.registered_routes.map(fn(route) { route.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn RuntimeLaunchManifest::resolve_asset(
  self : RuntimeLaunchManifest,
  url : String,
) -> Result[RuntimeLaunchAsset, String] {
  match parse_launch_asset_url(url) {
    Err(problem) => Err(problem)
    Ok(parsed) =>
      if parsed.scheme != self.asset_protocol {
        Err("asset scheme mismatch: \{parsed.scheme}")
      } else if parsed.authority == "inline" || parsed.authority == "rabbita" {
        self.resolve_virtual_asset(url, parsed)
      } else if parsed.authority == "local" {
        self.resolve_local_asset(url, parsed)
      } else if parsed.authority == "runtime" {
        Err(
          "runtime assets are injected through WebView initialization scripts",
        )
      } else {
        Err("unknown asset authority: \{parsed.authority}")
      }
  }
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
pub fn RuntimeWebViewBoot::event_dispatch_hook(
  self : RuntimeWebViewBoot,
) -> String {
  self.event_dispatch_hook
}

///|
pub fn RuntimeWebViewBoot::allowed_routes(
  self : RuntimeWebViewBoot,
) -> Array[String] {
  self.allowed_routes.copy()
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
pub fn RuntimeLaunchAsset::url(self : RuntimeLaunchAsset) -> String {
  self.url
}

///|
pub fn RuntimeLaunchAsset::mime_type(self : RuntimeLaunchAsset) -> String {
  self.mime_type
}

///|
pub fn RuntimeLaunchAsset::body(
  self : RuntimeLaunchAsset,
) -> RuntimeLaunchAssetBody {
  self.body
}

///|
fn RuntimeLaunchManifest::resolve_virtual_asset(
  self : RuntimeLaunchManifest,
  url : String,
  parsed : ParsedLaunchAssetUrl,
) -> Result[RuntimeLaunchAsset, String] {
  match parse_manifest_asset_path(parsed.path) {
    Err(problem) => Err(problem)
    Ok((window_label, path)) => {
      for file in self.virtual_files {
        if file.window_label() == window_label && file.path() == path {
          return Ok({
            url,
            mime_type: file.mime_type(),
            body: LaunchVirtualContent(file.content()),
          })
        }
      }
      Err("virtual asset not found: \{window_label}/\{path}")
    }
  }
}

///|
fn RuntimeLaunchManifest::resolve_local_asset(
  self : RuntimeLaunchManifest,
  url : String,
  parsed : ParsedLaunchAssetUrl,
) -> Result[RuntimeLaunchAsset, String] {
  match parse_manifest_asset_path(parsed.path) {
    Err(problem) => Err(problem)
    Ok((window_label, path)) =>
      match self.local_root_for(window_label) {
        None => Err("local asset root not found: \{window_label}")
        Some(root) =>
          Ok({
            url,
            mime_type: mime_type_for_path(path),
            body: LaunchLocalFile(join_asset_path(root, path)),
          })
      }
  }
}

///|
fn RuntimeLaunchManifest::local_root_for(
  self : RuntimeLaunchManifest,
  label : String,
) -> String? {
  for mapping in self.protocol_mappings {
    if mapping.window_label() == label && !mapping.root().has_prefix("memory:") {
      return Some(mapping.root())
    }
  }
  None
}

///|
fn parse_launch_asset_url(url : String) -> Result[ParsedLaunchAssetUrl, String] {
  match url.find("://") {
    None => Err("asset url must include scheme")
    Some(index) => {
      let scheme = url[:index].to_owned()
      let rest = url[index + 3:].to_owned()
      match rest.find("/") {
        None => Ok({ scheme, authority: rest, path: "" })
        Some(path_index) =>
          Ok({
            scheme,
            authority: rest[:path_index].to_owned(),
            path: strip_asset_suffix(rest[path_index + 1:].to_owned()),
          })
      }
    }
  }
}

///|
fn strip_asset_suffix(path : String) -> String {
  let without_query = match path.find("?") {
    None => path
    Some(index) => path[:index].to_owned()
  }
  match without_query.find("#") {
    None => without_query
    Some(index) => without_query[:index].to_owned()
  }
}

///|
fn parse_manifest_asset_path(path : String) -> Result[(String, String), String] {
  match path.find("/") {
    None => Err("asset path must include window label")
    Some(index) => {
      let window_label = path[:index].to_owned()
      let asset_path = path[index + 1:].to_owned()
      if window_label == "" {
        Err("asset window label is required")
      } else if !is_safe_asset_path(asset_path) {
        Err("unsafe asset path: \{asset_path}")
      } else {
        Ok((window_label, asset_path))
      }
    }
  }
}

///|
fn is_safe_asset_path(path : String) -> Bool {
  if path == "" || path.has_prefix("/") || path.has_prefix("\\") {
    return false
  }
  for segment in path.split("/") {
    if segment == "" || segment == "." || segment == ".." {
      return false
    }
    if segment.contains("\\") {
      return false
    }
  }
  true
}

///|
fn join_asset_path(root : String, path : String) -> String {
  let root = root.trim_end(chars="/\\").to_owned()
  if root == "" {
    path
  } else {
    "\{root}/\{path}"
  }
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
    "\"eventDispatchHook\":\{webview.event_dispatch_hook().json_string()},",
    "\"allowedRoutes\":[\{webview.allowed_routes().map(fn(route) { route.json_string() }).join(",")}],",
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
