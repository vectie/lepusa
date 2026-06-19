///|
pub type CommandHandler = (String) -> Result[String, String]

///|
pub struct RegisteredCommand {
  route : String
  permission : Permission
  handler : CommandHandler
}

///|
pub fn RegisteredCommand::new(
  route : String,
  permission? : Permission = Permission::command(route),
  handler~ : CommandHandler,
) -> RegisteredCommand {
  { route, permission, handler }
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
pub struct CommandRegistry {
  commands : Map[String, RegisteredCommand]
}

///|
pub fn CommandRegistry::new() -> CommandRegistry {
  { commands: {} }
}

///|
pub fn CommandRegistry::register(
  self : CommandRegistry,
  command : RegisteredCommand,
) -> CommandRegistry {
  let commands = self.commands.copy()
  commands[command.route()] = command
  { commands, }
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
    return InvokeResponse::error(request.id(), request_problems[0])
  }
  let route = request.route()
  match self.commands.get(route) {
    None => InvokeResponse::error(request.id(), "unknown command: \{route}")
    Some(command) =>
      if !capabilities.allow_invoke(
          window_label=request.window_label(),
          permission=command.permission(),
        ) {
        InvokeResponse::error(request.id(), "permission denied: \{route}")
      } else {
        match (command.handler)(request.payload()) {
          Ok(payload) => InvokeResponse::ok(request.id(), payload)
          Err(message) => InvokeResponse::error(request.id(), message)
        }
      }
  }
}

///|
fn Array::allow_invoke(
  self : Array[Capability],
  window_label~ : String,
  permission~ : Permission,
) -> Bool {
  for capability in self {
    if capability.allows(window_label~, permission~) {
      return true
    }
  }
  false
}
