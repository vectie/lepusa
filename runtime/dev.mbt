///|
pub struct RuntimeDevPlan {
  launch_manifest : @lepusa.RuntimeLaunchManifest
  session : RuntimeSession
  dev_session : RuntimeDevSession
  webviews : Array[RuntimeWebViewSpec]
  startup_operations : Array[RuntimeOperation]
  lifecycle_steps : Array[RuntimeRunnerStep]
  bridge_sync_routes : Array[String]
  bridge_async_routes : Array[String]
  commands : Array[RuntimeDevCommand]
} derive(Debug, Eq)

///|
pub struct RuntimeDevSession {
  webviews : Array[RuntimeDevWebView]
  service_plan : RuntimeServicePlan
  reload_event : String
  proxy_mode : String
} derive(Debug, Eq)

///|
pub struct RuntimeDevWebView {
  label : String
  url : String
  source_kind : RuntimeDevSourceKind
  reload_mode : RuntimeDevReloadMode
  asset_protocol : String
  native_hook : String
  event_dispatch_hook : String
  local_service : @lepusa.LocalService?
} derive(Debug, Eq)

///|
pub(all) enum RuntimeDevSourceKind {
  RuntimeDevInlineAssets
  RuntimeDevRabbitaAssets
  RuntimeDevLocalAssets
  RuntimeDevPackagedAssets
  RuntimeDevSupervisedLocalhost
  RuntimeDevExternalUrl
  RuntimeDevCustomUrl
} derive(Debug, Eq)

///|
pub(all) enum RuntimeDevReloadMode {
  RuntimeDevReloadWindow
  RuntimeDevReloadExternal
  RuntimeDevReloadNone
} derive(Debug, Eq)

///|
pub struct RuntimeDevCommand {
  name : String
  purpose : String
  template : String
  target_required : Bool
} derive(Debug, Eq)

///|
pub fn RuntimeHost::dev_plan(
  self : RuntimeHost,
) -> Result[RuntimeDevPlan, Array[String]] {
  match self.runner_plan() {
    Ok(plan) => {
      let service_plan = plan.service_plan()
      let webviews = plan.webviews()
      Ok({
        launch_manifest: plan.launch_manifest(),
        session: plan.session(),
        dev_session: runtime_dev_session(webviews, service_plan),
        webviews,
        startup_operations: plan.startup_operations(),
        lifecycle_steps: plan.lifecycle_steps(),
        bridge_sync_routes: self.sync_command_routes(),
        bridge_async_routes: self.async_command_routes(),
        commands: runtime_dev_commands(),
      })
    }
    Err(problems) => Err(problems)
  }
}

///|
pub fn RuntimeDevPlan::launch_manifest(
  self : RuntimeDevPlan,
) -> @lepusa.RuntimeLaunchManifest {
  self.launch_manifest
}

///|
pub fn RuntimeDevPlan::session(self : RuntimeDevPlan) -> RuntimeSession {
  self.session
}

///|
pub fn RuntimeDevPlan::dev_session(self : RuntimeDevPlan) -> RuntimeDevSession {
  self.dev_session
}

///|
pub fn RuntimeDevPlan::webviews(
  self : RuntimeDevPlan,
) -> Array[RuntimeWebViewSpec] {
  self.webviews.copy()
}

///|
pub fn RuntimeDevPlan::startup_operations(
  self : RuntimeDevPlan,
) -> Array[RuntimeOperation] {
  self.startup_operations.copy()
}

///|
pub fn RuntimeDevPlan::lifecycle_steps(
  self : RuntimeDevPlan,
) -> Array[RuntimeRunnerStep] {
  self.lifecycle_steps.copy()
}

///|
pub fn RuntimeDevPlan::bridge_sync_routes(
  self : RuntimeDevPlan,
) -> Array[String] {
  self.bridge_sync_routes.copy()
}

