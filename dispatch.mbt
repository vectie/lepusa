///|
pub type CommandHandler = (String) -> Result[String, String]

///|
pub type AsyncCommandHandler = async (String) -> Result[String, String]

///|
enum RegisteredCommandHandler {
  SyncCommandHandler(CommandHandler)
  AsyncCommandHandler(AsyncCommandHandler)
}

///|
pub struct RegisteredCommand {
  route : String
  permission : Permission
  handler : RegisteredCommandHandler
}

///|
pub fn RegisteredCommand::new(
  route : String,
  permission? : Permission = Permission::command(route),
  handler~ : CommandHandler,
) -> RegisteredCommand {
  { route, permission, handler: SyncCommandHandler(handler) }
}

///|
pub fn RegisteredCommand::new_async(
  route : String,
  permission? : Permission = Permission::command(route),
  handler~ : AsyncCommandHandler,
) -> RegisteredCommand {
  { route, permission, handler: AsyncCommandHandler(handler) }
}

///|
pub fn RegisteredCommand::route(self : RegisteredCommand) -> String {
  self.route
}

///|
pub fn RegisteredCommand::permission(self : RegisteredCommand) -> Permission {
  self.permission
}

///|
pub fn RegisteredCommand::mode(self : RegisteredCommand) -> CommandMode {
  match self.handler {
    SyncCommandHandler(_) => Sync
    AsyncCommandHandler(_) => Async
  }
}

///|
pub struct CommandRegistry {
  commands : Map[String, RegisteredCommand]
  duplicate_routes : Array[String]
}

///|
pub fn CommandRegistry::new() -> CommandRegistry {
  { commands: {}, duplicate_routes: [] }
}

///|
pub fn CommandRegistry::register(
  self : CommandRegistry,
  command : RegisteredCommand,
) -> CommandRegistry {
  let commands = self.commands.copy()
  let duplicate_routes = self.duplicate_routes.copy()
  let route = command.route()
  if route != "" && commands.contains(route) {
    if !duplicate_routes.contains(route) {
      duplicate_routes.push(route)
    }
  } else {
    commands[route] = command
  }
  { commands, duplicate_routes }
}

///|
pub fn CommandRegistry::register_fn(
  self : CommandRegistry,
  route : String,
  permission? : Permission = Permission::command(route),
  handler~ : CommandHandler,
) -> CommandRegistry {
  self.register(RegisteredCommand::new(route, permission~, handler~))
}

///|
pub fn CommandRegistry::register_async_fn(
  self : CommandRegistry,
  route : String,
  permission? : Permission = Permission::command(route),
  handler~ : AsyncCommandHandler,
) -> CommandRegistry {
  self.register(RegisteredCommand::new_async(route, permission~, handler~))
}

///|
pub fn CommandRegistry::merge(
  self : CommandRegistry,
  other : CommandRegistry,
) -> CommandRegistry {
  let mut merged = self
  other.commands.each(fn(_, command) { merged = merged.register(command) })
  let duplicate_routes = merged.duplicate_routes.copy()
  for route in other.duplicate_routes {
    if !duplicate_routes.contains(route) {
      duplicate_routes.push(route)
    }
  }
  { ..merged, duplicate_routes, }
}

///|
pub fn CommandRegistry::contains(
  self : CommandRegistry,
  route : String,
) -> Bool {
  self.commands.contains(route)
}

///|
pub fn CommandRegistry::routes(self : CommandRegistry) -> Array[String] {
  let routes : Array[String] = []
  self.commands.each(fn(route, _) { routes.push(route) })
  routes.sort()
  routes
}

///|
pub fn CommandRegistry::async_routes(self : CommandRegistry) -> Array[String] {
  self.routes_by_mode(Async)
}

///|
pub fn CommandRegistry::sync_routes(self : CommandRegistry) -> Array[String] {
  self.routes_by_mode(Sync)
}

///|
fn CommandRegistry::routes_by_mode(
  self : CommandRegistry,
  mode : CommandMode,
) -> Array[String] {
  let routes : Array[String] = []
  self.commands.each(fn(route, command) {
    if command.mode() == mode {
      routes.push(route)
    }
  })
  routes.sort()
  routes
}

///|
pub fn CommandRegistry::validate(self : CommandRegistry) -> Array[String] {
  let problems : Array[String] = []
  self.commands.each(fn(route, command) {
    if route == "" {
      problems.push("registered command route is required")
    }
    if command.route() != route {
      problems.push("registered command route mismatch: \{route}")
    }
  })
  for route in self.duplicate_routes {
    problems.push("registered command route must be unique: \{route}")
  }
  problems
}

///|
pub fn CommandRegistry::dispatch(
  self : CommandRegistry,
  request : InvokeRequest,
  capabilities? : Array[Capability] = [],
) -> InvokeResponse {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return InvokeResponse::invalid_request(request.id(), request_problems[0])
  }
  let route = request.route()
  match self.commands.get(route) {
    None => InvokeResponse::unknown_command(request.id(), route)
    Some(command) =>
      dispatch_command(
        request,
        command,
        permission=command.permission(),
        capabilities,
      )
  }
}

