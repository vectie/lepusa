///|
pub struct InvokeContract {
  route : String
  plugin : String
  command : String
  mode : CommandMode
  affinity : CommandExecutionAffinity
  permission : Permission
  request_schema : IpcSchema
  response_schema : IpcSchema
  allowed_windows : Array[String]
  allowed_origins : Array[String]
  requires_registered_handler : Bool
  registered : Bool
  registered_mode : CommandMode?
  registered_permission : Permission?
  exposed : Bool
  operation_scope_configured : Bool
  operation_scope_required : Bool
  problems : Array[String]
} derive(Debug, Eq)

///|
pub struct InvokeContractReport {
  contracts : Array[InvokeContract]
  undeclared_routes : Array[String]
  duplicate_routes : Array[String]
  problems : Array[String]
} derive(Debug, Eq)

///|
pub fn CommandRegistry::invoke_contracts(
  self : CommandRegistry,
  profile : SecurityProfile,
) -> Array[InvokeContract] {
  profile
  .command_manifest()
  .entries()
  .map(fn(entry) {
    InvokeContract::from_entry(profile, entry, self.commands.get(entry.route()))
  })
}

///|
pub fn CommandRegistry::invoke_contract(
  self : CommandRegistry,
  profile : SecurityProfile,
  route : String,
) -> InvokeContract? {
  for contract in self.invoke_contracts(profile) {
    if contract.route() == route {
      return Some(contract)
    }
  }
  None
}

///|
pub fn CommandRegistry::invoke_contract_report(
  self : CommandRegistry,
  profile : SecurityProfile,
) -> InvokeContractReport {
  InvokeContractReport::from_registry(self, profile)
}

///|
pub fn AppManager::invoke_contracts(self : AppManager) -> Array[InvokeContract] {
  self.registry.invoke_contracts(self.security_profile())
}

///|
pub fn AppManager::invoke_contract_report(
  self : AppManager,
) -> InvokeContractReport {
  self.registry.invoke_contract_report(self.security_profile())
}

///|
fn InvokeContract::from_entry(
  profile : SecurityProfile,
  entry : CommandManifestEntry,
  command : RegisteredCommand?,
) -> InvokeContract {
  let problems : Array[String] = []
  let requires_registered_handler = entry.mode().requires_registered_handler()
  let registered = command is Some(_)
  let operation_scope_configured = invoke_contract_operation_scope_configured(
    profile, entry,
  )
  let mut registered_mode : CommandMode? = None
  let mut registered_permission : Permission? = None
  let mut operation_scope_required = false
  if entry.allowed_windows().is_empty() {
    problems.push(
      "command has no capability grant for any window: \{entry.route()}",
    )
  }
  for problem in entry.request_schema().validate() {
    problems.push("request schema invalid for \{entry.route()}: \{problem}")
  }
  for problem in entry.response_schema().validate() {
    problems.push("response schema invalid for \{entry.route()}: \{problem}")
  }
  match command {
    None =>
      if requires_registered_handler {
        problems.push(
          "command has no registered native handler: \{entry.route()}",
        )
      }
    Some(command) => {
      registered_mode = Some(command.mode())
      registered_permission = Some(command.permission())
      operation_scope_required = command.requires_operation_scope()
      if command.mode() != entry.mode() {
        problems.push(
          "registered handler mode mismatch for \{entry.route()}: expected \{entry.mode().name()} got \{command.mode().name()}",
        )
      }
      if command.permission() != entry.permission() {
        problems.push(
          "registered handler permission mismatch for \{entry.route()}: expected \{entry.permission().name()} got \{command.permission().name()}",
        )
      }
      if operation_scope_configured && !operation_scope_required {
        problems.push(
          "command has scoped capability grants but registered handler does not resolve an operation scope: \{entry.route()}",
        )
      }
    }
  }
  {
    route: entry.route(),
    plugin: entry.plugin(),
    command: entry.command(),
    mode: entry.mode(),
    affinity: entry.affinity(),
    permission: entry.permission(),
    request_schema: entry.request_schema(),
    response_schema: entry.response_schema(),
    allowed_windows: entry.allowed_windows(),
    allowed_origins: entry.allowed_origins(),
    requires_registered_handler,
    registered,
    registered_mode,
    registered_permission,
    exposed: invoke_contract_exposed(profile, entry.route()),
    operation_scope_configured,
    operation_scope_required,
    problems,
  }
}