///|
pub fn RuntimeDevPlan::bridge_async_routes(
  self : RuntimeDevPlan,
) -> Array[String] {
  self.bridge_async_routes.copy()
}

///|
pub fn RuntimeDevPlan::commands(
  self : RuntimeDevPlan,
) -> Array[RuntimeDevCommand] {
  self.commands.copy()
}

///|
pub fn RuntimeDevCommand::new(
  name~ : String,
  purpose~ : String,
  template~ : String,
  target_required? : Bool = false,
) -> RuntimeDevCommand {
  { name, purpose, template, target_required }
}

///|
pub fn RuntimeDevCommand::name(self : RuntimeDevCommand) -> String {
  self.name
}

///|
pub fn RuntimeDevCommand::purpose(self : RuntimeDevCommand) -> String {
  self.purpose
}

///|
pub fn RuntimeDevCommand::template(self : RuntimeDevCommand) -> String {
  self.template
}

///|
pub fn RuntimeDevCommand::target_required(self : RuntimeDevCommand) -> Bool {
  self.target_required
}

///|
pub fn RuntimeDevSession::webviews(
  self : RuntimeDevSession,
) -> Array[RuntimeDevWebView] {
  self.webviews.copy()
}

///|
pub fn RuntimeDevSession::service_plan(
  self : RuntimeDevSession,
) -> RuntimeServicePlan {
  self.service_plan
}

///|
pub fn RuntimeDevSession::reload_event(self : RuntimeDevSession) -> String {
  self.reload_event
}

///|
pub fn RuntimeDevSession::proxy_mode(self : RuntimeDevSession) -> String {
  self.proxy_mode
}

///|
pub fn RuntimeDevSession::requires_supervisor(self : RuntimeDevSession) -> Bool {
  self.service_plan.requires_supervisor()
}

///|
pub fn RuntimeDevSession::window_reload_count(self : RuntimeDevSession) -> Int {
  let mut count = 0
  for webview in self.webviews {
    if webview.reload_mode() is RuntimeDevReloadWindow {
      count += 1
    }
  }
  count
}

///|
pub fn RuntimeDevSession::external_reload_count(
  self : RuntimeDevSession,
) -> Int {
  let mut count = 0
  for webview in self.webviews {
    if webview.reload_mode() is RuntimeDevReloadExternal {
      count += 1
    }
  }
  count
}

///|
pub fn RuntimeDevWebView::label(self : RuntimeDevWebView) -> String {
  self.label
}

///|
pub fn RuntimeDevWebView::url(self : RuntimeDevWebView) -> String {
  self.url
}

///|
pub fn RuntimeDevWebView::source_kind(
  self : RuntimeDevWebView,
) -> RuntimeDevSourceKind {
  self.source_kind
}

///|
pub fn RuntimeDevWebView::reload_mode(
  self : RuntimeDevWebView,
) -> RuntimeDevReloadMode {
  self.reload_mode
}

///|
pub fn RuntimeDevWebView::asset_protocol(self : RuntimeDevWebView) -> String {
  self.asset_protocol
}

///|
pub fn RuntimeDevWebView::native_hook(self : RuntimeDevWebView) -> String {
  self.native_hook
}

///|
pub fn RuntimeDevWebView::event_dispatch_hook(
  self : RuntimeDevWebView,
) -> String {
  self.event_dispatch_hook
}

///|
pub fn RuntimeDevWebView::local_service(
  self : RuntimeDevWebView,
) -> @lepusa.LocalService? {
  self.local_service
}

///|
pub fn RuntimeDevWebView::requires_supervisor(self : RuntimeDevWebView) -> Bool {
  self.local_service is Some(_)
}

///|
pub fn RuntimeDevWebView::uses_runtime_asset_protocol(
  self : RuntimeDevWebView,
) -> Bool {
  match self.source_kind {
    RuntimeDevInlineAssets
    | RuntimeDevRabbitaAssets
    | RuntimeDevLocalAssets
    | RuntimeDevPackagedAssets => true
    _ => false
  }
}

