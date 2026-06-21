///|
pub(all) enum MenuItemKind {
  Action
  Separator
  Check
  Submenu
} derive(Debug, Eq)

///|
pub(all) enum MenuControlAction {
  SetAppMenu
  SetWindowMenu
  ClearAppMenu
  ClearWindowMenu
  SetItemEnabled
  SetItemChecked
  ActivateItem
} derive(Debug, Eq)

///|
pub(all) enum MenuTarget {
  AppMenu
  WindowMenu(String)
} derive(Debug, Eq)

///|
pub struct MenuItem {
  id : String
  label : String
  kind : MenuItemKind
  accelerator : String?
  enabled : Bool
  checked : Bool
  items : Array[MenuItem]
} derive(Debug, Eq)

///|
pub struct MenuBar {
  items : Array[MenuItem]
} derive(Debug, Eq)

///|
pub struct MenuOperation {
  target : MenuTarget
  action : MenuControlAction
  payload : String
} derive(Debug, Eq)

///|
pub struct MenuState {
  mut app_menu : MenuBar?
  window_menus : Map[String, MenuBar]
  mut last_activated : String?
  operations : Array[MenuOperation]
}

///|
priv struct MenuUpdateResult {
  items : Array[MenuItem]
  found : Bool
}

///|
priv struct MenuItemUpdate {
  id : String
  enabled : Bool?
  checked : Bool?
  target : MenuTarget
}

///|
pub fn MenuItem::action(
  id~ : String,
  label~ : String,
  accelerator? : String,
  enabled? : Bool = true,
) -> MenuItem {
  { id, label, kind: Action, accelerator, enabled, checked: false, items: [] }
}

///|
pub fn MenuItem::separator() -> MenuItem {
  {
    id: "",
    label: "",
    kind: Separator,
    accelerator: None,
    enabled: false,
    checked: false,
    items: [],
  }
}

///|
pub fn MenuItem::check(
  id~ : String,
  label~ : String,
  checked? : Bool = false,
  accelerator? : String,
  enabled? : Bool = true,
) -> MenuItem {
  { id, label, kind: Check, accelerator, enabled, checked, items: [] }
}

///|
pub fn MenuItem::submenu(
  id~ : String,
  label~ : String,
  items? : Array[MenuItem] = [],
  enabled? : Bool = true,
) -> MenuItem {
  {
    id,
    label,
    kind: Submenu,
    accelerator: None,
    enabled,
    checked: false,
    items: items.copy(),
  }
}

///|
pub fn MenuItem::id(self : MenuItem) -> String {
  self.id
}

///|
pub fn MenuItem::label(self : MenuItem) -> String {
  self.label
}

///|
pub fn MenuItem::kind(self : MenuItem) -> MenuItemKind {
  self.kind
}

///|
pub fn MenuItem::accelerator(self : MenuItem) -> String? {
  self.accelerator
}

///|
pub fn MenuItem::enabled(self : MenuItem) -> Bool {
  self.enabled
}

///|
pub fn MenuItem::checked(self : MenuItem) -> Bool {
  self.checked
}

///|
pub fn MenuItem::items(self : MenuItem) -> Array[MenuItem] {
  self.items.copy()
}

///|
pub fn MenuItem::validate(self : MenuItem) -> Array[String] {
  let problems : Array[String] = []
  match self.kind {
    Separator => ()
    Action | Check | Submenu => {
      if self.id == "" {
        problems.push("menu item id is required")
      } else if invalid_menu_id(self.id) {
        problems.push("menu item id is invalid: \{self.id}")
      }
      if self.label == "" {
        problems.push("menu item label is required")
      }
    }
  }
  match self.accelerator {
    Some("") => problems.push("menu item accelerator is required")
    Some(value) =>
      if invalid_accelerator(value) {
        problems.push("menu item accelerator is invalid: \{value}")
      }
    None => ()
  }
  match self.kind {
    Submenu => {
      if self.items.is_empty() {
        problems.push("submenu items are required")
      }
      for item in self.items {
        problems.append(item.validate())
      }
    }
    Action | Check | Separator =>
      if !self.items.is_empty() {
        problems.push("menu item children are only allowed for submenu")
      }
  }
  problems
}

