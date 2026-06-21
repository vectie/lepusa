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
pub struct TrayState {
  mut icon_path : String?
  mut tooltip : String?
  mut menu : Array[TrayMenuItem]
  mut visible : Bool
  mut destroyed : Bool
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
  validate_tray_fields(self.icon_path, self.tooltip, self.menu)
}

///|
fn validate_tray_fields(
  icon_path : String?,
  tooltip : String?,
  menu : Array[TrayMenuItem],
) -> Array[String] {
  let problems : Array[String] = []
  match icon_path {
    Some("") => problems.push("tray icon path is required")
    Some(path) =>
      if path.contains("\\") {
        problems.push("tray icon path must use forward slashes")
      }
    None => ()
  }
  match tooltip {
    Some("") => problems.push("tray tooltip is required")
    _ => ()
  }
  let seen : Array[String] = []
  for item in menu {
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
pub fn TrayState::new(policy? : TrayPolicy = TrayPolicy::new()) -> TrayState {
  {
    icon_path: policy.icon_path(),
    tooltip: policy.tooltip(),
    menu: policy.menu(),
    visible: true,
    destroyed: false,
  }
}

///|
pub fn TrayState::icon_path(self : TrayState) -> String? {
  self.icon_path
}

///|
pub fn TrayState::tooltip(self : TrayState) -> String? {
  self.tooltip
}

///|
pub fn TrayState::menu(self : TrayState) -> Array[TrayMenuItem] {
  self.menu.copy()
}

///|
pub fn TrayState::visible(self : TrayState) -> Bool {
  self.visible
}

///|
pub fn TrayState::destroyed(self : TrayState) -> Bool {
  self.destroyed
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("tray")
  .command_sync("setIcon", permission=Tray, affinity=MainThread)
  .command_sync("setTooltip", permission=Tray, affinity=MainThread)
  .command_sync("setMenu", permission=Tray, affinity=MainThread)
  .command_sync("showMenu", permission=Tray, affinity=MainThread)
  .command_sync("setVisible", permission=Tray, affinity=MainThread)
  .command_sync("destroy", permission=Tray, affinity=MainThread)
  .command_event("onMenuItemClick", permission=Tray, affinity=MainThread)
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
pub fn registry(
  policy? : TrayPolicy = TrayPolicy::new(),
  state? : TrayState,
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, state?)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : TrayPolicy = TrayPolicy::new(),
  state? : TrayState,
) -> @lepusa.CommandRegistry {
  let state = state.unwrap_or(TrayState::new(policy~))
  registry
  .register_fn("tray.setIcon", permission=Tray, handler=payload => {
    handle_set_icon(state, payload)
  })
  .register_fn("tray.setTooltip", permission=Tray, handler=payload => {
    handle_set_tooltip(state, payload)
  })
  .register_fn("tray.setMenu", permission=Tray, handler=payload => {
    handle_set_menu(state, payload)
  })
  .register_fn("tray.showMenu", permission=Tray, handler=_ => {
    handle_show_menu(state)
  })
  .register_fn("tray.setVisible", permission=Tray, handler=payload => {
    handle_set_visible(state, payload)
  })
  .register_fn("tray.destroy", permission=Tray, handler=_ => {
    handle_destroy(state)
  })
}

///|
fn handle_set_icon(
  state : TrayState,
  payload : String,
) -> Result[String, String] {
  match
    decode_string_payload(payload, field="iconPath", context="tray setIcon") {
    Ok(icon_path) =>
      match
        first_problem(
          validate_tray_fields(Some(icon_path), state.tooltip(), state.menu()),
        ) {
        Some(problem) => Err(problem)
        None => {
          state.icon_path = Some(icon_path)
          Ok(tray_state_json(state, status="delegated").stringify())
        }
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set_tooltip(
  state : TrayState,
  payload : String,
) -> Result[String, String] {
  match
    decode_string_payload(payload, field="tooltip", context="tray setTooltip") {
    Ok(tooltip) =>
      match
        first_problem(
          validate_tray_fields(state.icon_path(), Some(tooltip), state.menu()),
        ) {
        Some(problem) => Err(problem)
        None => {
          state.tooltip = Some(tooltip)
          Ok(tray_state_json(state, status="delegated").stringify())
        }
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set_menu(
  state : TrayState,
  payload : String,
) -> Result[String, String] {
  match decode_menu_payload(payload) {
    Ok(menu) =>
      match
        first_problem(
          validate_tray_fields(state.icon_path(), state.tooltip(), menu),
        ) {
        Some(problem) => Err(problem)
        None => {
          state.menu = menu.copy()
          Ok(tray_state_json(state, status="delegated").stringify())
        }
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_show_menu(state : TrayState) -> Result[String, String] {
  Ok(tray_state_json(state, status="delegated").stringify())
}

///|
fn handle_set_visible(
  state : TrayState,
  payload : String,
) -> Result[String, String] {
  match decode_visible_payload(payload) {
    Ok(visible) => {
      state.visible = visible
      Ok(tray_state_json(state, status="delegated").stringify())
    }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_destroy(state : TrayState) -> Result[String, String] {
  state.destroyed = true
  state.visible = false
  Ok(tray_state_json(state, status="delegated").stringify())
}

///|
fn tray_state_json(state : TrayState, status~ : String) -> Json {
  Json::object({
    "status": Json::string(status),
    "iconPath": optional_string_json(state.icon_path()),
    "tooltip": optional_string_json(state.tooltip()),
    "menu": Json::array(state.menu().map(tray_menu_item_json)),
    "visible": Json::boolean(state.visible()),
    "destroyed": Json::boolean(state.destroyed()),
  })
}

///|
fn tray_menu_item_json(item : TrayMenuItem) -> Json {
  Json::object({
    "id": Json::string(item.id()),
    "label": Json::string(item.label()),
    "kind": Json::string(tray_kind_name(item.kind())),
    "enabled": Json::boolean(item.enabled()),
    "checked": Json::boolean(item.checked()),
  })
}

///|
fn tray_kind_name(kind : TrayMenuItemKind) -> String {
  match kind {
    Action => "action"
    Separator => "separator"
    Check => "check"
  }
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn decode_string_payload(
  payload : String,
  field~ : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    String(value) =>
      if value == "" {
        Err("\{context} \{field} is required")
      } else {
        Ok(value)
      }
    Object(object) =>
      match string_field(object, field) {
        Some(value) =>
          if value == "" {
            Err("\{context} \{field} is required")
          } else {
            Ok(value)
          }
        None => Err("\{context} \{field} is required")
      }
    _ => Err("\{context} payload must be a string or object")
  }
}

///|
fn decode_visible_payload(payload : String) -> Result[Bool, String] {
  if payload == "" {
    return Err("tray setVisible payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid tray setVisible payload: \{error}")
  }
  match json {
    True => Ok(true)
    False => Ok(false)
    Object(object) =>
      match bool_field(object, "visible") {
        Some(visible) => Ok(visible)
        None => Err("tray setVisible visible is required")
      }
    _ => Err("tray setVisible payload must be a boolean or object")
  }
}

///|
fn decode_menu_payload(payload : String) -> Result[Array[TrayMenuItem], String] {
  if payload == "" {
    return Err("tray setMenu payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid tray setMenu payload: \{error}")
  }
  match json {
    Array(items) => decode_menu_items(items)
    Object(object) =>
      match object.get("items") {
        Some(Array(items)) => decode_menu_items(items)
        Some(_) => Err("tray setMenu items must be an array")
        None => Err("tray setMenu items are required")
      }
    _ => Err("tray setMenu payload must be an array or object")
  }
}

///|
fn decode_menu_items(
  items : Array[Json],
) -> Result[Array[TrayMenuItem], String] {
  let menu : Array[TrayMenuItem] = []
  for item in items {
    match decode_menu_item(item) {
      Ok(item) => menu.push(item)
      Err(problem) => return Err(problem)
    }
  }
  Ok(menu)
}

///|
fn decode_menu_item(json : Json) -> Result[TrayMenuItem, String] {
  match json {
    Object(object) => {
      let kind = string_field(object, "kind").unwrap_or("action")
      match kind {
        "separator" => Ok(TrayMenuItem::separator())
        "action" => {
          let id = string_field(object, "id").unwrap_or("")
          let label = string_field(object, "label").unwrap_or("")
          let enabled = bool_field(object, "enabled").unwrap_or(true)
          Ok(TrayMenuItem::action(id~, label~, enabled~))
        }
        "check" => {
          let id = string_field(object, "id").unwrap_or("")
          let label = string_field(object, "label").unwrap_or("")
          let checked = bool_field(object, "checked").unwrap_or(false)
          let enabled = bool_field(object, "enabled").unwrap_or(true)
          Ok(TrayMenuItem::check(id~, label~, checked~, enabled~))
        }
        _ => Err("tray menu item kind is invalid: \{kind}")
      }
    }
    _ => Err("tray menu items must be objects")
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn bool_field(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn first_problem(problems : Array[String]) -> String? {
  if problems.length() == 0 {
    None
  } else {
    Some(problems[0])
  }
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
