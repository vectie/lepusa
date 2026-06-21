///|
pub struct FrontendApiConfig {
  global_name : String
  module_name : String
} derive(Debug, Eq)

///|
pub struct FrontendApiBundle {
  config : FrontendApiConfig
  command_manifest : @lepusa.CommandManifest
  invoke_contract_report : @lepusa.InvokeContractReport?
  javascript : String
  typescript : String
} derive(Debug, Eq)

///|
pub fn FrontendApiConfig::new(
  global_name? : String = "lepusa",
  module_name? : String = "lepusa-api",
) -> FrontendApiConfig {
  { global_name, module_name }
}

///|
pub fn FrontendApiConfig::global_name(self : FrontendApiConfig) -> String {
  self.global_name
}

///|
pub fn FrontendApiConfig::module_name(self : FrontendApiConfig) -> String {
  self.module_name
}

///|
pub fn FrontendApiConfig::validate(self : FrontendApiConfig) -> Array[String] {
  let problems : Array[String] = []
  if self.global_name == "" {
    problems.push("frontend api global name is required")
  }
  if self.module_name == "" {
    problems.push("frontend api module name is required")
  }
  problems
}

///|
pub fn FrontendApiBundle::from_runtime_plan(
  plan : @lepusa.RuntimePlan,
  config? : FrontendApiConfig = FrontendApiConfig::new(),
) -> Result[FrontendApiBundle, Array[String]] {
  FrontendApiBundle::from_command_manifest(
    frontend_invokable_manifest(plan.command_manifest()),
    config~,
  )
}

///|
pub fn FrontendApiBundle::from_launch_manifest(
  manifest : @lepusa.RuntimeLaunchManifest,
  config? : FrontendApiConfig = FrontendApiConfig::new(),
) -> Result[FrontendApiBundle, Array[String]] {
  FrontendApiBundle::from_command_manifest(
    frontend_invokable_manifest(
      manifest.command_manifest(),
      registered_routes=manifest.registered_routes(),
      restrict_registered=true,
    ),
    config~,
  )
}

///|
pub fn FrontendApiBundle::from_command_manifest(
  manifest : @lepusa.CommandManifest,
  config? : FrontendApiConfig = FrontendApiConfig::new(),
) -> Result[FrontendApiBundle, Array[String]] {
  FrontendApiBundle::build(manifest, report=None, config~)
}

///|
pub fn FrontendApiBundle::from_invoke_contract_report(
  manifest : @lepusa.CommandManifest,
  report : @lepusa.InvokeContractReport,
  config? : FrontendApiConfig = FrontendApiConfig::new(),
) -> Result[FrontendApiBundle, Array[String]] {
  FrontendApiBundle::build(
    frontend_manifest_for_contract_report(manifest, report),
    report=Some(report),
    config~,
  )
}

///|
fn FrontendApiBundle::build(
  manifest : @lepusa.CommandManifest,
  report~ : @lepusa.InvokeContractReport?,
  config~ : FrontendApiConfig,
) -> Result[FrontendApiBundle, Array[String]] {
  let problems = config.validate()
  if !problems.is_empty() {
    return Err(problems)
  }
  Ok({
    config,
    command_manifest: manifest,
    invoke_contract_report: report,
    javascript: frontend_api_javascript(manifest, report, config),
    typescript: frontend_api_typescript(manifest, report, config),
  })
}

///|
pub fn FrontendApiBundle::config(self : FrontendApiBundle) -> FrontendApiConfig {
  self.config
}

///|
pub fn FrontendApiBundle::command_manifest(
  self : FrontendApiBundle,
) -> @lepusa.CommandManifest {
  self.command_manifest
}

///|
pub fn FrontendApiBundle::invoke_contract_report(
  self : FrontendApiBundle,
) -> @lepusa.InvokeContractReport? {
  self.invoke_contract_report
}

///|
pub fn FrontendApiBundle::javascript(self : FrontendApiBundle) -> String {
  self.javascript
}

