///|
pub type CommandHandler = (String) -> Result[String, String]

///|
pub type AsyncCommandHandler = async (String) -> Result[String, String]

///|
pub type OperationScopeResolver = (InvokeRequest) -> Result[
  OperationScope,
  String,
]

///|
enum RegisteredCommandHandler {
  SyncCommandHandler(CommandHandler)
  AsyncCommandHandler(AsyncCommandHandler)
  StreamCommandHandler(StreamCommandHandler)
}

///|
pub struct RegisteredCommand {
  route : String
  permission : Permission
  operation_scope : OperationScopeResolver?
  handler : RegisteredCommandHandler
}

///|
pub fn RegisteredCommand::new(
  route : String,
  permission? : Permission = Permission::command(route),
  operation_scope? : OperationScopeResolver,
  handler~ : CommandHandler,
) -> RegisteredCommand {
  { route, permission, operation_scope, handler: SyncCommandHandler(handler) }
}

///|
pub fn RegisteredCommand::new_async(
  route : String,
  permission? : Permission = Permission::command(route),
  operation_scope? : OperationScopeResolver,
  handler~ : AsyncCommandHandler,
) -> RegisteredCommand {
  { route, permission, operation_scope, handler: AsyncCommandHandler(handler) }
}

///|
pub fn RegisteredCommand::new_stream(
  route : String,
  permission? : Permission = Permission::command(route),
  operation_scope? : OperationScopeResolver,
  handler~ : StreamCommandHandler,
) -> RegisteredCommand {
  { route, permission, operation_scope, handler: StreamCommandHandler(handler) }
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
pub fn RegisteredCommand::requires_operation_scope(
  self : RegisteredCommand,
) -> Bool {
  self.operation_scope is Some(_)
}

///|
pub fn RegisteredCommand::resolve_operation_scope(
  self : RegisteredCommand,
  request : InvokeRequest,
) -> Result[OperationScope?, String] {
  match self.operation_scope {
    Some(resolve) =>
      match resolve(request) {
        Ok(scope) => Ok(Some(scope))
        Err(problem) => Err(problem)
      }
    None => Ok(None)
  }
}

///|
pub fn RegisteredCommand::mode(self : RegisteredCommand) -> CommandMode {
  match self.handler {
    SyncCommandHandler(_) => Sync
    AsyncCommandHandler(_) => Async
    StreamCommandHandler(_) => Stream
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
  operation_scope? : OperationScopeResolver,
  handler~ : CommandHandler,
) -> CommandRegistry {
  self.register(
    RegisteredCommand::new(route, permission~, operation_scope?, handler~),
  )
}

///|
pub fn CommandRegistry::register_async_fn(
  self : CommandRegistry,
  route : String,
  permission? : Permission = Permission::command(route),
  operation_scope? : OperationScopeResolver,
  handler~ : AsyncCommandHandler,
) -> CommandRegistry {
  self.register(
    RegisteredCommand::new_async(route, permission~, operation_scope?, handler~),
  )
}

///|
pub fn CommandRegistry::register_stream_fn(
  self : CommandRegistry,
  route : String,
  permission? : Permission = Permission::command(route),
  operation_scope? : OperationScopeResolver,
  handler~ : StreamCommandHandler,
) -> CommandRegistry {
  self.register(
    RegisteredCommand::new_stream(
      route,
      permission~,
      operation_scope?,
      handler~,
    ),
  )
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
  match self.commands.get(request.route()) {
    None => InvokeResponse::unknown_command(request.id(), request.route())
    Some(command) =>
      match authorize_profile_command(profile, request, command) {
        Ok(_) =>
          validate_profile_response(
            profile,
            request,
            execute_command(request, command),
          )
        Err(response) => response
      }
  }
}

///|
fn CommandRegistry::dispatch_with_profile_channels(
  self : CommandRegistry,
  profile : SecurityProfile,
  request : InvokeRequest,
  channels : ChannelTable,
) -> InvokeResponse {
  match self.commands.get(request.route()) {
    None => InvokeResponse::unknown_command(request.id(), request.route())
    Some(command) =>
      match authorize_profile_command(profile, request, command) {
        Ok(_) =>
          if command.mode() is Stream {
            execute_stream_command(request, command, channels)
          } else {
            validate_profile_response(
              profile,
              request,
              execute_command(request, command),
            )
          }
        Err(response) => response
      }
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
  match self.commands.get(request.route()) {
    None => InvokeResponse::unknown_command(request.id(), request.route())
    Some(command) =>
      match authorize_profile_command(profile, request, command) {
        Ok(_) =>
          validate_profile_response(
            profile,
            request,
            execute_command_async(request, command),
          )
        Err(response) => response
      }
  }
}

///|
async fn CommandRegistry::dispatch_with_profile_channels_async(
  self : CommandRegistry,
  profile : SecurityProfile,
  request : InvokeRequest,
  channels : ChannelTable,
) -> InvokeResponse {
  match self.commands.get(request.route()) {
    None => InvokeResponse::unknown_command(request.id(), request.route())
    Some(command) =>
      match authorize_profile_command(profile, request, command) {
        Ok(_) =>
          if command.mode() is Stream {
            execute_stream_command(request, command, channels)
          } else {
            validate_profile_response(
              profile,
              request,
              execute_command_async(request, command),
            )
          }
        Err(response) => response
      }
  }
}

///|
fn authorize_profile_command(
  profile : SecurityProfile,
  request : InvokeRequest,
  command : RegisteredCommand,
) -> Result[Unit, InvokeResponse] {
  let authorization = profile.authorize_invoke(request)
  if !authorization.allowed() {
    return Err(authorization.to_response(request.id()))
  }
  match validate_profile_request(profile, request) {
    Some(problem) =>
      return Err(InvokeResponse::invalid_request(request.id(), problem))
    None => ()
  }
  match command.resolve_operation_scope(request) {
    Ok(None) => Ok(())
    Ok(Some(scope)) => {
      let operation_authorization = profile.authorize_operation(request, scope)
      if operation_authorization.allowed() {
        Ok(())
      } else {
        Err(operation_authorization.to_response(request.id()))
      }
    }
    Err(problem) => Err(InvokeResponse::invalid_request(request.id(), problem))
  }
}

///|
fn validate_profile_request(
  profile : SecurityProfile,
  request : InvokeRequest,
) -> String? {
  match profile.command_manifest().entry(request.route()) {
    Some(entry) =>
      match entry.request_schema().validate_payload(request.payload()) {
        Some(problem) =>
          Some("request schema mismatch for \{request.route()}: \{problem}")
        None => None
      }
    None => Some("command is not declared: \{request.route()}")
  }
}

///|
fn validate_profile_response(
  profile : SecurityProfile,
  request : InvokeRequest,
  response : InvokeResponse,
) -> InvokeResponse {
  match response {
    InvokeOk(id, payload) =>
      match profile.command_manifest().entry(request.route()) {
        Some(entry) =>
          match entry.response_schema().validate_payload(payload) {
            Some(problem) =>
              InvokeResponse::handler_error(
                id,
                "response schema mismatch for \{request.route()}: \{problem}",
                route=request.route(),
              )
            None => response
          }
        None => response
      }
    InvokeError(_, _) => response
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
    StreamCommandHandler(_) =>
      InvokeResponse::handler_error(
        request.id(),
        "stream command requires channel-backed dispatch: \{route}",
        route~,
      )
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
    StreamCommandHandler(_) =>
      InvokeResponse::handler_error(
        request.id(),
        "stream command requires channel-backed dispatch: \{route}",
        route~,
      )
    AsyncCommandHandler(handler) =>
      match handler(request.payload()) {
        Ok(payload) => InvokeResponse::ok(request.id(), payload)
        Err(message) =>
          InvokeResponse::handler_error(request.id(), message, route~)
      }
  }
}

///|
fn execute_stream_command(
  request : InvokeRequest,
  command : RegisteredCommand,
  channels : ChannelTable,
) -> InvokeResponse {
  let route = request.route()
  match command.handler {
    StreamCommandHandler(handler) =>
      match
        channels.open(
          owner=request.plugin(),
          name=request.command(),
          metadata=stream_channel_metadata(request),
        ) {
        Ok(channel) => {
          let sink = StreamSink::new(route~, channel_id=channel.id(), channels~)
          match handler(request.payload(), sink) {
            Ok(_) => {
              if !sink.closed() {
                ignore(sink.end())
              }
              InvokeResponse::ok(
                request.id(),
                stream_response_payload(route, sink),
              )
            }
            Err(message) => {
              ignore(sink.fail(message))
              InvokeResponse::handler_error(request.id(), message, route~)
            }
          }
        }
        Err(problems) =>
          InvokeResponse::handler_error(
            request.id(),
            problems.join("; "),
            route~,
          )
      }
    _ =>
      InvokeResponse::handler_error(
        request.id(),
        "registered command is not a stream: \{route}",
        route~,
      )
  }
}

///|
fn stream_channel_metadata(request : InvokeRequest) -> String {
  [
    "{",
    "\"route\":\{request.route().json_string()},",
    "\"window\":\{request.window_label().json_string()}",
    "}",
  ].join("")
}