///|
pub fn MenuBar::new(items? : Array[MenuItem] = []) -> MenuBar {
  { items: items.copy() }
}

///|
pub fn MenuBar::item(self : MenuBar, item : MenuItem) -> MenuBar {
  let items = self.items.copy()
  items.push(item)
  { items, }
}

///|
pub fn MenuBar::items(self : MenuBar) -> Array[MenuItem] {
  self.items.copy()
}

///|
pub fn MenuBar::validate(self : MenuBar) -> Array[String] {
  let problems : Array[String] = []
  if self.items.is_empty() {
    problems.push("menu items are required")
  }
  let seen : Array[String] = []
  validate_menu_items(self.items, seen, problems)
  problems
}

///|
pub fn MenuState::new(app_menu? : MenuBar) -> MenuState {
  { app_menu, window_menus: {}, last_activated: None, operations: [] }
}

///|
pub fn MenuState::app_menu(self : MenuState) -> MenuBar? {
  self.app_menu
}

///|
pub fn MenuState::window_menu(
  self : MenuState,
  window_label : String,
) -> MenuBar? {
  self.window_menus.get(window_label)
}

///|
pub fn MenuState::last_activated(self : MenuState) -> String? {
  self.last_activated
}

///|
pub fn MenuState::operations(self : MenuState) -> Array[MenuOperation] {
  self.operations.copy()
}

///|
pub fn MenuState::last(self : MenuState) -> MenuOperation? {
  self.operations.last()
}

///|
pub fn MenuOperation::new(
  target~ : MenuTarget,
  action~ : MenuControlAction,
  payload? : String = "",
) -> MenuOperation {
  { target, action, payload }
}

///|
pub fn MenuOperation::target(self : MenuOperation) -> MenuTarget {
  self.target
}

///|
pub fn MenuOperation::action(self : MenuOperation) -> MenuControlAction {
  self.action
}

///|
pub fn MenuOperation::payload(self : MenuOperation) -> String {
  self.payload
}

///|
pub fn MenuOperation::to_json(self : MenuOperation) -> String {
  menu_operation_json(self).stringify()
}

///|
pub fn MenuControlAction::name(self : MenuControlAction) -> String {
  match self {
    SetAppMenu => "setAppMenu"
    SetWindowMenu => "setWindowMenu"
    ClearAppMenu => "clearAppMenu"
    ClearWindowMenu => "clearWindowMenu"
    SetItemEnabled => "setItemEnabled"
    SetItemChecked => "setItemChecked"
    ActivateItem => "activateItem"
  }
}

///|
pub fn MenuTarget::name(self : MenuTarget) -> String {
  match self {
    AppMenu => "app"
    WindowMenu(_) => "window"
  }
}

///|
pub fn MenuTarget::window_label(self : MenuTarget) -> String? {
  match self {
    AppMenu => None
    WindowMenu(label) => Some(label)
  }
}

///|
pub fn MenuItemKind::name(self : MenuItemKind) -> String {
  match self {
    Action => "action"
    Separator => "separator"
    Check => "check"
    Submenu => "submenu"
  }
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("menu")
  .command_sync("setAppMenu", permission=Menu, affinity=MainThread)
  .command_sync("setWindowMenu", permission=Menu, affinity=MainThread)
  .command_sync("clearAppMenu", permission=Menu, affinity=MainThread)
  .command_sync("clearWindowMenu", permission=Menu, affinity=MainThread)
  .command_sync("setItemEnabled", permission=Menu, affinity=MainThread)
  .command_sync("setItemChecked", permission=Menu, affinity=MainThread)
  .command_sync("activateItem", permission=Menu, affinity=MainThread)
  .command_event("onItemClick", permission=Menu, affinity=MainThread)
}

