///|
pub struct PermissionManifestCommand {
  plugin : String
  command : String
  route : String
  mode : CommandMode
  affinity : CommandExecutionAffinity
  allowed_windows : Array[String]
  allowed_origins : Array[String]
} derive(Debug, Eq)

///|
pub struct PermissionManifestGrant {
  capability : String
  windows : Array[String]
  origins : Array[String]
} derive(Debug, Eq)

///|
pub struct PermissionManifestPermission {
  name : String
  commands : Array[PermissionManifestCommand]
  grants : Array[PermissionManifestGrant]
  allowed_windows : Array[String]
  allowed_origins : Array[String]
  denied_routes : Array[String]
} derive(Debug, Eq)

///|
pub struct PermissionManifest {
  permissions : Array[PermissionManifestPermission]
} derive(Debug, Eq)

///|
fn PermissionManifestCommand::from_entry(
  entry : CommandManifestEntry,
) -> PermissionManifestCommand {
  {
    plugin: entry.plugin(),
    command: entry.command(),
    route: entry.route(),
    mode: entry.mode(),
    affinity: entry.affinity(),
    allowed_windows: entry.allowed_windows(),
    allowed_origins: entry.allowed_origins(),
  }
}

///|
fn PermissionManifestGrant::from_capability(
  capability : Capability,
) -> PermissionManifestGrant {
  {
    capability: capability.name(),
    windows: capability.windows(),
    origins: capability.origins(),
  }
}

///|
pub fn PermissionManifestCommand::plugin(
  self : PermissionManifestCommand,
) -> String {
  self.plugin
}

///|
pub fn PermissionManifestCommand::command(
  self : PermissionManifestCommand,
) -> String {
  self.command
}

///|
pub fn PermissionManifestCommand::route(
  self : PermissionManifestCommand,
) -> String {
  self.route
}

///|
pub fn PermissionManifestCommand::mode(
  self : PermissionManifestCommand,
) -> CommandMode {
  self.mode
}

///|
pub fn PermissionManifestCommand::affinity(
  self : PermissionManifestCommand,
) -> CommandExecutionAffinity {
  self.affinity
}

///|
pub fn PermissionManifestCommand::allowed_windows(
  self : PermissionManifestCommand,
) -> Array[String] {
  self.allowed_windows.copy()
}

///|
pub fn PermissionManifestCommand::allowed_origins(
  self : PermissionManifestCommand,
) -> Array[String] {
  self.allowed_origins.copy()
}

