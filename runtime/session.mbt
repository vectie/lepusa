///|
pub struct RuntimeSession {
  backend : @lepusa.RuntimeBackend
  devtools : Bool
  asset_protocol : String
  windows : Array[RuntimeWindow]
  protocol_mappings : Array[RuntimeProtocolMapping]
  virtual_files : Array[RuntimeVirtualFile]
  local_services : Array[@lepusa.LocalService]
  filesystem_scopes : Array[@lepusa.FileSystemScope]
  startup_actions : Array[@lepusa.RuntimeAction]
  lifecycle_hooks : Array[@lepusa.RuntimeLifecycleHook]
  command_routes : Array[String]
  registered_routes : Array[String]
  bridge_source : String
} derive(Debug, Eq)

///|
pub struct RuntimeWindow {
  label : String
  title : String
  url : String
  width : Int
  height : Int
  resizable : Bool
  title_bar : @lepusa.TitleBarStyle
} derive(Debug, Eq)

///|
pub struct RuntimeProtocolMapping {
  window_label : String
  scheme : String
  root : String
} derive(Debug, Eq)

///|
pub struct RuntimeVirtualFile {
  window_label : String
  path : String
  content : String
} derive(Debug, Eq)

///|
fn RuntimeSession::from_plan(
  plan : @lepusa.RuntimePlan,
  bridge_source~ : String,
  startup_actions~ : Array[@lepusa.RuntimeAction],
  lifecycle_hooks~ : Array[@lepusa.RuntimeLifecycleHook],
  registered_routes~ : Array[String],
) -> RuntimeSession {
  let windows : Array[RuntimeWindow] = []
  let protocol_mappings : Array[RuntimeProtocolMapping] = []
  let virtual_files : Array[RuntimeVirtualFile] = []
  let local_services : Array[@lepusa.LocalService] = []
  for window in plan.windows() {
    windows.push(RuntimeWindow::from_resolved(window))
    for mapping in window.source().protocol_mappings() {
      protocol_mappings.push(
        RuntimeProtocolMapping::from_mapping(window.label(), mapping),
      )
    }
    for file in window.source().virtual_files() {
      virtual_files.push(RuntimeVirtualFile::from_file(window.label(), file))
    }
    for service in window.source().local_services() {
      local_services.push(service)
    }
  }
  {
    backend: plan.backend(),
    devtools: plan.devtools(),
    asset_protocol: plan.asset_protocol(),
    windows,
    protocol_mappings,
    virtual_files,
    local_services,
    filesystem_scopes: plan.file_system_scopes(),
    startup_actions,
    lifecycle_hooks,
    command_routes: plan.command_routes(),
    registered_routes,
    bridge_source,
  }
}

///|
fn RuntimeWindow::from_resolved(
  window : @lepusa.ResolvedWindow,
) -> RuntimeWindow {
  {
    label: window.label(),
    title: window.title(),
    url: window.url(),
    width: window.width(),
    height: window.height(),
    resizable: window.resizable(),
    title_bar: window.title_bar(),
  }
}

///|
fn RuntimeProtocolMapping::from_mapping(
  window_label : String,
  mapping : @lepusa.ProtocolMapping,
) -> RuntimeProtocolMapping {
  { window_label, scheme: mapping.scheme(), root: mapping.root() }
}

///|
fn RuntimeVirtualFile::from_file(
  window_label : String,
  file : @lepusa.VirtualFile,
) -> RuntimeVirtualFile {
  { window_label, path: file.path(), content: file.content() }
}

///|
pub fn RuntimeSession::backend(self : RuntimeSession) -> @lepusa.RuntimeBackend {
  self.backend
}

///|
pub fn RuntimeSession::devtools(self : RuntimeSession) -> Bool {
  self.devtools
}

///|
pub fn RuntimeSession::asset_protocol(self : RuntimeSession) -> String {
  self.asset_protocol
}

///|
pub fn RuntimeSession::windows(self : RuntimeSession) -> Array[RuntimeWindow] {
  self.windows.copy()
}

///|
pub fn RuntimeSession::protocol_mappings(
  self : RuntimeSession,
) -> Array[RuntimeProtocolMapping] {
  self.protocol_mappings.copy()
}

///|
pub fn RuntimeSession::virtual_files(
  self : RuntimeSession,
) -> Array[RuntimeVirtualFile] {
  self.virtual_files.copy()
}

///|
pub fn RuntimeSession::local_services(
  self : RuntimeSession,
) -> Array[@lepusa.LocalService] {
  self.local_services.copy()
}

///|
pub fn RuntimeSession::file_system_scopes(
  self : RuntimeSession,
) -> Array[@lepusa.FileSystemScope] {
  self.filesystem_scopes.copy()
}

///|
pub fn RuntimeSession::startup_actions(
  self : RuntimeSession,
) -> Array[@lepusa.RuntimeAction] {
  self.startup_actions.copy()
}