///|
pub fn InvokeContract::route(self : InvokeContract) -> String {
  self.route
}

///|
pub fn InvokeContract::plugin(self : InvokeContract) -> String {
  self.plugin
}

///|
pub fn InvokeContract::command(self : InvokeContract) -> String {
  self.command
}

///|
pub fn InvokeContract::mode(self : InvokeContract) -> CommandMode {
  self.mode
}

///|
pub fn InvokeContract::affinity(
  self : InvokeContract,
) -> CommandExecutionAffinity {
  self.affinity
}

///|
pub fn InvokeContract::permission(self : InvokeContract) -> Permission {
  self.permission
}

///|
pub fn InvokeContract::request_schema(self : InvokeContract) -> IpcSchema {
  self.request_schema
}

///|
pub fn InvokeContract::response_schema(self : InvokeContract) -> IpcSchema {
  self.response_schema
}

///|
pub fn InvokeContract::allowed_windows(self : InvokeContract) -> Array[String] {
  self.allowed_windows.copy()
}

///|
pub fn InvokeContract::allowed_origins(self : InvokeContract) -> Array[String] {
  self.allowed_origins.copy()
}

///|
pub fn InvokeContract::requires_registered_handler(
  self : InvokeContract,
) -> Bool {
  self.requires_registered_handler
}

///|
pub fn InvokeContract::registered(self : InvokeContract) -> Bool {
  self.registered
}

///|
pub fn InvokeContract::registered_mode(self : InvokeContract) -> CommandMode? {
  self.registered_mode
}

///|
pub fn InvokeContract::registered_permission(
  self : InvokeContract,
) -> Permission? {
  self.registered_permission
}

///|
pub fn InvokeContract::exposed(self : InvokeContract) -> Bool {
  self.exposed
}

///|
pub fn InvokeContract::operation_scope_configured(
  self : InvokeContract,
) -> Bool {
  self.operation_scope_configured
}

///|
pub fn InvokeContract::operation_scope_required(self : InvokeContract) -> Bool {
  self.operation_scope_required
}

///|
pub fn InvokeContract::problems(self : InvokeContract) -> Array[String] {
  self.problems.copy()
}

///|
pub fn InvokeContract::ok(self : InvokeContract) -> Bool {
  self.problems.is_empty()
}

///|
pub fn InvokeContract::dispatchable(self : InvokeContract) -> Bool {
  self.ok() &&
  self.exposed &&
  (!self.requires_registered_handler || self.registered)
}

