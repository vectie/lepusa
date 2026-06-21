///|
pub struct PluginCommandContract {
  plugin : String
  name : String
  route : String
  mode : CommandMode
  permission : Permission
  request_schema : IpcSchema
  response_schema : IpcSchema
} derive(Debug, Eq)

///|
pub fn PluginCommandContract::from_command(
  plugin_name~ : String,
  command : CommandSpec,
) -> PluginCommandContract {
  let name = command.name()
  {
    plugin: plugin_name,
    name,
    route: "\{plugin_name}.\{name}",
    mode: command.mode(),
    permission: command.permission(),
    request_schema: command.request_schema(),
    response_schema: command.response_schema(),
  }
}

///|
pub fn PluginCommandContract::plugin(self : PluginCommandContract) -> String {
  self.plugin
}

///|
pub fn PluginCommandContract::name(self : PluginCommandContract) -> String {
  self.name
}

///|
pub fn PluginCommandContract::route(self : PluginCommandContract) -> String {
  self.route
}

///|
pub fn PluginCommandContract::mode(self : PluginCommandContract) -> CommandMode {
  self.mode
}

///|
pub fn PluginCommandContract::permission(
  self : PluginCommandContract,
) -> Permission {
  self.permission
}

///|
pub fn PluginCommandContract::request_schema(
  self : PluginCommandContract,
) -> IpcSchema {
  self.request_schema
}

///|
pub fn PluginCommandContract::response_schema(
  self : PluginCommandContract,
) -> IpcSchema {
  self.response_schema
}

///|
pub fn PluginCommandContract::to_json(self : PluginCommandContract) -> String {
  [
    "{",
    "\"plugin\":\{self.plugin.json_string()},",
    "\"name\":\{self.name.json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"permission\":\{self.permission.name().json_string()},",
    "\"request\":\{self.request_schema.to_json()},",
    "\"response\":\{self.response_schema.to_json()}",
    "}",
  ].join("")
}

///|
pub struct PluginLifecycleContract {
  event : LifecycleEvent
  command_empty : Bool
} derive(Debug, Eq)

///|
pub fn PluginLifecycleContract::from_hook(
  hook : LifecycleHook,
) -> PluginLifecycleContract {
  { event: hook.event(), command_empty: hook.command().is_empty() }
}

///|
pub fn PluginLifecycleContract::event(
  self : PluginLifecycleContract,
) -> LifecycleEvent {
  self.event
}

///|
pub fn PluginLifecycleContract::command_empty(
  self : PluginLifecycleContract,
) -> Bool {
  self.command_empty
}

///|
pub fn PluginLifecycleContract::to_json(
  self : PluginLifecycleContract,
) -> String {
  [
    "{",
    "\"event\":\{self.event.to_json()},",
    "\"commandEmpty\":\{self.command_empty.json_bool()}",
    "}",
  ].join("")
}

///|
pub struct PluginContract {
  name : String
  commands : Array[PluginCommandContract]
  lifecycle_hooks : Array[PluginLifecycleContract]
  permissions : Array[String]
  problems : Array[String]
} derive(Debug, Eq)

///|
pub fn Plugin::contract(self : Plugin) -> PluginContract {
  let commands = self
    .commands()
    .map(fn(command) {
      PluginCommandContract::from_command(plugin_name=self.name(), command)
    })
  {
    name: self.name(),
    commands,
    lifecycle_hooks: self
    .lifecycle_hooks()
    .map(PluginLifecycleContract::from_hook),
    permissions: plugin_contract_permissions(commands),
    problems: self.validate(),
  }
}

///|
pub fn PluginContract::name(self : PluginContract) -> String {
  self.name
}

///|
pub fn PluginContract::commands(
  self : PluginContract,
) -> Array[PluginCommandContract] {
  self.commands.copy()
}

///|
pub fn PluginContract::lifecycle_hooks(
  self : PluginContract,
) -> Array[PluginLifecycleContract] {
  self.lifecycle_hooks.copy()
}

///|
pub fn PluginContract::permissions(self : PluginContract) -> Array[String] {
  self.permissions.copy()
}

///|
pub fn PluginContract::problems(self : PluginContract) -> Array[String] {
  self.problems.copy()
}

///|
pub fn PluginContract::ok(self : PluginContract) -> Bool {
  self.problems.is_empty()
}

///|
pub fn PluginContract::command_routes(self : PluginContract) -> Array[String] {
  self.commands.map(fn(command) { command.route() })
}

///|
pub fn PluginContract::command_count(self : PluginContract) -> Int {
  self.commands.length()
}

///|
pub fn PluginContract::lifecycle_count(self : PluginContract) -> Int {
  self.lifecycle_hooks.length()
}

///|
pub fn PluginContract::sync_count(self : PluginContract) -> Int {
  self.command_count_by_mode(Sync)
}

///|
pub fn PluginContract::async_count(self : PluginContract) -> Int {
  self.command_count_by_mode(Async)
}

///|
pub fn PluginContract::stream_count(self : PluginContract) -> Int {
  self.command_count_by_mode(Stream)
}

///|
pub fn PluginContract::event_count(self : PluginContract) -> Int {
  self.command_count_by_mode(Event)
}

///|
pub fn PluginContract::command_count_by_mode(
  self : PluginContract,
  mode : CommandMode,
) -> Int {
  let mut count = 0
  for command in self.commands {
    if command.mode() == mode {
      count += 1
    }
  }
  count
}

///|
pub fn PluginContract::to_json(self : PluginContract) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"ok\":\{self.ok().json_bool()},",
    "\"commands\":[\{self.commands.map(fn(command) { command.to_json() }).join(",")}],",
    "\"lifecycleHooks\":[\{self.lifecycle_hooks.map(fn(hook) { hook.to_json() }).join(",")}],",
    "\"permissions\":[\{self.permissions.map(fn(permission) { permission.json_string() }).join(",")}],",
    "\"counts\":\{self.counts_json()},",
    "\"problems\":[\{self.problems.map(fn(problem) { problem.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn PluginContract::counts_json(self : PluginContract) -> String {
  [
    "{",
    "\"commands\":\{self.command_count()},",
    "\"sync\":\{self.sync_count()},",
    "\"async\":\{self.async_count()},",
    "\"stream\":\{self.stream_count()},",
    "\"event\":\{self.event_count()},",
    "\"lifecycle\":\{self.lifecycle_count()}",
    "}",
  ].join("")
}

///|
fn plugin_contract_permissions(
  commands : Array[PluginCommandContract],
) -> Array[String] {
  let permissions : Array[String] = []
  for command in commands {
    let permission = command.permission().name()
    if !permissions.contains(permission) {
      permissions.push(permission)
    }
  }
  permissions
}