///|
pub fn RuntimeSession::lifecycle_hooks(
  self : RuntimeSession,
) -> Array[@lepusa.RuntimeLifecycleHook] {
  self.lifecycle_hooks.copy()
}

///|
pub fn RuntimeSession::command_routes(self : RuntimeSession) -> Array[String] {
  self.command_routes.copy()
}

///|
pub fn RuntimeSession::registered_routes(
  self : RuntimeSession,
) -> Array[String] {
  self.registered_routes.copy()
}

///|
pub fn RuntimeSession::bridge_source(self : RuntimeSession) -> String {
  self.bridge_source
}

///|
pub fn RuntimeSession::to_json(self : RuntimeSession) -> String {
  [
    "{",
    "\"backend\":\{self.backend().name().json_string()},",
    "\"devtools\":\{self.devtools.json_bool()},",
    "\"assetProtocol\":\{self.asset_protocol.json_string()},",
    "\"bridgeUrl\":\{self.bridge_url().json_string()},",
    "\"bridgeSource\":\{self.bridge_source.json_string()},",
    "\"windows\":[\{self.windows.map(runtime_window_json).join(",")}],",
    "\"protocolMappings\":[\{self.protocol_mappings.map(runtime_protocol_mapping_json).join(",")}],",
    "\"virtualFiles\":[\{self.virtual_files.map(runtime_virtual_file_json).join(",")}],",
    "\"localServices\":[\{self.local_services.map(fn(service) { service.to_json() }).join(",")}],",
    "\"filesystemScopes\":[\{self.filesystem_scopes.map(fn(scope) { scope.to_json() }).join(",")}],",
    "\"startupActions\":[\{self.startup_actions.map(fn(action) { action.to_json() }).join(",")}],",
    "\"lifecycleHooks\":[\{self.lifecycle_hooks.map(fn(hook) { hook.to_json() }).join(",")}],",
    "\"commandRoutes\":[\{self.command_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"registeredRoutes\":[\{self.registered_routes.map(fn(route) { route.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn RuntimeWindow::label(self : RuntimeWindow) -> String {
  self.label
}

///|
pub fn RuntimeWindow::title(self : RuntimeWindow) -> String {
  self.title
}

///|
pub fn RuntimeWindow::url(self : RuntimeWindow) -> String {
  self.url
}

///|
pub fn RuntimeWindow::width(self : RuntimeWindow) -> Int {
  self.width
}

///|
pub fn RuntimeWindow::height(self : RuntimeWindow) -> Int {
  self.height
}

///|
pub fn RuntimeWindow::resizable(self : RuntimeWindow) -> Bool {
  self.resizable
}

///|
pub fn RuntimeWindow::title_bar(self : RuntimeWindow) -> @lepusa.TitleBarStyle {
  self.title_bar
}

///|
pub fn RuntimeProtocolMapping::window_label(
  self : RuntimeProtocolMapping,
) -> String {
  self.window_label
}

///|
pub fn RuntimeProtocolMapping::scheme(self : RuntimeProtocolMapping) -> String {
  self.scheme
}

///|
pub fn RuntimeProtocolMapping::root(self : RuntimeProtocolMapping) -> String {
  self.root
}

///|
pub fn RuntimeVirtualFile::window_label(self : RuntimeVirtualFile) -> String {
  self.window_label
}

///|
pub fn RuntimeVirtualFile::path(self : RuntimeVirtualFile) -> String {
  self.path
}

///|
pub fn RuntimeVirtualFile::content(self : RuntimeVirtualFile) -> String {
  self.content
}

///|
fn runtime_window_json(window : RuntimeWindow) -> String {
  [
    "{",
    "\"label\":\{window.label().json_string()},",
    "\"title\":\{window.title().json_string()},",
    "\"url\":\{window.url().json_string()},",
    "\"width\":\{window.width()},",
    "\"height\":\{window.height()},",
    "\"resizable\":\{window.resizable().json_bool()},",
    "\"titleBar\":\{window.title_bar().native_manifest_name().json_string()}",
    "}",
  ].join("")
}

///|
fn runtime_protocol_mapping_json(mapping : RuntimeProtocolMapping) -> String {
  [
    "{",
    "\"windowLabel\":\{mapping.window_label().json_string()},",
    "\"scheme\":\{mapping.scheme().json_string()},",
    "\"root\":\{mapping.root().json_string()}",
    "}",
  ].join("")
}

///|
fn runtime_virtual_file_json(file : RuntimeVirtualFile) -> String {
  [
    "{",
    "\"windowLabel\":\{file.window_label().json_string()},",
    "\"path\":\{file.path().json_string()},",
    "\"mimeType\":\{mime_type_for_path(file.path()).json_string()},",
    "\"content\":\{file.content().json_string()}",
    "}",
  ].join("")
}