///|
pub fn InvokeContract::to_json(self : InvokeContract) -> String {
  [
    "{",
    "\"route\":\{self.route.json_string()},",
    "\"plugin\":\{self.plugin.json_string()},",
    "\"command\":\{self.command.json_string()},",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"affinity\":\{self.affinity.name().json_string()},",
    "\"permission\":\{self.permission.name().json_string()},",
    "\"requestSchema\":\{self.request_schema.to_json()},",
    "\"responseSchema\":\{self.response_schema.to_json()},",
    "\"allowedWindows\":[\{self.allowed_windows.map(fn(window) { window.json_string() }).join(",")}],",
    "\"allowedOrigins\":[\{self.allowed_origins.map(fn(origin) { origin.json_string() }).join(",")}],",
    "\"requiresRegisteredHandler\":\{self.requires_registered_handler.json_bool()},",
    "\"registered\":\{self.registered.json_bool()},",
    "\"registeredMode\":\{invoke_contract_mode_json(self.registered_mode)},",
    "\"registeredPermission\":\{invoke_contract_permission_json(self.registered_permission)},",
    "\"exposed\":\{self.exposed.json_bool()},",
    "\"operationScopeConfigured\":\{self.operation_scope_configured.json_bool()},",
    "\"operationScopeRequired\":\{self.operation_scope_required.json_bool()},",
    "\"ok\":\{self.ok().json_bool()},",
    "\"dispatchable\":\{self.dispatchable().json_bool()},",
    "\"problems\":[\{self.problems.map(fn(problem) { problem.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn InvokeContractReport::from_registry(
  registry : CommandRegistry,
  profile : SecurityProfile,
) -> InvokeContractReport {
  let contracts = registry.invoke_contracts(profile)
  let undeclared_routes : Array[String] = []
  let problems : Array[String] = []
  let declared_routes = profile.command_manifest().routes()
  for route in registry.routes() {
    if !declared_routes.contains(route) {
      undeclared_routes.push(route)
      invoke_contract_push_unique(
        problems,
        "registered handler is not declared in command manifest: \{route}",
      )
    }
  }
  for route in registry.duplicate_routes {
    invoke_contract_push_unique(
      problems,
      "registered command route must be unique: \{route}",
    )
  }
  for problem in registry.validate() {
    invoke_contract_push_unique(problems, problem)
  }
  {
    contracts,
    undeclared_routes,
    duplicate_routes: registry.duplicate_routes.copy(),
    problems,
  }
}

///|
pub fn InvokeContractReport::contracts(
  self : InvokeContractReport,
) -> Array[InvokeContract] {
  self.contracts.copy()
}

///|
pub fn InvokeContractReport::undeclared_routes(
  self : InvokeContractReport,
) -> Array[String] {
  self.undeclared_routes.copy()
}

///|
pub fn InvokeContractReport::duplicate_routes(
  self : InvokeContractReport,
) -> Array[String] {
  self.duplicate_routes.copy()
}

///|
pub fn InvokeContractReport::problems(
  self : InvokeContractReport,
) -> Array[String] {
  let problems = self.problems.copy()
  for contract in self.contracts {
    for problem in contract.problems() {
      invoke_contract_push_unique(problems, problem)
    }
  }
  problems
}

///|
pub fn InvokeContractReport::ok(self : InvokeContractReport) -> Bool {
  self.problems.is_empty() && self.contracts.all(fn(contract) { contract.ok() })
}

///|
pub fn InvokeContractReport::dispatchable_routes(
  self : InvokeContractReport,
) -> Array[String] {
  self.contracts
  .filter(fn(contract) { contract.dispatchable() })
  .map(fn(contract) { contract.route() })
}

///|
pub fn InvokeContractReport::to_json(self : InvokeContractReport) -> String {
  [
    "{",
    "\"ok\":\{self.ok().json_bool()},",
    "\"dispatchableRoutes\":[\{self.dispatchable_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"undeclaredRoutes\":[\{self.undeclared_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"duplicateRoutes\":[\{self.duplicate_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"problems\":[\{self.problems().map(fn(problem) { problem.json_string() }).join(",")}],",
    "\"contracts\":[\{self.contracts.map(fn(contract) { contract.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn invoke_contract_exposed(profile : SecurityProfile, route : String) -> Bool {
  profile.exposed_routes().contains(route)
}

///|
fn invoke_contract_operation_scope_configured(
  profile : SecurityProfile,
  entry : CommandManifestEntry,
) -> Bool {
  match profile.permission_manifest().permission(entry.permission().name()) {
    Some(permission) =>
      permission
      .grants()
      .any(fn(grant) { !grant.operation_scopes().is_empty() })
    None => false
  }
}

///|
fn invoke_contract_mode_json(mode : CommandMode?) -> String {
  match mode {
    Some(mode) => mode.name().json_string()
    None => "null"
  }
}

///|
fn invoke_contract_permission_json(permission : Permission?) -> String {
  match permission {
    Some(permission) => permission.name().json_string()
    None => "null"
  }
}

///|
fn invoke_contract_push_unique(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}