///|
pub fn RuntimeDevSourceKind::name(self : RuntimeDevSourceKind) -> String {
  match self {
    RuntimeDevInlineAssets => "inline-assets"
    RuntimeDevRabbitaAssets => "rabbita-assets"
    RuntimeDevLocalAssets => "local-assets"
    RuntimeDevPackagedAssets => "packaged-assets"
    RuntimeDevSupervisedLocalhost => "supervised-localhost"
    RuntimeDevExternalUrl => "external-url"
    RuntimeDevCustomUrl => "custom-url"
  }
}

///|
pub fn RuntimeDevReloadMode::name(self : RuntimeDevReloadMode) -> String {
  match self {
    RuntimeDevReloadWindow => "window-reload"
    RuntimeDevReloadExternal => "external"
    RuntimeDevReloadNone => "none"
  }
}

///|
pub fn RuntimeDevCommand::to_json(self : RuntimeDevCommand) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"purpose\":\{self.purpose.json_string()},",
    "\"template\":\{self.template.json_string()},",
    "\"targetRequired\":\{self.target_required.json_bool()}",
    "}",
  ].join("")
}

///|
pub fn RuntimeDevSession::to_json(self : RuntimeDevSession) -> String {
  [
    "{",
    "\"webviews\":[\{self.webviews.map(fn(webview) { webview.to_json() }).join(",")}],",
    "\"servicePlan\":\{self.service_plan.to_json()},",
    "\"reloadEvent\":\{self.reload_event.json_string()},",
    "\"proxyMode\":\{self.proxy_mode.json_string()},",
    "\"requiresSupervisor\":\{self.requires_supervisor().json_bool()},",
    "\"windowReloadCount\":\{self.window_reload_count()},",
    "\"externalReloadCount\":\{self.external_reload_count()}",
    "}",
  ].join("")
}

///|
pub fn RuntimeDevWebView::to_json(self : RuntimeDevWebView) -> String {
  [
    "{",
    "\"label\":\{self.label.json_string()},",
    "\"url\":\{self.url.json_string()},",
    "\"sourceKind\":\{self.source_kind.name().json_string()},",
    "\"reloadMode\":\{self.reload_mode.name().json_string()},",
    "\"assetProtocol\":\{self.asset_protocol.json_string()},",
    "\"nativeHook\":\{self.native_hook.json_string()},",
    "\"eventDispatchHook\":\{self.event_dispatch_hook.json_string()},",
    "\"usesRuntimeAssetProtocol\":\{self.uses_runtime_asset_protocol().json_bool()},",
    "\"requiresSupervisor\":\{self.requires_supervisor().json_bool()},",
    "\"localService\":\{runtime_dev_local_service_json(self.local_service)}",
    "}",
  ].join("")
}