///|
pub fn PermissionManifestCommand::to_json(
  self : PermissionManifestCommand,
) -> String {
  [
    "{",
    "\"plugin\":\{self.plugin.json_string()},",
    "\"command\":\{self.command.json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"affinity\":\{self.affinity.name().json_string()},",
    "\"allowedWindows\":[\{self.allowed_windows.map(fn(window) { window.json_string() }).join(",")}],",
    "\"allowedOrigins\":[\{self.allowed_origins.map(fn(origin) { origin.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn PermissionManifestGrant::capability(
  self : PermissionManifestGrant,
) -> String {
  self.capability
}

///|
pub fn PermissionManifestGrant::windows(
  self : PermissionManifestGrant,
) -> Array[String] {
  self.windows.copy()
}

///|
pub fn PermissionManifestGrant::origins(
  self : PermissionManifestGrant,
) -> Array[String] {
  self.origins.copy()
}

///|
pub fn PermissionManifestGrant::to_json(
  self : PermissionManifestGrant,
) -> String {
  [
    "{",
    "\"capability\":\{self.capability.json_string()},",
    "\"windows\":[\{self.windows.map(fn(window) { window.json_string() }).join(",")}],",
    "\"origins\":[\{self.origins.map(fn(origin) { origin.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn PermissionManifestPermission::name(
  self : PermissionManifestPermission,
) -> String {
  self.name
}

///|
pub fn PermissionManifestPermission::commands(
  self : PermissionManifestPermission,
) -> Array[PermissionManifestCommand] {
  self.commands.copy()
}

///|
pub fn PermissionManifestPermission::grants(
  self : PermissionManifestPermission,
) -> Array[PermissionManifestGrant] {
  self.grants.copy()
}

///|
pub fn PermissionManifestPermission::allowed_windows(
  self : PermissionManifestPermission,
) -> Array[String] {
  self.allowed_windows.copy()
}

///|
pub fn PermissionManifestPermission::allowed_origins(
  self : PermissionManifestPermission,
) -> Array[String] {
  self.allowed_origins.copy()
}

///|
pub fn PermissionManifestPermission::denied_routes(
  self : PermissionManifestPermission,
) -> Array[String] {
  self.denied_routes.copy()
}

///|
pub fn PermissionManifestPermission::to_json(
  self : PermissionManifestPermission,
) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"commands\":[\{self.commands.map(fn(command) { command.to_json() }).join(",")}],",
    "\"grants\":[\{self.grants.map(fn(grant) { grant.to_json() }).join(",")}],",
    "\"allowedWindows\":[\{self.allowed_windows.map(fn(window) { window.json_string() }).join(",")}],",
    "\"allowedOrigins\":[\{self.allowed_origins.map(fn(origin) { origin.json_string() }).join(",")}],",
    "\"deniedRoutes\":[\{self.denied_routes.map(fn(route) { route.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn PermissionManifest::new(
  permissions? : Array[PermissionManifestPermission] = [],
) -> PermissionManifest {
  { permissions: permissions.copy() }
}

///|
pub fn PermissionManifest::from_command_manifest(
  manifest : CommandManifest,
  capabilities~ : Array[Capability],
) -> PermissionManifest {
  let permissions : Array[PermissionManifestPermission] = []
  for name in permission_names(manifest, capabilities) {
    let commands = permission_commands(manifest, name)
    permissions.push({
      name,
      commands,
      grants: permission_grants(capabilities, name),
      allowed_windows: permission_allowed_windows(commands),
      allowed_origins: permission_allowed_origins(commands),
      denied_routes: commands
      .filter(fn(command) { command.allowed_windows().is_empty() })
      .map(fn(command) { command.route() }),
    })
  }
  PermissionManifest::new(permissions~)
}

///|
pub fn PermissionManifest::from_plugins(
  plugins~ : Array[Plugin],
  capabilities~ : Array[Capability],
  windows~ : Array[ResolvedWindow],
) -> PermissionManifest {
  PermissionManifest::from_command_manifest(
    CommandManifest::from_plugins(plugins~, capabilities~, windows~),
    capabilities~,
  )
}

///|
pub fn PermissionManifest::permissions(
  self : PermissionManifest,
) -> Array[PermissionManifestPermission] {
  self.permissions.copy()
}

///|
pub fn PermissionManifest::permission_names(
  self : PermissionManifest,
) -> Array[String] {
  self.permissions.map(fn(permission) { permission.name() })
}

///|
pub fn PermissionManifest::permission(
  self : PermissionManifest,
  name : String,
) -> PermissionManifestPermission? {
  for permission in self.permissions {
    if permission.name() == name {
      return Some(permission)
    }
  }
  None
}

///|
pub fn PermissionManifest::denied_routes(
  self : PermissionManifest,
) -> Array[String] {
  let routes : Array[String] = []
  for permission in self.permissions {
    for route in permission.denied_routes() {
      if !routes.contains(route) {
        routes.push(route)
      }
    }
  }
  routes
}

///|
pub fn PermissionManifest::to_json(self : PermissionManifest) -> String {
  [
    "{",
    "\"permissions\":[\{self.permissions.map(fn(permission) { permission.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn permission_names(
  manifest : CommandManifest,
  capabilities : Array[Capability],
) -> Array[String] {
  let names : Array[String] = []
  for entry in manifest.entries() {
    let name = entry.permission().name()
    if !names.contains(name) {
      names.push(name)
    }
  }
  for capability in capabilities {
    for permission in capability.permissions() {
      let name = permission.name()
      if !names.contains(name) {
        names.push(name)
      }
    }
  }
  names
}

///|
fn permission_commands(
  manifest : CommandManifest,
  permission_name : String,
) -> Array[PermissionManifestCommand] {
  let commands : Array[PermissionManifestCommand] = []
  for entry in manifest.entries() {
    if entry.permission().name() == permission_name {
      commands.push(PermissionManifestCommand::from_entry(entry))
    }
  }
  commands
}

///|
fn permission_grants(
  capabilities : Array[Capability],
  permission_name : String,
) -> Array[PermissionManifestGrant] {
  let grants : Array[PermissionManifestGrant] = []
  for capability in capabilities {
    if capability
      .permissions()
      .any(fn(permission) { permission.name() == permission_name }) {
      grants.push(PermissionManifestGrant::from_capability(capability))
    }
  }
  grants
}

///|
fn permission_allowed_windows(
  commands : Array[PermissionManifestCommand],
) -> Array[String] {
  let windows : Array[String] = []
  for command in commands {
    for window in command.allowed_windows() {
      if !windows.contains(window) {
        windows.push(window)
      }
    }
  }
  windows
}

///|
fn permission_allowed_origins(
  commands : Array[PermissionManifestCommand],
) -> Array[String] {
  let origins : Array[String] = []
  for command in commands {
    for origin in command.allowed_origins() {
      if !origins.contains(origin) {
        origins.push(origin)
      }
    }
  }
  origins
}
