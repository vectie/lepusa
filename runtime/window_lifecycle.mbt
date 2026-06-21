///|
pub struct RuntimeWindowOpenPlan {
  window : RuntimeWindow
  asset_protocol : String
  bridge_global_name : String
  native_hook : String
  devtools : Bool
  bridge_source : String
  allowed_routes : Array[String]
} derive(Debug, Eq)

///|
pub fn RuntimeWindowOpenPlan::new(
  window~ : RuntimeWindow,
  asset_protocol~ : String,
  bridge_global_name~ : String,
  native_hook~ : String,
  devtools~ : Bool,
  bridge_source~ : String,
  allowed_routes~ : Array[String],
) -> RuntimeWindowOpenPlan {
  {
    window,
    asset_protocol,
    bridge_global_name,
    native_hook,
    devtools,
    bridge_source,
    allowed_routes: allowed_routes.copy(),
  }
}

///|
pub fn RuntimeWindowOpenPlan::window(
  self : RuntimeWindowOpenPlan,
) -> RuntimeWindow {
  self.window
}

///|
pub fn RuntimeWindowOpenPlan::label(self : RuntimeWindowOpenPlan) -> String {
  self.window.label()
}

///|
pub fn RuntimeWindowOpenPlan::url(self : RuntimeWindowOpenPlan) -> String {
  self.window.url()
}

///|
pub fn RuntimeWindowOpenPlan::asset_protocol(
  self : RuntimeWindowOpenPlan,
) -> String {
  self.asset_protocol
}

///|
pub fn RuntimeWindowOpenPlan::bridge_global_name(
  self : RuntimeWindowOpenPlan,
) -> String {
  self.bridge_global_name
}

///|
pub fn RuntimeWindowOpenPlan::native_hook(
  self : RuntimeWindowOpenPlan,
) -> String {
  self.native_hook
}

///|
pub fn RuntimeWindowOpenPlan::devtools(self : RuntimeWindowOpenPlan) -> Bool {
  self.devtools
}

///|
pub fn RuntimeWindowOpenPlan::bridge_source(
  self : RuntimeWindowOpenPlan,
) -> String {
  self.bridge_source
}

///|
pub fn RuntimeWindowOpenPlan::allowed_routes(
  self : RuntimeWindowOpenPlan,
) -> Array[String] {
  self.allowed_routes.copy()
}

///|
pub fn RuntimeWindowOpenPlan::initialization_scripts(
  self : RuntimeWindowOpenPlan,
) -> Array[String] {
  if self.bridge_source == "" {
    []
  } else {
    [self.bridge_source]
  }
}

///|
pub fn RuntimeWindowOpenPlan::webview_spec(
  self : RuntimeWindowOpenPlan,
) -> RuntimeWebViewSpec {
  {
    label: self.window.label(),
    title: self.window.title(),
    url: self.window.url(),
    width: self.window.width(),
    height: self.window.height(),
    resizable: self.window.resizable(),
    title_bar: self.window.title_bar(),
    devtools: self.devtools,
    asset_protocol: self.asset_protocol,
    bridge_global_name: self.bridge_global_name,
    native_hook: self.native_hook,
    event_dispatch_hook: self.window.event_dispatch_hook(),
    allowed_routes: self.allowed_routes(),
    initialization_scripts: self.initialization_scripts(),
  }
}

///|
pub fn RuntimeWindowOpenPlan::to_json(self : RuntimeWindowOpenPlan) -> String {
  [
    "{",
    "\"window\":\{runtime_window_json(self.window)},",
    "\"assetProtocol\":\{self.asset_protocol.json_string()},",
    "\"bridgeGlobalName\":\{self.bridge_global_name.json_string()},",
    "\"nativeHook\":\{self.native_hook.json_string()},",
    "\"devtools\":\{self.devtools.json_bool()},",
    "\"bridgeSource\":\{self.bridge_source.json_string()},",
    "\"allowedRoutes\":[\{self.allowed_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"webviewSpec\":\{self.webview_spec().to_json()}",
    "}",
  ].join("")
}