///|
pub fn RuntimeDevPlan::to_json(self : RuntimeDevPlan) -> String {
  [
    "{",
    "\"kind\":\"runtime-dev-plan\",",
    "\"launchManifest\":\{self.launch_manifest.to_json()},",
    "\"session\":\{self.session.to_json()},",
    "\"devSession\":\{self.dev_session.to_json()},",
    "\"webviews\":[\{self.webviews.map(fn(webview) { webview.to_json() }).join(",")}],",
    "\"startupOperations\":[\{self.startup_operations.map(fn(operation) { operation.to_json() }).join(",")}],",
    "\"lifecycleSteps\":[\{self.lifecycle_steps.map(fn(step) { step.to_json() }).join(",")}],",
    "\"bridgeRoutes\":{",
    "\"sync\":[\{self.bridge_sync_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"async\":[\{self.bridge_async_routes.map(fn(route) { route.json_string() }).join(",")}]",
    "},",
    "\"commands\":[\{self.commands.map(fn(command) { command.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn runtime_dev_session(
  webviews : Array[RuntimeWebViewSpec],
  service_plan : RuntimeServicePlan,
) -> RuntimeDevSession {
  {
    webviews: webviews.map(fn(webview) {
      runtime_dev_webview(webview, service_plan)
    }),
    service_plan,
    reload_event: "lepusa:dev-reload",
    proxy_mode: "none",
  }
}

///|
fn runtime_dev_webview(
  webview : RuntimeWebViewSpec,
  service_plan : RuntimeServicePlan,
) -> RuntimeDevWebView {
  let local_service = runtime_dev_local_service_for(
    webview.label(),
    service_plan,
  )
  let source_kind = runtime_dev_source_kind(webview, local_service)
  {
    label: webview.label(),
    url: webview.url(),
    source_kind,
    reload_mode: runtime_dev_reload_mode(source_kind),
    asset_protocol: webview.asset_protocol(),
    native_hook: webview.native_hook(),
    event_dispatch_hook: webview.event_dispatch_hook(),
    local_service,
  }
}

///|
fn runtime_dev_local_service_for(
  label : String,
  service_plan : RuntimeServicePlan,
) -> @lepusa.LocalService? {
  for service in service_plan.services() {
    if service.name() == label {
      return Some(service)
    }
  }
  None
}

///|
fn runtime_dev_source_kind(
  webview : RuntimeWebViewSpec,
  local_service : @lepusa.LocalService?,
) -> RuntimeDevSourceKind {
  let url = webview.url()
  let asset = webview.asset_protocol()
  if url.has_prefix("\{asset}://inline/") {
    RuntimeDevInlineAssets
  } else if url.has_prefix("\{asset}://rabbita/") {
    RuntimeDevRabbitaAssets
  } else if url.has_prefix("\{asset}://local/") {
    RuntimeDevLocalAssets
  } else if url.has_prefix("\{asset}://packaged/") {
    RuntimeDevPackagedAssets
  } else if local_service is Some(_) {
    RuntimeDevSupervisedLocalhost
  } else if url.has_prefix("http://") || url.has_prefix("https://") {
    RuntimeDevExternalUrl
  } else {
    RuntimeDevCustomUrl
  }
}

///|
fn runtime_dev_reload_mode(
  source_kind : RuntimeDevSourceKind,
) -> RuntimeDevReloadMode {
  match source_kind {
    RuntimeDevInlineAssets
    | RuntimeDevRabbitaAssets
    | RuntimeDevLocalAssets
    | RuntimeDevPackagedAssets => RuntimeDevReloadWindow
    RuntimeDevSupervisedLocalhost | RuntimeDevExternalUrl =>
      RuntimeDevReloadExternal
    RuntimeDevCustomUrl => RuntimeDevReloadNone
  }
}

///|
fn runtime_dev_local_service_json(service : @lepusa.LocalService?) -> String {
  match service {
    Some(value) => value.to_json()
    None => "null"
  }
}

///|
fn runtime_dev_commands() -> Array[RuntimeDevCommand] {
  [
    RuntimeDevCommand::new(
      name="inspect",
      purpose="print the resolved runtime plan",
      template="lepusa plan{project}",
    ),
    RuntimeDevCommand::new(
      name="manifest",
      purpose="print the native launch manifest consumed by runtime hosts",
      template="lepusa manifest{project}",
    ),
    RuntimeDevCommand::new(
      name="verify",
      purpose="check runtime, IPC, native launch, and bundle contracts",
      template="lepusa verify {target}{project}",
      target_required=true,
    ),
    RuntimeDevCommand::new(
      name="run",
      purpose="open the native development window for the selected target",
      template="lepusa run {target} --launch{project}",
      target_required=true,
    ),
    RuntimeDevCommand::new(
      name="bundle",
      purpose="materialize a platform bundle for local release testing",
      template="lepusa bundle-write {target} _build/lepusa-{target}{project}",
      target_required=true,
    ),
  ]
}
