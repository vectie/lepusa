///|
pub(all) enum AppControlAction {
  Show
  Hide
  SetTheme
  SetDockVisibility
  Exit
  Restart
} derive(Debug, Eq)

///|
pub(all) enum AppTheme {
  System
  Light
  Dark
} derive(Debug, Eq)

///|
pub struct AppInfo {
  name : String
  version : String
  identifier : String
} derive(Debug, Eq)

///|
pub struct AppControlOperation {
  action : AppControlAction
  payload : String
} derive(Debug, Eq)

///|
pub struct AppState {
  info : AppInfo
  mut visible : Bool
  mut theme : AppTheme
  mut dock_visible : Bool
  mut exit_requested : Bool
  mut restart_requested : Bool
  operations : Array[AppControlOperation]
}

///|
pub fn AppInfo::new(
  name~ : String,
  version~ : String,
  identifier~ : String,
) -> AppInfo {
  { name, version, identifier }
}

///|
pub fn AppInfo::from_metadata(metadata : @lepusa.AppMetadata) -> AppInfo {
  {
    name: metadata.product_name(),
    version: metadata.version(),
    identifier: metadata.identifier(),
  }
}

///|
pub fn AppInfo::default() -> AppInfo {
  AppInfo::new(
    name="Lepusa App",
    version="0.0.0",
    identifier="dev.vectie.lepusa",
  )
}

///|
pub fn AppInfo::name(self : AppInfo) -> String {
  self.name
}

///|
pub fn AppInfo::version(self : AppInfo) -> String {
  self.version
}

///|
pub fn AppInfo::identifier(self : AppInfo) -> String {
  self.identifier
}

///|
pub fn AppInfo::validate(self : AppInfo) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("app name is required")
  }
  if self.version == "" {
    problems.push("app version is required")
  }
  if self.identifier == "" {
    problems.push("app identifier is required")
  }
  problems
}

///|
pub fn AppState::new(
  info? : AppInfo = AppInfo::default(),
  visible? : Bool = true,
  theme? : AppTheme = System,
  dock_visible? : Bool = true,
) -> AppState {
  {
    info,
    visible,
    theme,
    dock_visible,
    exit_requested: false,
    restart_requested: false,
    operations: [],
  }
}

///|
pub fn AppState::info(self : AppState) -> AppInfo {
  self.info
}

///|
pub fn AppState::visible(self : AppState) -> Bool {
  self.visible
}

///|
pub fn AppState::theme(self : AppState) -> AppTheme {
  self.theme
}

///|
pub fn AppState::dock_visible(self : AppState) -> Bool {
  self.dock_visible
}

///|
pub fn AppState::exit_requested(self : AppState) -> Bool {
  self.exit_requested
}

///|
pub fn AppState::restart_requested(self : AppState) -> Bool {
  self.restart_requested
}

///|
pub fn AppState::operations(self : AppState) -> Array[AppControlOperation] {
  self.operations.copy()
}

///|
pub fn AppState::last(self : AppState) -> AppControlOperation? {
  self.operations.last()
}

///|
pub fn AppControlOperation::new(
  action~ : AppControlAction,
  payload? : String = "",
) -> AppControlOperation {
  { action, payload }
}

///|
pub fn AppControlOperation::action(
  self : AppControlOperation,
) -> AppControlAction {
  self.action
}

///|
pub fn AppControlOperation::payload(self : AppControlOperation) -> String {
  self.payload
}

///|
pub fn AppControlOperation::to_json(self : AppControlOperation) -> String {
  self.to_json_value().stringify()
}

///|
pub fn AppControlAction::name(self : AppControlAction) -> String {
  match self {
    Show => "show"
    Hide => "hide"
    SetTheme => "setTheme"
    SetDockVisibility => "setDockVisibility"
    Exit => "exit"
    Restart => "restart"
  }
}

///|
pub fn AppTheme::name(self : AppTheme) -> String {
  match self {
    System => "system"
    Light => "light"
    Dark => "dark"
  }
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("app")
  .command_sync("info", permission=App)
  .command_sync("name", permission=App)
  .command_sync("version", permission=App)
  .command_sync("identifier", permission=App)
  .command_sync("show", permission=App)
  .command_sync("hide", permission=App)
  .command_sync("setTheme", permission=App)
  .command_sync("setDockVisibility", permission=App)
  .command_sync("exit", permission=App)
  .command_sync("restart", permission=App)
  .command_event("onThemeChanged", permission=App)
}

