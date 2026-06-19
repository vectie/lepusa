///|
pub(all) enum CommandMode {
  Sync
  Async
  Stream
  Event
} derive(Debug, Eq)

///|
pub struct CommandSpec {
  name : String
  mode : CommandMode
  permission : Permission
} derive(Debug, Eq)

///|
pub fn CommandSpec::new(
  name : String,
  mode? : CommandMode = Sync,
  permission? : Permission = Permission::command(name),
) -> CommandSpec {
  { name, mode, permission }
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
pub struct Plugin {
  name : String
  commands : Array[CommandSpec]
} derive(Debug, Eq)

///|
pub fn Plugin::new(name : String) -> Plugin {
  { name, commands: [] }
}

///|
pub fn Plugin::command(
  self : Plugin,
  name : String,
  mode? : CommandMode = Sync,
  permission? : Permission,
) -> Plugin {
  let commands = self.commands.copy()
  let route = "\{self.name}.\{name}"
  let permission = permission.unwrap_or(Permission::command(route))
  commands.push(CommandSpec::new(name, mode~, permission~))
  { ..self, commands, }
}

///|
pub fn Plugin::command_sync(
  self : Plugin,
  name : String,
  permission? : Permission,
) -> Plugin {
  self.command(name, mode=Sync, permission?)
}

///|
pub fn Plugin::command_async(
  self : Plugin,
  name : String,
  permission? : Permission,
) -> Plugin {
  self.command(name, mode=Async, permission?)
}

///|
pub fn Plugin::command_stream(
  self : Plugin,
  name : String,
  permission? : Permission,
) -> Plugin {
  self.command(name, mode=Stream, permission?)
}

///|
pub fn Plugin::command_event(
  self : Plugin,
  name : String,
  permission? : Permission,
) -> Plugin {
  self.command(name, mode=Event, permission?)
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
  }
  problems
}
