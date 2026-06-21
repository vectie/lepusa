///|
pub(all) enum Permission {
  App
  FileSystemRead
  FileSystemWrite
  FileDialog
  Network
  Localhost
  DeepLink
  SingleInstance
  Menu
  Tray
  AutoLaunch
  Window
  WindowState
  Updater
  ServiceDiscovery
  Shell
  Opener
  Dialog
  Clipboard
  Notification
  ProcessInfo
  ProcessEnvironment
  ProcessControl
  Custom(String)
} derive(Debug, Eq)

///|
pub fn Permission::command(route : String) -> Permission {
  Custom(route)
}

///|
pub fn Permission::named(name : String) -> Result[Permission, String] {
  match name {
    "app" => Ok(App)
    "filesystem.read" => Ok(FileSystemRead)
    "filesystem.write" => Ok(FileSystemWrite)
    "file-dialog" => Ok(FileDialog)
    "network" => Ok(Network)
    "localhost" => Ok(Localhost)
    "deep-link" => Ok(DeepLink)
    "single-instance" => Ok(SingleInstance)
    "menu" => Ok(Menu)
    "tray" => Ok(Tray)
    "auto-launch" => Ok(AutoLaunch)
    "window" => Ok(Window)
    "window-state" => Ok(WindowState)
    "updater" => Ok(Updater)
    "service-discovery" => Ok(ServiceDiscovery)
    "shell" => Ok(Shell)
    "opener" => Ok(Opener)
    "dialog" => Ok(Dialog)
    "clipboard" => Ok(Clipboard)
    "notification" => Ok(Notification)
    "process.info" => Ok(ProcessInfo)
    "process.environment" => Ok(ProcessEnvironment)
    "process.control" => Ok(ProcessControl)
    _ =>
      if name.has_prefix("custom:") {
        let value = name[7:].to_owned()
        if value == "" {
          Err("custom permission name is required")
        } else {
          Ok(Custom(value))
        }
      } else {
        Err("unknown permission: \{name}")
      }
  }
}

///|
pub fn Permission::name(self : Permission) -> String {
  match self {
    App => "app"
    FileSystemRead => "filesystem.read"
    FileSystemWrite => "filesystem.write"
    FileDialog => "file-dialog"
    Network => "network"
    Localhost => "localhost"
    DeepLink => "deep-link"
    SingleInstance => "single-instance"
    Menu => "menu"
    Tray => "tray"
    AutoLaunch => "auto-launch"
    Window => "window"
    WindowState => "window-state"
    Updater => "updater"
    ServiceDiscovery => "service-discovery"
    Shell => "shell"
    Opener => "opener"
    Dialog => "dialog"
    Clipboard => "clipboard"
    Notification => "notification"
    ProcessInfo => "process.info"
    ProcessEnvironment => "process.environment"
    ProcessControl => "process.control"
    Custom(value) => "custom:\{value}"
  }
}

///|
pub struct Capability {
  name : String
  windows : Array[String]
  origins : Array[String]
  platforms : Array[String]
  permissions : Array[Permission]
  operation_scopes : Array[OperationScope]
} derive(Debug, Eq)

///|
pub fn Capability::new(name : String) -> Capability {
  {
    name,
    windows: [],
    origins: [],
    platforms: [],
    permissions: [],
    operation_scopes: [],
  }
}

///|
pub fn Capability::window(self : Capability, label : String) -> Capability {
  let windows = self.windows.copy()
  windows.push(label)
  { ..self, windows, }
}

///|
pub fn Capability::origin(self : Capability, origin : String) -> Capability {
  let origins = self.origins.copy()
  origins.push(origin)
  { ..self, origins, }
}

///|
pub fn Capability::platform(self : Capability, platform : String) -> Capability {
  let platforms = self.platforms.copy()
  platforms.push(platform)
  { ..self, platforms, }
}

///|
pub fn Capability::permission(
  self : Capability,
  permission : Permission,
) -> Capability {
  let permissions = self.permissions.copy()
  permissions.push(permission)
  { ..self, permissions, }
}

///|
pub fn Capability::command(self : Capability, route : String) -> Capability {
  self.permission(Permission::command(route))
}

///|
pub fn Capability::operation_scope(
  self : Capability,
  scope : OperationScope,
) -> Capability {
  let operation_scopes = self.operation_scopes.copy()
  operation_scopes.push(scope)
  { ..self, operation_scopes, }
}

///|
pub fn Capability::path_scope(
  self : Capability,
  root~ : String,
  writable? : Bool = false,
) -> Capability {
  self.operation_scope(OperationScope::path(root~, writable~))
}

///|
pub fn Capability::shell_scope(
  self : Capability,
  command : String,
) -> Capability {
  self.operation_scope(OperationScope::shell(command))
}

///|
pub fn Capability::url_scope(self : Capability, origin : String) -> Capability {
  self.operation_scope(OperationScope::url(origin))
}

///|
pub fn Capability::allows(
  self : Capability,
  window_label~ : String,
  permission~ : Permission,
  origin? : String = "",
  platform? : String = "",
) -> Bool {
  let window_allowed = self.windows.is_empty() ||
    self.windows.contains(window_label)
  let origin_allowed = self.origins.is_empty() || self.origins.contains(origin)
  let platform_allowed = self.platforms.is_empty() ||
    self.platforms.contains(platform)
  window_allowed &&
  origin_allowed &&
  platform_allowed &&
  self.permissions.contains(permission)
}

///|
pub fn Capability::allows_operation(
  self : Capability,
  window_label~ : String,
  permission~ : Permission,
  scope~ : OperationScope,
  origin? : String = "",
  platform? : String = "",
) -> Bool {
  self.allows(window_label~, permission~, origin~, platform~) &&
  self.operation_scopes.any(fn(allowed) { allowed.allows(scope) })
}

///|
pub fn Capability::name(self : Capability) -> String {
  self.name
}

///|
pub fn Capability::permissions(self : Capability) -> Array[Permission] {
  self.permissions.copy()
}

///|
pub fn Capability::windows(self : Capability) -> Array[String] {
  self.windows.copy()
}

///|
pub fn Capability::origins(self : Capability) -> Array[String] {
  self.origins.copy()
}

///|
pub fn Capability::platforms(self : Capability) -> Array[String] {
  self.platforms.copy()
}

///|
pub fn Capability::operation_scopes(self : Capability) -> Array[OperationScope] {
  self.operation_scopes.copy()
}

///|
pub fn Capability::operation_scopes_by_kind(
  self : Capability,
  kind : OperationScopeKind,
) -> Array[OperationScope] {
  self.operation_scopes.filter(fn(scope) { scope.kind() == kind })
}

///|
pub fn Capability::validate(self : Capability) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("capability name is required")
  }
  if self.permissions.is_empty() {
    problems.push("capability must include at least one permission")
  }
  for origin in self.origins {
    if origin == "" {
      problems.push("capability origin must not be empty")
    }
  }
  for platform in self.platforms {
    if platform == "" {
      problems.push("capability platform must not be empty")
    }
  }
  let seen_scopes : Array[String] = []
  for scope in self.operation_scopes {
    for problem in scope.validate() {
      problems.push(problem)
    }
    let fingerprint = scope.fingerprint()
    if seen_scopes.contains(fingerprint) {
      problems.push("capability operation scope must be unique: \{fingerprint}")
    } else {
      seen_scopes.push(fingerprint)
    }
  }
  problems
}