///|
pub fn FrontendApiBundle::typescript(self : FrontendApiBundle) -> String {
  self.typescript
}

///|
pub fn FrontendApiBundle::to_json(self : FrontendApiBundle) -> String {
  [
    "{",
    "\"moduleName\":\{self.config.module_name().json_literal()},",
    "\"globalName\":\{self.config.global_name().json_literal()},",
    "\"commandManifest\":\{self.command_manifest.to_json()},",
    "\"invokeContractReport\":\{frontend_contract_report_json(self.invoke_contract_report)},",
    "\"javascript\":\{self.javascript.json_literal()},",
    "\"typescript\":\{self.typescript.json_literal()}",
    "}",
  ].join("")
}

///|
fn frontend_api_javascript(
  manifest : @lepusa.CommandManifest,
  report : @lepusa.InvokeContractReport?,
  config : FrontendApiConfig,
) -> String {
  let route_literals = manifest
    .routes()
    .map(fn(route) { route.json_literal() })
    .join(", ")
  let export_aliases : Array[String] = []
  for plugin in manifest_plugins(manifest) {
    if plugin.is_js_identifier() && !plugin.is_js_reserved_word() {
      export_aliases.push(
        "export const \{plugin} = commands[\{plugin.json_literal()}];",
      )
    }
  }
  [
    "const globalName = \{config.global_name().json_literal()};",
    "const routeList = [\{route_literals}];",
    "const getApi = () => {",
    "  const api = globalThis[globalName];",
    "  if (!api) {",
    "    throw new Error(`Missing Lepusa frontend bridge: ${globalName}`);",
    "  }",
    "  return api;",
    "};",
    "",
    "export const commandManifest = \{manifest.to_json()};",
    "export const invokeContractReport = \{frontend_contract_report_json(report)};",
    "export const routes = Object.freeze(routeList.slice());",
    "export const can = (route) => getApi().can(route);",
    "export const invoke = (route, payload = null, options = {}) => getApi().invoke(route, payload, options);",
    "export const stream = (route, payload = null, options = {}) => getApi().stream(route, payload, options);",
    "export const drainStream = (channelId, options = {}) => getApi().drainStream(channelId, options);",
    "export const cancelStream = (channelId, options = {}) => getApi().cancelStream(channelId, options);",
    "export const closeResource = (resource, options = {}) => getApi().closeResource(resource, options);",
    "export const isInvokeError = (error) => getApi().isInvokeError(error);",
    "export const listen = (name, handler) => getApi().listen(name, handler);",
    "export const unlisten = (name, handler) => getApi().unlisten(name, handler);",
    "export const emit = (name, payload = null) => getApi().emit(name, payload);",
    "export const emitTo = (target, name, payload = null) => getApi().emitTo(target, name, payload);",
    "export const command = (route) => getApi().command(route);",
    "",
    "const makeInvoker = (route) => (payload = null, options = {}) => invoke(route, payload, options);",
    "const commandTree = {};",
    "for (const route of routeList) {",
    "  const parts = route.split('.').filter(Boolean);",
    "  const leaf = parts.pop();",
    "  let scope = commandTree;",
    "  for (const part of parts) {",
    "    scope = scope[part] ||= {};",
    "  }",
    "  scope[leaf] = makeInvoker(route);",
    "}",
    "",
    "const freezeTree = (value) => {",
    "  if (!value || typeof value !== 'object' || Object.isFrozen(value)) {",
    "    return value;",
    "  }",
    "  for (const key of Object.keys(value)) {",
    "    freezeTree(value[key]);",
    "  }",
    "  return Object.freeze(value);",
    "};",
    "",
    "export const commands = freezeTree(commandTree);",
    export_aliases.join("\n"),
    "",
    "export default Object.freeze({",
    "  commandManifest,",
    "  invokeContractReport,",
    "  routes,",
    "  can,",
    "  invoke,",
    "  stream,",
    "  drainStream,",
    "  cancelStream,",
    "  closeResource,",
    "  isInvokeError,",
    "  listen,",
    "  unlisten,",
    "  emit,",
    "  emitTo,",
    "  command,",
    "  commands,",
    "});",
    "",
  ]
  .filter(fn(line) { line != "" })
  .join("\n") +
  "\n"
}

