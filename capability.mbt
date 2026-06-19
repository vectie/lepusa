///|
pub(all) enum Permission {
  FileSystemRead
  FileSystemWrite
  FileDialog
  Network
  Localhost
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
    "filesystem.read" => Ok(FileSystemRead)
    "filesystem.write" => Ok(FileSystemWrite)
    "file-dialog" => Ok(FileDialog)
    "network" => Ok(Network)
    "localhost" => Ok(Localhost)
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
    FileSystemRead => "filesystem.read"
    FileSystemWrite => "filesystem.write"
    FileDialog => "file-dialog"
    Network => "network"
    Localhost => "localhost"
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
  permissions : Array[Permission]
} derive(Debug, Eq)

///|
pub fn Capability::new(name : String) -> Capability {
  { name, windows: [], permissions: [] }
}

///|
pub fn Capability::window(self : Capability, label : String) -> Capability {
  let windows = self.windows.copy()
  windows.push(label)
  { ..self, windows, }
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
pub fn Capability::allows(
  self : Capability,
  window_label~ : String,
  permission~ : Permission,
) -> Bool {
  let window_allowed = self.windows.is_empty() ||
    self.windows.contains(window_label)
  window_allowed && self.permissions.contains(permission)
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
pub fn Capability::validate(self : Capability) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("capability name is required")
  }
  if self.permissions.is_empty() {
    problems.push("capability must include at least one permission")
  }
  problems
}