///|
pub fn capability(name? : String = "app") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(App)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "app",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(state? : AppState = AppState::new()) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), state~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  state? : AppState = AppState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("app.info", permission=App, handler=_ => {
    Ok(app_state_json(state).stringify())
  })
  .register_fn("app.name", permission=App, handler=_ => {
    Ok(Json::object({ "name": Json::string(state.info().name()) }).stringify())
  })
  .register_fn("app.version", permission=App, handler=_ => {
    Ok(
      Json::object({ "version": Json::string(state.info().version()) }).stringify(),
    )
  })
  .register_fn("app.identifier", permission=App, handler=_ => {
    Ok(
      Json::object({ "identifier": Json::string(state.info().identifier()) }).stringify(),
    )
  })
  .register_fn("app.show", permission=App, handler=payload => {
    handle_control(state, payload, action=Show)
  })
  .register_fn("app.hide", permission=App, handler=payload => {
    handle_control(state, payload, action=Hide)
  })
  .register_fn("app.setTheme", permission=App, handler=payload => {
    handle_control(state, payload, action=SetTheme)
  })
  .register_fn("app.setDockVisibility", permission=App, handler=payload => {
    handle_control(state, payload, action=SetDockVisibility)
  })
  .register_fn("app.exit", permission=App, handler=payload => {
    handle_control(state, payload, action=Exit)
  })
  .register_fn("app.restart", permission=App, handler=payload => {
    handle_control(state, payload, action=Restart)
  })
}

///|
fn handle_control(
  state : AppState,
  payload : String,
  action~ : AppControlAction,
) -> Result[String, String] {
  match action {
    Show => state.visible = true
    Hide => state.visible = false
    SetTheme =>
      match parse_theme_payload(payload) {
        Ok(theme) => state.theme = theme
        Err(problem) => return Err(problem)
      }
    SetDockVisibility =>
      match parse_visibility_payload(payload) {
        Ok(visible) => state.dock_visible = visible
        Err(problem) => return Err(problem)
      }
    Exit => state.exit_requested = true
    Restart => state.restart_requested = true
  }
  let operation = AppControlOperation::new(action~, payload~)
  state.operations.push(operation)
  Ok(
    Json::object({
      "status": Json::string("queued"),
      "action": Json::string(action.name()),
      "operation": operation.to_json_value(),
      "app": app_state_json(state),
    }).stringify(),
  )
}

///|
fn parse_theme_payload(payload : String) -> Result[AppTheme, String] {
  let value = if payload == "" {
    "system"
  } else {
    let json = @json.parse(payload) catch {
      error => return Err("invalid app theme payload: \{error}")
    }
    match json {
      String(theme) => theme
      Object(object) => string_field(object, "theme").unwrap_or("system")
      _ => return Err("app theme payload must be a string or object")
    }
  }
  match value {
    "system" => Ok(System)
    "light" => Ok(Light)
    "dark" => Ok(Dark)
    _ => Err("app theme is invalid: \{value}")
  }
}

///|
fn parse_visibility_payload(payload : String) -> Result[Bool, String] {
  if payload == "" {
    return Ok(true)
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid app visibility payload: \{error}")
  }
  match json {
    True => Ok(true)
    False => Ok(false)
    Object(object) =>
      match object.get("visible") {
        Some(True) => Ok(true)
        Some(False) => Ok(false)
        Some(_) => Err("app visibility field must be boolean")
        None => Ok(true)
      }
    _ => Err("app visibility payload must be a boolean or object")
  }
}

///|
fn app_state_json(state : AppState) -> Json {
  Json::object({
    "name": Json::string(state.info().name()),
    "version": Json::string(state.info().version()),
    "identifier": Json::string(state.info().identifier()),
    "visible": Json::boolean(state.visible()),
    "theme": Json::string(state.theme().name()),
    "dockVisible": Json::boolean(state.dock_visible()),
    "exitRequested": Json::boolean(state.exit_requested()),
    "restartRequested": Json::boolean(state.restart_requested()),
  })
}

///|
fn AppControlOperation::to_json_value(self : AppControlOperation) -> Json {
  Json::object({
    "action": Json::string(self.action.name()),
    "payload": Json::string(self.payload),
  })
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