///|
pub fn CommandRegistry::dispatch_with_permission(
  self : CommandRegistry,
  request : InvokeRequest,
  permission~ : Permission,
  capabilities? : Array[Capability] = [],
) -> InvokeResponse {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return InvokeResponse::invalid_request(request.id(), request_problems[0])
  }
  let route = request.route()
  match self.commands.get(route) {
    None => InvokeResponse::unknown_command(request.id(), route)
    Some(command) =>
      dispatch_command(request, command, permission~, capabilities)
  }
}

///|
pub fn CommandRegistry::dispatch_with_profile(
  self : CommandRegistry,
  profile : SecurityProfile,
  request : InvokeRequest,
) -> InvokeResponse {
  let authorization = profile.authorize_invoke(request)
  if !authorization.allowed() {
    return authorization.to_response(request.id())
  }
  match self.commands.get(request.route()) {
    None => InvokeResponse::unknown_command(request.id(), request.route())
    Some(command) => execute_command(request, command)
  }
}

///|
pub async fn CommandRegistry::dispatch_async(
  self : CommandRegistry,
  request : InvokeRequest,
  capabilities? : Array[Capability] = [],
) -> InvokeResponse {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return InvokeResponse::invalid_request(request.id(), request_problems[0])
  }
  let route = request.route()
  match self.commands.get(route) {
    None => InvokeResponse::unknown_command(request.id(), route)
    Some(command) =>
      dispatch_command_async(
        request,
        command,
        permission=command.permission(),
        capabilities,
      )
  }
}

///|
pub async fn CommandRegistry::dispatch_with_permission_async(
  self : CommandRegistry,
  request : InvokeRequest,
  permission~ : Permission,
  capabilities? : Array[Capability] = [],
) -> InvokeResponse {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return InvokeResponse::invalid_request(request.id(), request_problems[0])
  }
  let route = request.route()
  match self.commands.get(route) {
    None => InvokeResponse::unknown_command(request.id(), route)
    Some(command) =>
      dispatch_command_async(request, command, permission~, capabilities)
  }
}

///|
pub async fn CommandRegistry::dispatch_with_profile_async(
  self : CommandRegistry,
  profile : SecurityProfile,
  request : InvokeRequest,
) -> InvokeResponse {
  let authorization = profile.authorize_invoke(request)
  if !authorization.allowed() {
    return authorization.to_response(request.id())
  }
  match self.commands.get(request.route()) {
    None => InvokeResponse::unknown_command(request.id(), request.route())
    Some(command) => execute_command_async(request, command)
  }
}

///|
fn dispatch_command(
  request : InvokeRequest,
  command : RegisteredCommand,
  permission~ : Permission,
  capabilities : Array[Capability],
) -> InvokeResponse {
  let route = request.route()
  let policy = CapabilityPolicy::new(capabilities~)
  if !policy.allows(
      window_label=request.window_label(),
      permission~,
      origin=request.origin(),
    ) {
    InvokeResponse::permission_denied(request.id(), route)
  } else {
    execute_command(request, command)
  }
}

///|
async fn dispatch_command_async(
  request : InvokeRequest,
  command : RegisteredCommand,
  permission~ : Permission,
  capabilities : Array[Capability],
) -> InvokeResponse {
  let route = request.route()
  let policy = CapabilityPolicy::new(capabilities~)
  if !policy.allows(
      window_label=request.window_label(),
      permission~,
      origin=request.origin(),
    ) {
    InvokeResponse::permission_denied(request.id(), route)
  } else {
    execute_command_async(request, command)
  }
}

///|
fn execute_command(
  request : InvokeRequest,
  command : RegisteredCommand,
) -> InvokeResponse {
  let route = request.route()
  match command.handler {
    SyncCommandHandler(handler) =>
      match handler(request.payload()) {
        Ok(payload) => InvokeResponse::ok(request.id(), payload)
        Err(message) =>
          InvokeResponse::handler_error(request.id(), message, route~)
      }
    AsyncCommandHandler(_) =>
      InvokeResponse::async_required(request.id(), route)
  }
}

///|
async fn execute_command_async(
  request : InvokeRequest,
  command : RegisteredCommand,
) -> InvokeResponse {
  let route = request.route()
  match command.handler {
    SyncCommandHandler(handler) =>
      match handler(request.payload()) {
        Ok(payload) => InvokeResponse::ok(request.id(), payload)
        Err(message) =>
          InvokeResponse::handler_error(request.id(), message, route~)
      }
    AsyncCommandHandler(handler) =>
      match handler(request.payload()) {
        Ok(payload) => InvokeResponse::ok(request.id(), payload)
        Err(message) =>
          InvokeResponse::handler_error(request.id(), message, route~)
      }
  }
}