///|
fn frontend_invokable_manifest(
  manifest : @lepusa.CommandManifest,
  registered_routes? : Array[String] = [],
  restrict_registered? : Bool = false,
) -> @lepusa.CommandManifest {
  let entries : Array[@lepusa.CommandManifestEntry] = []
  for entry in manifest.entries() {
    if entry.allowed_windows().is_empty() {
      continue
    }
    if entry.mode() is Event {
      continue
    }
    if restrict_registered && !registered_routes.contains(entry.route()) {
      continue
    }
    entries.push(entry)
  }
  @lepusa.CommandManifest::new(entries~)
}

///|
fn frontend_manifest_for_contract_report(
  manifest : @lepusa.CommandManifest,
  report : @lepusa.InvokeContractReport,
) -> @lepusa.CommandManifest {
  let dispatchable_routes = report.dispatchable_routes()
  let entries : Array[@lepusa.CommandManifestEntry] = []
  for entry in manifest.entries() {
    if dispatchable_routes.contains(entry.route()) {
      entries.push(entry)
    }
  }
  @lepusa.CommandManifest::new(entries~)
}

///|
fn frontend_api_typescript(
  manifest : @lepusa.CommandManifest,
  report : @lepusa.InvokeContractReport?,
  config : FrontendApiConfig,
) -> String {
  let route_union = if manifest.routes().is_empty() {
    "string"
  } else {
    manifest.routes().map(fn(route) { route.json_literal() }).join(" | ")
  }
  let command_tree = typescript_command_tree(manifest)
  let export_aliases : Array[String] = []
  for plugin in manifest_plugins(manifest) {
    if plugin.is_js_identifier() && !plugin.is_js_reserved_word() {
      export_aliases.push(
        "export declare const \{plugin}: typeof commands[\{plugin.json_literal()}];",
      )
    }
  }
  [
    "// Generated Lepusa frontend API declarations for \{config.module_name()}",
    "export type LepusaRoute = \{route_union};",
    "export type LepusaPayload = unknown;",
    "export type LepusaAbortSignal = { readonly aborted: boolean; addEventListener?: (type: \"abort\", listener: () => void, options?: { once?: boolean }) => void; removeEventListener?: (type: \"abort\", listener: () => void) => void };",
    "export type LepusaInvokeOptions = { signal?: LepusaAbortSignal | null; timeoutMs?: number };",
    "export type LepusaInvokeErrorCode = \"invalid-request\" | \"unknown-command\" | \"permission-denied\" | \"async-required\" | \"handler-error\" | \"transport-error\" | \"timeout\" | \"cancelled\" | string;",
    "export type LepusaInvokeFailure = { code: LepusaInvokeErrorCode; message: string; route?: string | null };",
    "export interface LepusaInvokeError extends Error { name: \"LepusaInvokeError\"; code: LepusaInvokeErrorCode; route: string; id: string; failure: LepusaInvokeFailure | null; response: unknown; }",
    "export type LepusaResourceHandle = { id: string; kind: string; owner: string; name: string };",
    "export type LepusaChannelMessageKind = \"data\" | \"error\" | \"end\" | \"cancel\";",
    "export type LepusaChannelMessage = { channelId: string; sequence: number; kind: LepusaChannelMessageKind; payload: string };",
    "export type LepusaStreamDrain = { channelId: string; messages: readonly LepusaChannelMessage[] };",
    "export type LepusaStreamCancel = { channelId: string; message: LepusaChannelMessage };",
    "export type LepusaResourceClose = { closed: LepusaResourceHandle & { sequence?: number; metadata?: string; closed?: boolean } };",
    "export type LepusaStream = { kind: \"stream\"; route: string; channelId: string; channel: LepusaResourceHandle | null; drain(options?: LepusaInvokeOptions): Promise<LepusaStreamDrain>; cancel(options?: LepusaInvokeOptions): Promise<LepusaStreamCancel>; close(options?: LepusaInvokeOptions): Promise<LepusaResourceClose> };",
    "export type LepusaEventTarget = { kind: \"app\" } | { kind: \"window\"; label: string } | { kind: \"webview\"; label: string } | string;",
    "export type LepusaEvent = { name: string; payload?: string };",
    "export type LepusaUnlisten = () => boolean;",
    "export type LepusaEventHandler = (payload: unknown, event: LepusaEvent) => void;",
    "export type LepusaInvokeContractReport = { ok: boolean; dispatchableRoutes: readonly string[]; undeclaredRoutes: readonly string[]; duplicateRoutes: readonly string[]; problems: readonly string[]; contracts: readonly unknown[] };",
    "export type LepusaCommandPayloads = \{typescript_command_schema_map(manifest, request=true)};",
    "export type LepusaCommandResponses = \{typescript_command_schema_map(manifest, request=false)};",
    "export type LepusaPayloadFor<Route extends string> = Route extends keyof LepusaCommandPayloads ? LepusaCommandPayloads[Route] : LepusaPayload;",
    "export type LepusaResponseFor<Route extends string> = Route extends keyof LepusaCommandResponses ? LepusaCommandResponses[Route] : unknown;",
    "",
    "export declare const commandManifest: \{manifest.to_json()};",
    "export declare const invokeContractReport: \{frontend_contract_report_type(report)};",
    "export declare const routes: readonly LepusaRoute[];",
    "export declare function can(route: string): boolean;",
    "export declare function invoke<Route extends LepusaRoute>(route: Route, payload?: LepusaPayloadFor<Route>, options?: LepusaInvokeOptions): Promise<LepusaResponseFor<Route>>;",
    "export declare function stream<Route extends LepusaRoute>(route: Route, payload?: LepusaPayloadFor<Route>, options?: LepusaInvokeOptions): Promise<LepusaStream>;",
    "export declare function drainStream(channelId: string, options?: LepusaInvokeOptions): Promise<LepusaStreamDrain>;",
    "export declare function cancelStream(channelId: string, options?: LepusaInvokeOptions): Promise<LepusaStreamCancel>;",
    "export declare function closeResource(resource: string | LepusaResourceHandle, options?: LepusaInvokeOptions): Promise<LepusaResourceClose>;",
    "export declare function isInvokeError(error: unknown): error is LepusaInvokeError;",
    "export declare function listen(name: string, handler: LepusaEventHandler): LepusaUnlisten;",
    "export declare function unlisten(name: string, handler: LepusaEventHandler): boolean;",
    "export declare function emit(name: string, payload?: LepusaPayload): Promise<number>;",
    "export declare function emitTo(target: LepusaEventTarget, name: string, payload?: LepusaPayload): Promise<number>;",
    "export declare function command<Route extends LepusaRoute>(route: Route): (payload?: LepusaPayloadFor<Route>, options?: LepusaInvokeOptions) => Promise<LepusaResponseFor<Route>>;",
    "export declare const commands: \{command_tree};",
    export_aliases.join("\n"),
    "",
    "declare const api: {",
    "  commandManifest: typeof commandManifest;",
    "  invokeContractReport: typeof invokeContractReport;",
    "  routes: typeof routes;",
    "  can: typeof can;",
    "  invoke: typeof invoke;",
    "  stream: typeof stream;",
    "  drainStream: typeof drainStream;",
    "  cancelStream: typeof cancelStream;",
    "  closeResource: typeof closeResource;",
    "  isInvokeError: typeof isInvokeError;",
    "  listen: typeof listen;",
    "  unlisten: typeof unlisten;",
    "  emit: typeof emit;",
    "  emitTo: typeof emitTo;",
    "  command: typeof command;",
    "  commands: typeof commands;",
    "};",
    "export default api;",
    "",
  ]
  .filter(fn(line) { line != "" })
  .join("\n") +
  "\n"
}

