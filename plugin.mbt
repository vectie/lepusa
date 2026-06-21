///|
pub(all) enum CommandMode {
  Sync
  Async
  Stream
  Event
} derive(Debug, Eq)

///|
pub fn CommandMode::name(self : CommandMode) -> String {
  match self {
    Sync => "sync"
    Async => "async"
    Stream => "stream"
    Event => "event"
  }
}

///|
pub struct CommandSpec {
  name : String
  mode : CommandMode
  permission : Permission
  request_schema : IpcSchema
  response_schema : IpcSchema
} derive(Debug, Eq)

///|
pub fn CommandSpec::new(
  name : String,
  mode? : CommandMode = Sync,
  permission? : Permission = Permission::command(name),
  request? : IpcSchema = IpcSchema::any(),
  response? : IpcSchema = IpcSchema::any(),
) -> CommandSpec {
  { name, mode, permission, request_schema: request, response_schema: response }
}

///|
pub fn CommandSpec::name(self : CommandSpec) -> String {
  self.name
}

///|
pub fn CommandSpec::mode(self : CommandSpec) -> CommandMode {
  self.mode
}

///|
pub fn CommandSpec::permission(self : CommandSpec) -> Permission {
  self.permission
}

///|
pub fn CommandSpec::request_schema(self : CommandSpec) -> IpcSchema {
  self.request_schema
}

///|
pub fn CommandSpec::response_schema(self : CommandSpec) -> IpcSchema {
  self.response_schema
}

///|
pub fn CommandSpec::with_schema(
  self : CommandSpec,
  request? : IpcSchema = self.request_schema,
  response? : IpcSchema = self.response_schema,
) -> CommandSpec {
  { ..self, request_schema: request, response_schema: response }
}

///|
pub struct Plugin {
  name : String
  commands : Array[CommandSpec]
  lifecycle_hooks : Array[LifecycleHook]
} derive(Debug, Eq)

///|
pub fn Plugin::new(name : String) -> Plugin {
  { name, commands: [], lifecycle_hooks: [] }
}

///|
pub fn Plugin::command(
  self : Plugin,
  name : String,
  mode? : CommandMode = Sync,
  permission? : Permission,
  request? : IpcSchema,
  response? : IpcSchema,
) -> Plugin {
  let commands = self.commands.copy()
  let route = "\{self.name}.\{name}"
  let permission = permission.unwrap_or(Permission::command(route))
  let request = request.unwrap_or(IpcSchema::any())
  let response = response.unwrap_or(IpcSchema::any())
  commands.push(CommandSpec::new(name, mode~, permission~, request~, response~))
  { ..self, commands, }
}

///|
pub fn Plugin::command_sync(
  self : Plugin,
  name : String,
  permission? : Permission,
  request? : IpcSchema,
  response? : IpcSchema,
) -> Plugin {
  self.command(name, mode=Sync, permission?, request?, response?)
}

///|
pub fn Plugin::command_async(
  self : Plugin,
  name : String,
  permission? : Permission,
  request? : IpcSchema,
  response? : IpcSchema,
) -> Plugin {
  self.command(name, mode=Async, permission?, request?, response?)
}

///|
pub fn Plugin::command_stream(
  self : Plugin,
  name : String,
  permission? : Permission,
  request? : IpcSchema,
  response? : IpcSchema,
) -> Plugin {
  self.command(name, mode=Stream, permission?, request?, response?)
}

///|
pub fn Plugin::command_event(
  self : Plugin,
  name : String,
  permission? : Permission,
  request? : IpcSchema,
  response? : IpcSchema,
) -> Plugin {
  self.command(name, mode=Event, permission?, request?, response?)
}

///|
pub fn Plugin::name(self : Plugin) -> String {
  self.name
}

///|
pub fn Plugin::commands(self : Plugin) -> Array[CommandSpec] {
  self.commands.copy()
}

///|
pub fn Plugin::with_lifecycle(
  self : Plugin,
  event : LifecycleEvent,
  command : Cmd,
) -> Plugin {
  let lifecycle_hooks = self.lifecycle_hooks.copy()
  lifecycle_hooks.push(LifecycleHook::new(event, command))
  { ..self, lifecycle_hooks, }
}

///|
pub fn Plugin::on_setup(self : Plugin, command : Cmd) -> Plugin {
  self.with_lifecycle(PluginSetup(self.name), command)
}

///|
pub fn Plugin::on_ready(self : Plugin, command : Cmd) -> Plugin {
  self.with_lifecycle(PluginReady(self.name), command)
}

///|
pub fn Plugin::on_will_exit(self : Plugin, command : Cmd) -> Plugin {
  self.with_lifecycle(PluginWillExit(self.name), command)
}

///|
pub fn Plugin::lifecycle_hooks(self : Plugin) -> Array[LifecycleHook] {
  self.lifecycle_hooks.copy()
}

///|
pub fn Plugin::command_names(self : Plugin) -> Array[String] {
  self.commands.map(fn(command) { command.name() })
}

///|
pub fn Plugin::command_routes(self : Plugin) -> Array[String] {
  self.commands.map(fn(command) { "\{self.name}.\{command.name()}" })
}

///|
pub fn Plugin::validate(self : Plugin) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("plugin name is required")
  }
  let seen : Array[String] = []
  for command in self.commands {
    let name = command.name()
    if name == "" {
      problems.push("plugin command name is required")
    } else if seen.contains(name) {
      problems.push("plugin command must be unique: \{name}")
    } else {
      seen.push(name)
    }
    for problem in command.request_schema().validate() {
      problems.push(problem)
    }
    for problem in command.response_schema().validate() {
      problems.push(problem)
    }
  }
  for hook in self.lifecycle_hooks {
    match hook.event().plugin_name() {
      Some(name) =>
        if name != self.name {
          problems.push(
            "plugin lifecycle hook belongs to another plugin: \{name}",
          )
        }
      None => problems.push("plugin lifecycle hook must use a plugin event")
    }
  }
  problems
}
