///|
pub struct CommandManifestEntry {
  plugin : String
  command : String
  route : String
  mode : CommandMode
  permission : Permission
  allowed_windows : Array[String]
} derive(Debug, Eq)

///|
fn CommandManifestEntry::new(
  plugin~ : String,
  command~ : String,
  mode~ : CommandMode,
  permission~ : Permission,
  allowed_windows~ : Array[String],
) -> CommandManifestEntry {
  {
    plugin,
    command,
    route: "\{plugin}.\{command}",
    mode,
    permission,
    allowed_windows: allowed_windows.copy(),
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
pub fn CommandManifestEntry::allowed_windows(
  self : CommandManifestEntry,
) -> Array[String] {
  self.allowed_windows.copy()
}

///|
pub fn CommandManifestEntry::allowed_in_window(
  self : CommandManifestEntry,
  window_label : String,
) -> Bool {
  self.allowed_windows.contains(window_label)
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
    "\"allowedWindows\":[\{self.allowed_windows.map(fn(window) { window.json_string() }).join(",")}]",
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
        if policy.allows(
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
          allowed_windows~,
        ),
      )
    }
  }
  CommandManifest::new(entries~)
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
pub fn CommandManifest::to_json(self : CommandManifest) -> String {
  [
    "{",
    "\"commands\":[\{self.entries.map(fn(entry) { entry.to_json() }).join(",")}]",
    "}",
  ].join("")
}