///|
pub fn capability(name? : String = "menu") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Menu)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "menu",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(
  state? : MenuState = MenuState::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), state~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  state? : MenuState = MenuState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("menu.setAppMenu", permission=Menu, handler=payload => {
    handle_set_app_menu(state, payload)
  })
  .register_fn("menu.setWindowMenu", permission=Menu, handler=payload => {
    handle_set_window_menu(state, payload)
  })
  .register_fn("menu.clearAppMenu", permission=Menu, handler=payload => {
    handle_clear_app_menu(state, payload)
  })
  .register_fn("menu.clearWindowMenu", permission=Menu, handler=payload => {
    handle_clear_window_menu(state, payload)
  })
  .register_fn("menu.setItemEnabled", permission=Menu, handler=payload => {
    handle_set_item_enabled(state, payload)
  })
  .register_fn("menu.setItemChecked", permission=Menu, handler=payload => {
    handle_set_item_checked(state, payload)
  })
  .register_fn("menu.activateItem", permission=Menu, handler=payload => {
    handle_activate_item(state, payload)
  })
}

///|
fn handle_set_app_menu(
  state : MenuState,
  payload : String,
) -> Result[String, String] {
  match decode_menu_payload(payload, context="menu setAppMenu") {
    Ok(menu) =>
      match first_problem(menu.validate()) {
        Some(problem) => Err(problem)
        None => {
          state.app_menu = Some(menu)
          record(state, target=AppMenu, action=SetAppMenu, payload~)
        }
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set_window_menu(
  state : MenuState,
  payload : String,
) -> Result[String, String] {
  match decode_window_menu_payload(payload) {
    Ok((window_label, menu)) =>
      match first_problem(menu.validate()) {
        Some(problem) => Err(problem)
        None => {
          state.window_menus[window_label] = menu
          record(
            state,
            target=WindowMenu(window_label),
            action=SetWindowMenu,
            payload~,
          )
        }
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_clear_app_menu(
  state : MenuState,
  payload : String,
) -> Result[String, String] {
  state.app_menu = None
  record(state, target=AppMenu, action=ClearAppMenu, payload~)
}

///|
fn handle_clear_window_menu(
  state : MenuState,
  payload : String,
) -> Result[String, String] {
  match decode_window_label_payload(payload, context="menu clearWindowMenu") {
    Ok(window_label) => {
      state.window_menus.remove(window_label)
      record(
        state,
        target=WindowMenu(window_label),
        action=ClearWindowMenu,
        payload~,
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set_item_enabled(
  state : MenuState,
  payload : String,
) -> Result[String, String] {
  match decode_item_update_payload(payload, field="enabled") {
    Ok(update) =>
      update_menu_item(state, update, action=SetItemEnabled, payload~)
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set_item_checked(
  state : MenuState,
  payload : String,
) -> Result[String, String] {
  match decode_item_update_payload(payload, field="checked") {
    Ok(update) =>
      update_menu_item(state, update, action=SetItemChecked, payload~)
    Err(problem) => Err(problem)
  }
}

///|
fn handle_activate_item(
  state : MenuState,
  payload : String,
) -> Result[String, String] {
  match decode_item_activation_payload(payload) {
    Ok((target, id)) =>
      if menu_contains_item(state, target, id) {
        state.last_activated = Some(id)
        record(state, target~, action=ActivateItem, payload~)
      } else {
        Err("menu item not found: \{id}")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn update_menu_item(
  state : MenuState,
  update : MenuItemUpdate,
  action~ : MenuControlAction,
  payload~ : String,
) -> Result[String, String] {
  match update.target {
    AppMenu =>
      match state.app_menu {
        None => Err("app menu is not set")
        Some(menu) =>
          match menu.update_item(update) {
            Ok(menu) => {
              state.app_menu = Some(menu)
              record(state, target=AppMenu, action~, payload~)
            }
            Err(problem) => Err(problem)
          }
      }
    WindowMenu(label) =>
      match state.window_menus.get(label) {
        None => Err("window menu is not set: \{label}")
        Some(menu) =>
          match menu.update_item(update) {
            Ok(menu) => {
              state.window_menus[label] = menu
              record(state, target=WindowMenu(label), action~, payload~)
            }
            Err(problem) => Err(problem)
          }
      }
  }
}

///|
fn record(
  state : MenuState,
  target~ : MenuTarget,
  action~ : MenuControlAction,
  payload~ : String,
) -> Result[String, String] {
  let operation = MenuOperation::new(target~, action~, payload~)
  state.operations.push(operation)
  Ok(
    Json::object({
      "status": Json::string("queued"),
      "action": Json::string(action.name()),
      "target": menu_target_json(target),
      "operation": menu_operation_json(operation),
      "menu": menu_state_json(state),
    }).stringify(),
  )
}

///|
fn MenuBar::update_item(
  self : MenuBar,
  update : MenuItemUpdate,
) -> Result[MenuBar, String] {
  let result = update_menu_items(self.items, update)
  if result.found {
    Ok(MenuBar::new(items=result.items))
  } else {
    Err("menu item not found: \{update.id}")
  }
}

///|
fn update_menu_items(
  items : Array[MenuItem],
  update : MenuItemUpdate,
) -> MenuUpdateResult {
  let next : Array[MenuItem] = []
  let mut found = false
  for item in items {
    if item.id() == update.id {
      next.push(apply_item_update(item, update))
      found = true
    } else if item.kind() is Submenu {
      let child = update_menu_items(item.items(), update)
      next.push({ ..item, items: child.items })
      found = found || child.found
    } else {
      next.push(item)
    }
  }
  { items: next, found }
}

///|
fn apply_item_update(item : MenuItem, update : MenuItemUpdate) -> MenuItem {
  let mut next = item
  match update.enabled {
    Some(enabled) => next = { ..next, enabled, }
    None => ()
  }
  match update.checked {
    Some(checked) => next = { ..next, checked, }
    None => ()
  }
  next
}

///|
fn menu_contains_item(
  state : MenuState,
  target : MenuTarget,
  id : String,
) -> Bool {
  match target {
    AppMenu =>
      match state.app_menu {
        Some(menu) => menu.contains_item(id)
        None => false
      }
    WindowMenu(label) =>
      match state.window_menus.get(label) {
        Some(menu) => menu.contains_item(id)
        None => false
      }
  }
}

///|
fn MenuBar::contains_item(self : MenuBar, id : String) -> Bool {
  menu_items_contain(self.items, id)
}

///|
fn menu_items_contain(items : Array[MenuItem], id : String) -> Bool {
  for item in items {
    if item.id() == id || menu_items_contain(item.items(), id) {
      return true
    }
  }
  false
}

///|
fn validate_menu_items(
  items : Array[MenuItem],
  seen : Array[String],
  problems : Array[String],
) -> Unit {
  for item in items {
    problems.append(item.validate())
    let id = item.id()
    if id != "" {
      if seen.contains(id) {
        problems.push("menu item must be unique: \{id}")
      } else {
        seen.push(id)
      }
    }
    validate_menu_items(item.items(), seen, problems)
  }
}

///|
fn decode_menu_payload(
  payload : String,
  context~ : String,
) -> Result[MenuBar, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    Array(items) => decode_menu_items(items)
    Object(object) =>
      match object.get("items") {
        Some(Array(items)) => decode_menu_items(items)
        Some(_) => Err("\{context} items must be an array")
        None => Err("\{context} items are required")
      }
    _ => Err("\{context} payload must be an array or object")
  }
}

///|
fn decode_window_menu_payload(
  payload : String,
) -> Result[(String, MenuBar), String] {
  if payload == "" {
    return Err("menu setWindowMenu payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid menu setWindowMenu payload: \{error}")
  }
  match json {
    Object(object) => {
      let window_label = string_field(object, "windowLabel").unwrap_or("main")
      match validate_window_label(window_label, context="menu setWindowMenu") {
        Ok(window_label) =>
          match object.get("items") {
            Some(Array(items)) =>
              match decode_menu_items(items) {
                Ok(menu) => Ok((window_label, menu))
                Err(problem) => Err(problem)
              }
            Some(_) => Err("menu setWindowMenu items must be an array")
            None => Err("menu setWindowMenu items are required")
          }
        Err(problem) => Err(problem)
      }
    }
    _ => Err("menu setWindowMenu payload must be an object")
  }
}

///|
fn decode_menu_items(items : Array[Json]) -> Result[MenuBar, String] {
  let menu_items : Array[MenuItem] = []
  for item in items {
    match decode_menu_item(item) {
      Ok(item) => menu_items.push(item)
      Err(problem) => return Err(problem)
    }
  }
  Ok(MenuBar::new(items=menu_items))
}

///|
fn decode_menu_item(json : Json) -> Result[MenuItem, String] {
  match json {
    Object(object) => {
      let kind = string_field(object, "kind").unwrap_or("action")
      match kind {
        "separator" => Ok(MenuItem::separator())
        "action" =>
          Ok(
            MenuItem::action(
              id=string_field(object, "id").unwrap_or(""),
              label=string_field(object, "label").unwrap_or(""),
              accelerator?=string_field(object, "accelerator"),
              enabled=bool_field(object, "enabled").unwrap_or(true),
            ),
          )
        "check" =>
          Ok(
            MenuItem::check(
              id=string_field(object, "id").unwrap_or(""),
              label=string_field(object, "label").unwrap_or(""),
              checked=bool_field(object, "checked").unwrap_or(false),
              accelerator?=string_field(object, "accelerator"),
              enabled=bool_field(object, "enabled").unwrap_or(true),
            ),
          )
        "submenu" =>
          match object.get("items") {
            Some(Array(items)) =>
              match decode_menu_items(items) {
                Ok(menu) =>
                  Ok(
                    MenuItem::submenu(
                      id=string_field(object, "id").unwrap_or(""),
                      label=string_field(object, "label").unwrap_or(""),
                      items=menu.items(),
                      enabled=bool_field(object, "enabled").unwrap_or(true),
                    ),
                  )
                Err(problem) => Err(problem)
              }
            Some(_) => Err("submenu items must be an array")
            None => Err("submenu items are required")
          }
        _ => Err("menu item kind is invalid: \{kind}")
      }
    }
    _ => Err("menu items must be objects")
  }
}

///|
fn decode_item_update_payload(
  payload : String,
  field~ : String,
) -> Result[MenuItemUpdate, String] {
  if payload == "" {
    return Err("menu setItem payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid menu setItem payload: \{error}")
  }
  match json {
    Object(object) => {
      let id = string_field(object, "id").unwrap_or("")
      match validate_menu_item_id(id, context="menu setItem") {
        Ok(id) =>
          match bool_field(object, field) {
            Some(value) =>
              match decode_target(object, context="menu setItem") {
                Ok(target) =>
                  Ok({
                    id,
                    enabled: if field == "enabled" {
                      Some(value)
                    } else {
                      None
                    },
                    checked: if field == "checked" {
                      Some(value)
                    } else {
                      None
                    },
                    target,
                  })
                Err(problem) => Err(problem)
              }
            None => Err("menu setItem \{field} is required")
          }
        Err(problem) => Err(problem)
      }
    }
    _ => Err("menu setItem payload must be an object")
  }
}

///|
fn decode_item_activation_payload(
  payload : String,
) -> Result[(MenuTarget, String), String] {
  if payload == "" {
    return Err("menu activateItem payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid menu activateItem payload: \{error}")
  }
  match json {
    String(id) =>
      match validate_menu_item_id(id, context="menu activateItem") {
        Ok(id) => Ok((AppMenu, id))
        Err(problem) => Err(problem)
      }
    Object(object) => {
      let id = string_field(object, "id").unwrap_or("")
      match validate_menu_item_id(id, context="menu activateItem") {
        Ok(id) =>
          match decode_target(object, context="menu activateItem") {
            Ok(target) => Ok((target, id))
            Err(problem) => Err(problem)
          }
        Err(problem) => Err(problem)
      }
    }
    _ => Err("menu activateItem payload must be a string or object")
  }
}

///|
fn decode_window_label_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Ok("main")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    String(label) => validate_window_label(label, context~)
    Object(object) =>
      validate_window_label(
        string_field(object, "windowLabel").unwrap_or("main"),
        context~,
      )
    _ => Err("\{context} payload must be a string or object")
  }
}

///|
fn decode_target(
  object : Map[String, Json],
  context~ : String,
) -> Result[MenuTarget, String] {
  match string_field(object, "windowLabel") {
    Some(label) =>
      match validate_window_label(label, context~) {
        Ok(label) => Ok(WindowMenu(label))
        Err(problem) => Err(problem)
      }
    None => Ok(AppMenu)
  }
}

///|
fn validate_window_label(
  label : String,
  context~ : String,
) -> Result[String, String] {
  if label == "" {
    Err("\{context} windowLabel is required")
  } else if invalid_window_label(label) {
    Err("\{context} windowLabel is invalid: \{label}")
  } else {
    Ok(label)
  }
}

///|
fn validate_menu_item_id(
  id : String,
  context~ : String,
) -> Result[String, String] {
  if id == "" {
    Err("\{context} id is required")
  } else if invalid_menu_id(id) {
    Err("\{context} id is invalid: \{id}")
  } else {
    Ok(id)
  }
}

///|
fn menu_state_json(state : MenuState) -> Json {
  let window_entries : Array[Json] = []
  state.window_menus.each(fn(label, menu) {
    window_entries.push(
      Json::object({
        "windowLabel": Json::string(label),
        "items": menu_items_json(menu.items()),
      }),
    )
  })
  Json::object({
    "appMenu": optional_menu_json(state.app_menu()),
    "windowMenus": Json::array(window_entries),
    "lastActivated": optional_string_json(state.last_activated()),
  })
}

///|
fn optional_menu_json(menu : MenuBar?) -> Json {
  match menu {
    Some(menu) => Json::object({ "items": menu_items_json(menu.items()) })
    None => Json::null()
  }
}

///|
fn menu_items_json(items : Array[MenuItem]) -> Json {
  Json::array(items.map(menu_item_json))
}

///|
fn menu_item_json(item : MenuItem) -> Json {
  Json::object({
    "id": Json::string(item.id()),
    "label": Json::string(item.label()),
    "kind": Json::string(item.kind().name()),
    "accelerator": optional_string_json(item.accelerator()),
    "enabled": Json::boolean(item.enabled()),
    "checked": Json::boolean(item.checked()),
    "items": menu_items_json(item.items()),
  })
}

///|
fn menu_operation_json(operation : MenuOperation) -> Json {
  Json::object({
    "target": menu_target_json(operation.target()),
    "action": Json::string(operation.action().name()),
    "payload": Json::string(operation.payload()),
  })
}

///|
fn menu_target_json(target : MenuTarget) -> Json {
  Json::object({
    "kind": Json::string(target.name()),
    "windowLabel": optional_string_json(target.window_label()),
  })
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
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
fn invalid_menu_id(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}

///|
fn invalid_window_label(label : String) -> Bool {
  label.contains("/") || label.contains("\\") || label.contains("..")
}

///|
fn invalid_accelerator(value : String) -> Bool {
  value.contains("\n") || value.contains("\t")
}