///|
fn typescript_command_tree(manifest : @lepusa.CommandManifest) -> String {
  if manifest.entries().is_empty() {
    return "Record<string, never>"
  }
  let plugin_blocks : Array[String] = []
  for plugin in manifest_plugins(manifest) {
    let command_lines : Array[String] = []
    for entry in manifest.entries() {
      if entry.plugin() == plugin {
        command_lines.push(
          "    \{entry.command().typescript_property_name()}: (payload?: \{entry.request_schema().typescript()}, options?: LepusaInvokeOptions) => Promise<\{typescript_entry_response(entry)}>;",
        )
      }
    }
    plugin_blocks.push(
      "  \{plugin.typescript_property_name()}: {\n\{command_lines.join("\n")}\n  };",
    )
  }
  "{\n\{plugin_blocks.join("\n")}\n}"
}

///|
fn typescript_command_schema_map(
  manifest : @lepusa.CommandManifest,
  request~ : Bool,
) -> String {
  if manifest.entries().is_empty() {
    return "{}"
  }
  let lines : Array[String] = []
  for entry in manifest.entries() {
    let value = if request {
      entry.request_schema().typescript()
    } else {
      typescript_entry_response(entry)
    }
    lines.push("  \{entry.route().json_literal()}: \{value};")
  }
  "{\n\{lines.join("\n")}\n}"
}

