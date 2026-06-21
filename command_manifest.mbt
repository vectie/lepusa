///|
pub struct CommandManifestEntry {
  plugin : String
  command : String
  route : String
  mode : CommandMode
  permission : Permission
  request_schema : IpcSchema
  response_schema : IpcSchema
  allowed_windows : Array[String]
  allowed_origins : Array[String]
} derive(Debug, Eq)

///|
fn CommandManifestEntry::new(
  plugin~ : String,
  command~ : String,
  mode~ : CommandMode,
  permission~ : Permission,
  request_schema~ : IpcSchema,
  response_schema~ : IpcSchema,
  allowed_windows~ : Array[String],
  allowed_origins~ : Array[String],
) -> CommandManifestEntry {
  {
    plugin,
    command,
    route: "\{plugin}.\{command}",
    mode,
    permission,
    request_schema,
    response_schema,
    allowed_windows: allowed_windows.copy(),
    allowed_origins: allowed_origins.copy(),
  }
}

///|
pub fn CommandManifestEntry::plugin(self : CommandManifestEntry) -> String {
  self.plugin
}

///|
pub fn CommandManifestEntry::command(self : CommandManifestEntry) -> String {
  self.command
}

///|
pub fn CommandManifestEntry::route(self : CommandManifestEntry) -> String {
  self.route
}

///|
pub fn CommandManifestEntry::mode(self : CommandManifestEntry) -> CommandMode {
  self.mode
}

///|
pub fn CommandManifestEntry::permission(
  self : CommandManifestEntry,
) -> Permission {
  self.permission
}

///|
pub fn CommandManifestEntry::request_schema(
  self : CommandManifestEntry,
) -> IpcSchema {
  self.request_schema
}

///|
pub fn CommandManifestEntry::response_schema(
  self : CommandManifestEntry,
) -> IpcSchema {
  self.response_schema
}

///|
pub fn CommandManifestEntry::allowed_windows(
  self : CommandManifestEntry,
) -> Array[String] {
  self.allowed_windows.copy()
}

///|
pub fn CommandManifestEntry::allowed_origins(
  self : CommandManifestEntry,
) -> Array[String] {
  self.allowed_origins.copy()
}

///|
pub fn CommandManifestEntry::allowed_in_window(
  self : CommandManifestEntry,
  window_label : String,
) -> Bool {
  self.allowed_windows.contains(window_label)
}

///|
pub fn CommandManifestEntry::allowed_for_origin(
  self : CommandManifestEntry,
  origin : String,
) -> Bool {
  self.allowed_origins.is_empty() || self.allowed_origins.contains(origin)
}

///|
pub fn CommandManifestEntry::to_json(self : CommandManifestEntry) -> String {
  [
    "{",
    "\"plugin\":\{self.plugin.json_string()},",
    "\"command\":\{self.command.json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"permission\":\{self.permission.name().json_string()},",
    "\"requestSchema\":\{self.request_schema.to_json()},",
    "\"responseSchema\":\{self.response_schema.to_json()},",
    "\"allowedWindows\":[\{self.allowed_windows.map(fn(window) { window.json_string() }).join(",")}],",
    "\"allowedOrigins\":[\{self.allowed_origins.map(fn(origin) { origin.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub struct CommandManifest {
  entries : Array[CommandManifestEntry]
} derive(Debug, Eq)

///|
pub fn CommandManifest::new(
  entries? : Array[CommandManifestEntry] = [],
) -> CommandManifest {
  { entries: entries.copy() }
}

///|
pub fn CommandManifest::from_plugins(
  plugins~ : Array[Plugin],
  capabilities~ : Array[Capability],
  windows~ : Array[ResolvedWindow],
) -> CommandManifest {
  let entries : Array[CommandManifestEntry] = []
  let policy = CapabilityPolicy::new(capabilities~)
  for plugin in plugins {
    for command in plugin.commands() {
      let allowed_windows : Array[String] = []
      for window in windows {
        if policy.allows_window(
            window_label=window.label(),
            permission=command.permission(),
          ) {
          allowed_windows.push(window.label())
        }
      }
      entries.push(
        CommandManifestEntry::new(
          plugin=plugin.name(),
          command=command.name(),
          mode=command.mode(),
          permission=command.permission(),
          request_schema=command.request_schema(),
          response_schema=command.response_schema(),
          allowed_windows~,
          allowed_origins=command_allowed_origins(
            policy,
            allowed_windows,
            command.permission(),
          ),
        ),
      )
    }
  }
  CommandManifest::new(entries~)
}

///|
fn command_allowed_origins(
  policy : CapabilityPolicy,
  windows : Array[String],
  permission : Permission,
) -> Array[String] {
  let origins : Array[String] = []
  for window in windows {
    let window_origins = policy.allowed_origins(
      window_label=window,
      permission~,
    )
    if window_origins.is_empty() {
      return []
    }
    for origin in window_origins {
      if !origins.contains(origin) {
        origins.push(origin)
      }
    }
  }
  origins
}

///|
pub fn CommandManifest::entries(
  self : CommandManifest,
) -> Array[CommandManifestEntry] {
  self.entries.copy()
}

///|
pub fn CommandManifest::routes(self : CommandManifest) -> Array[String] {
  self.entries.map(fn(entry) { entry.route() })
}

///|
pub fn CommandManifest::entry(
  self : CommandManifest,
  route : String,
) -> CommandManifestEntry? {
  for entry in self.entries {
    if entry.route() == route {
      return Some(entry)
    }
  }
  None
}

///|
pub fn CommandManifest::routes_by_mode(
  self : CommandManifest,
  mode : CommandMode,
) -> Array[String] {
  let routes : Array[String] = []
  for entry in self.entries {
    if entry.mode() == mode {
      routes.push(entry.route())
    }
  }
  routes
}

///|
pub fn CommandManifest::allowed_routes(
  self : CommandManifest,
  window_label : String,
) -> Array[String] {
  let routes : Array[String] = []
  for entry in self.entries {
    if entry.allowed_in_window(window_label) {
      routes.push(entry.route())
    }
  }
  routes
}

///|
pub fn CommandManifest::allows(
  self : CommandManifest,
  route : String,
  window_label~ : String,
  origin? : String = "",
) -> Bool {
  match self.entry(route) {
    Some(entry) =>
      entry.allowed_in_window(window_label) && entry.allowed_for_origin(origin)
    None => false
  }
}

///|
pub fn CommandManifest::to_json(self : CommandManifest) -> String {
  [
    "{",
    "\"commands\":[\{self.entries.map(fn(entry) { entry.to_json() }).join(",")}]",
    "}",
  ].join("")
}
