///|
pub(all) enum Permission {
  FileSystemRead
  FileSystemWrite
  Network
  Shell
  Dialog
  Clipboard
  Notification
  Custom(String)
} derive(Debug, Eq)

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
