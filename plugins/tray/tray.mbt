///|
pub(all) enum TrayMenuItemKind {
  Action
  Separator
  Check
} derive(Debug, Eq)

///|
pub struct TrayMenuItem {
  id : String
  label : String
  kind : TrayMenuItemKind
  enabled : Bool
  checked : Bool
} derive(Debug, Eq)

///|
pub struct TrayPolicy {
  icon_path : String?
  tooltip : String?
  menu : Array[TrayMenuItem]
} derive(Debug, Eq)

///|
pub fn TrayMenuItem::action(
  id~ : String,
  label~ : String,
  enabled? : Bool = true,
) -> TrayMenuItem {
  { id, label, kind: Action, enabled, checked: false }
}

///|
pub fn TrayMenuItem::separator() -> TrayMenuItem {
  { id: "", label: "", kind: Separator, enabled: false, checked: false }
}

///|
pub fn TrayMenuItem::check(
  id~ : String,
  label~ : String,
  checked? : Bool = false,
  enabled? : Bool = true,
) -> TrayMenuItem {
  { id, label, kind: Check, enabled, checked }
}

///|
pub fn TrayMenuItem::id(self : TrayMenuItem) -> String {
  self.id
}

///|
pub fn TrayMenuItem::label(self : TrayMenuItem) -> String {
  self.label
}

///|
pub fn TrayMenuItem::kind(self : TrayMenuItem) -> TrayMenuItemKind {
  self.kind
}

///|
pub fn TrayMenuItem::enabled(self : TrayMenuItem) -> Bool {
  self.enabled
}

///|
pub fn TrayMenuItem::checked(self : TrayMenuItem) -> Bool {
  self.checked
}

///|
pub fn TrayMenuItem::validate(self : TrayMenuItem) -> Array[String] {
  let problems : Array[String] = []
  match self.kind {
    Separator => ()
    Action | Check => {
      if self.id == "" {
        problems.push("tray menu item id is required")
      } else if invalid_id(self.id) {
        problems.push("tray menu item id is invalid: \{self.id}")
      }
      if self.label == "" {
        problems.push("tray menu item label is required")
      }
    }
  }
  problems
}

///|
pub fn TrayPolicy::new(
  icon_path? : String,
  tooltip? : String,
  menu? : Array[TrayMenuItem] = [],
) -> TrayPolicy {
  { icon_path, tooltip, menu }
}

///|
pub fn TrayPolicy::icon_path(self : TrayPolicy) -> String? {
  self.icon_path
}

///|
pub fn TrayPolicy::tooltip(self : TrayPolicy) -> String? {
  self.tooltip
}

///|
pub fn TrayPolicy::menu(self : TrayPolicy) -> Array[TrayMenuItem] {
  self.menu.copy()
}

///|
pub fn TrayPolicy::item(self : TrayPolicy, item : TrayMenuItem) -> TrayPolicy {
  let menu = self.menu.copy()
  menu.push(item)
  { ..self, menu, }
}

///|
pub fn TrayPolicy::validate(self : TrayPolicy) -> Array[String] {
  let problems : Array[String] = []
  match self.icon_path {
    Some("") => problems.push("tray icon path is required")
    Some(path) =>
      if path.contains("\\") {
        problems.push("tray icon path must use forward slashes")
      }
    None => ()
  }
  match self.tooltip {
    Some("") => problems.push("tray tooltip is required")
    _ => ()
  }
  let seen : Array[String] = []
  for item in self.menu {
    problems.append(item.validate())
    let id = item.id()
    if id != "" {
      if seen.contains(id) {
        problems.push("tray menu item must be unique: \{id}")
      } else {
        seen.push(id)
      }
    }
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("tray")
  .command_async("setIcon", permission=Tray)
  .command_async("setTooltip", permission=Tray)
  .command_async("setMenu", permission=Tray)
  .command_async("showMenu", permission=Tray)
  .command_async("setVisible", permission=Tray)
  .command_async("destroy", permission=Tray)
  .command_event("onMenuItemClick", permission=Tray)
}

///|
pub fn capability(name? : String = "tray") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Tray)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "tray",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
fn invalid_id(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}