///|
pub fn RuntimeSession::open_window(
  self : RuntimeSession,
  window : @lepusa.WindowConfig,
) -> Result[RuntimeStep, Array[String]] {
  match window.resolve(asset_protocol=self.asset_protocol()) {
    Ok(resolved) => self.open_resolved_window(resolved)
    Err(problems) => Err(problems)
  }
}

///|
pub fn RuntimeSession::request_window_close(
  self : RuntimeSession,
  window_label : String,
) -> Result[RuntimeStep, Array[String]] {
  if !self.has_live_window(window_label) {
    Err(["window not found: \{window_label}"])
  } else {
    self.lifecycle_step(
      @lepusa.LifecycleEvent::window_close_requested(window_label),
    )
  }
}

///|
pub fn RuntimeSession::close_window(
  self : RuntimeSession,
  window_label : String,
) -> Result[RuntimeStep, Array[String]] {
  if !self.has_live_window(window_label) {
    return Err(["window not found: \{window_label}"])
  }
  match
    self.lifecycle_step(@lepusa.LifecycleEvent::window_closed(window_label)) {
    Ok(step) => {
      let operations = step.operations()
      operations.push(RuntimeCloseWindow(window_label))
      Ok({ session: step.session().without_window(window_label), operations })
    }
    Err(problems) => Err(problems)
  }
}

///|
fn RuntimeSession::open_resolved_window(
  self : RuntimeSession,
  window : @lepusa.ResolvedWindow,
) -> Result[RuntimeStep, Array[String]] {
  let label = window.label()
  if label == "" {
    return Err(["window label is required"])
  }
  if self.has_live_window(label) {
    return Err(["window already open: \{label}"])
  }
  let runtime_window = RuntimeWindow::from_resolved(
    window,
    event_dispatch_hook="__lepusaDispatchEvent",
  )
  let protocol_mappings = self.protocol_mappings.copy()
  for mapping in window.source().protocol_mappings() {
    protocol_mappings.push(RuntimeProtocolMapping::from_mapping(label, mapping))
  }
  let virtual_files = self.virtual_files.copy()
  for file in window.source().virtual_files() {
    virtual_files.push(RuntimeVirtualFile::from_file(label, file))
  }
  let local_services = self.local_services.copy()
  for service in window.source().local_services() {
    local_services.push(service)
  }
  let windows = self.windows.copy()
  windows.push(runtime_window)
  let open_plan = self.window_open_plan(runtime_window)
  Ok({
    session: {
      ..self,
      windows,
      protocol_mappings,
      virtual_files,
      local_services,
    },
    operations: [RuntimeOpenWindow(open_plan)],
  })
}

///|
fn RuntimeSession::window_open_plan(
  self : RuntimeSession,
  window : RuntimeWindow,
) -> RuntimeWindowOpenPlan {
  RuntimeWindowOpenPlan::new(
    window~,
    asset_protocol=self.asset_protocol,
    bridge_global_name=self.bridge_global_name,
    native_hook=self.native_hook,
    devtools=self.devtools,
    bridge_source=self.bridge_source,
    allowed_routes=self.command_routes,
  )
}

///|
fn RuntimeSession::without_window(
  self : RuntimeSession,
  window_label : String,
) -> RuntimeSession {
  ignore(self.remove_event_target(WindowTarget(window_label)))
  ignore(self.remove_event_target(WebviewTarget(window_label)))
  {
    ..self,
    windows: self.windows_without(window_label),
    protocol_mappings: self.protocol_mappings_without(window_label),
    virtual_files: self.virtual_files_without(window_label),
    local_services: self.local_services_without(window_label),
  }
}

///|
fn RuntimeSession::has_live_window(
  self : RuntimeSession,
  window_label : String,
) -> Bool {
  for window in self.windows {
    if window.label() == window_label {
      return true
    }
  }
  false
}

///|
fn RuntimeSession::windows_without(
  self : RuntimeSession,
  window_label : String,
) -> Array[RuntimeWindow] {
  let windows : Array[RuntimeWindow] = []
  for window in self.windows {
    if window.label() != window_label {
      windows.push(window)
    }
  }
  windows
}