///|
fn typescript_entry_response(entry : @lepusa.CommandManifestEntry) -> String {
  if entry.mode() is Stream {
    "LepusaStream"
  } else {
    entry.response_schema().typescript()
  }
}

///|
fn frontend_contract_report_json(
  report : @lepusa.InvokeContractReport?,
) -> String {
  match report {
    Some(report) => report.to_json()
    None => "null"
  }
}

///|
fn frontend_contract_report_type(
  report : @lepusa.InvokeContractReport?,
) -> String {
  match report {
    Some(_) => "LepusaInvokeContractReport"
    None => "LepusaInvokeContractReport | null"
  }
}

///|
fn manifest_plugins(manifest : @lepusa.CommandManifest) -> Array[String] {
  let plugins : Array[String] = []
  for entry in manifest.entries() {
    if !plugins.contains(entry.plugin()) {
      plugins.push(entry.plugin())
    }
  }
  plugins
}

///|
fn String::typescript_property_name(self : String) -> String {
  if self.is_js_identifier() && !self.is_js_reserved_word() {
    self
  } else {
    self.json_literal()
  }
}

///|
fn String::is_js_identifier(self : String) -> Bool {
  if self == "" {
    return false
  }
  let chars = self.to_array()
  match chars.get(0) {
    Some(first) => if !first.is_js_identifier_start() { return false }
    None => return false
  }
  for index in 1..<chars.length() {
    match chars.get(index) {
      Some(char) => if !char.is_js_identifier_part() { return false }
      None => ()
    }
  }
  true
}

///|
fn Char::is_js_identifier_start(self : Char) -> Bool {
  self == '_' ||
  self == '$' ||
  (self >= 'a' && self <= 'z') ||
  (self >= 'A' && self <= 'Z')
}

///|
fn Char::is_js_identifier_part(self : Char) -> Bool {
  self.is_js_identifier_start() || (self >= '0' && self <= '9')
}

///|
fn String::is_js_reserved_word(self : String) -> Bool {
  [
    "await", "break", "case", "catch", "class", "const", "continue", "debugger",
    "default", "delete", "do", "else", "enum", "export", "extends", "false", "finally",
    "for", "function", "if", "import", "in", "instanceof", "new", "null", "return",
    "super", "switch", "this", "throw", "true", "try", "typeof", "var", "void", "while",
    "with", "yield",
  ].contains(self)
}

///|
fn String::json_literal(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
