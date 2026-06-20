///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("notification")
  .command_sync("show", permission=Notification)
  .command_sync("permissionState", permission=Notification)
  .command_sync("requestPermission", permission=Notification)
}

///|
pub fn capability(name? : String = "notification") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Notification)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "notification",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
#cfg(target="native")
extern "c" fn native_available_code() -> Int = "lepusa_notification_available"

///|
#cfg(target="native")
#borrow(title, body)
extern "c" fn native_show_code(title : Bytes, body : Bytes) -> Int = "lepusa_notification_show"

///|
#cfg(not(target="native"))
fn native_available_code() -> Int {
  0
}

///|
#cfg(not(target="native"))
fn native_show_code(_title : Bytes, _body : Bytes) -> Int {
  2
}

///|
pub fn native_available() -> Bool {
  native_available_code() == 1
}

///|
pub(all) enum NotificationPermissionState {
  Default
  Granted
  Denied
} derive(Debug, Eq)

///|
pub struct NotificationCenter {
  mut permission : NotificationPermissionState
  delivered : Array[String]
}

///|
pub fn NotificationCenter::new(
  permission? : NotificationPermissionState = Default,
) -> NotificationCenter {
  { permission, delivered: [] }
}

///|
pub fn NotificationCenter::permission(
  self : NotificationCenter,
) -> NotificationPermissionState {
  self.permission
}

///|
pub fn NotificationCenter::set_permission(
  self : NotificationCenter,
  permission : NotificationPermissionState,
) -> Unit {
  self.permission = permission
}

///|
pub fn NotificationCenter::delivered(
  self : NotificationCenter,
) -> Array[String] {
  self.delivered.copy()
}

///|
pub fn registry(
  center? : NotificationCenter = NotificationCenter::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), center~)
}

///|
pub fn native_registry() -> @lepusa.CommandRegistry {
  register_native(@lepusa.CommandRegistry::new())
}

///|
pub fn auto_registry(
  center? : NotificationCenter = NotificationCenter::new(),
) -> @lepusa.CommandRegistry {
  if native_available() {
    native_registry()
  } else {
    registry(center~)
  }
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  center? : NotificationCenter = NotificationCenter::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("notification.show", permission=Notification, handler=payload => {
    handle_show(center, payload)
  })
  .register_fn("notification.permissionState", permission=Notification, handler=_ => {
    handle_permission_state(center)
  })
  .register_fn("notification.requestPermission", permission=Notification, handler=_ => {
    handle_request_permission(center)
  })
}

///|
pub fn register_native(
  registry : @lepusa.CommandRegistry,
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("notification.show", permission=Notification, handler=payload => {
    handle_native_show(payload)
  })
  .register_fn("notification.permissionState", permission=Notification, handler=_ => {
    handle_native_permission_state()
  })
  .register_fn("notification.requestPermission", permission=Notification, handler=_ => {
    handle_native_request_permission()
  })
}

///|
fn handle_show(
  center : NotificationCenter,
  payload : String,
) -> Result[String, String] {
  match decode_notification_payload(payload) {
    Ok((title, body)) => {
      if center.permission() is Denied {
        return Err("notification permission denied")
      }
      center.delivered.push(title)
      Ok(
        Json::object({
          "title": Json::string(title),
          "body": Json::string(body),
          "permission": Json::string(permission_name(center.permission())),
          "shown": Json::boolean(center.permission() is Granted),
          "queued": Json::boolean(!(center.permission() is Granted)),
        }).stringify(),
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_permission_state(
  center : NotificationCenter,
) -> Result[String, String] {
  Ok(permission_json(center.permission()).stringify())
}

///|
fn handle_request_permission(
  center : NotificationCenter,
) -> Result[String, String] {
  if center.permission() is Default {
    center.set_permission(Granted)
  }
  Ok(permission_json(center.permission()).stringify())
}

///|
fn handle_native_show(payload : String) -> Result[String, String] {
  match decode_notification_payload(payload) {
    Ok((title, body)) =>
      match native_show_code(@utf8.encode(title), @utf8.encode(body)) {
        0 =>
          Ok(
            Json::object({
              "title": Json::string(title),
              "body": Json::string(body),
              "permission": Json::string("granted"),
              "shown": Json::boolean(true),
              "queued": Json::boolean(false),
              "native": Json::boolean(true),
            }).stringify(),
          )
        2 => Err("native notification is unavailable on this platform")
        code => Err("native notification show failed: code \{code}")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_native_permission_state() -> Result[String, String] {
  Ok(native_permission_json().stringify())
}

///|
fn handle_native_request_permission() -> Result[String, String] {
  Ok(native_permission_json().stringify())
}

///|
fn decode_notification_payload(
  payload : String,
) -> Result[(String, String), String] {
  if payload == "" {
    return Err("notification show payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid notification show payload: \{error}")
  }
  match json {
    String(title) => require_title(title, body="")
    Object(object) =>
      require_title(
        string_field(object, "title").unwrap_or(""),
        body=string_field(object, "body").unwrap_or(""),
      )
    _ => Err("notification show payload must be a string or object")
  }
}

///|
fn require_title(
  title : String,
  body~ : String,
) -> Result[(String, String), String] {
  if title == "" {
    Err("notification title is required")
  } else {
    Ok((title, body))
  }
}

///|
fn permission_json(permission : NotificationPermissionState) -> Json {
  Json::object({ "permission": Json::string(permission_name(permission)) })
}

///|
fn native_permission_json() -> Json {
  Json::object({
    "permission": Json::string(
      if native_available() {
        "granted"
      } else {
        "default"
      },
    ),
    "native": Json::boolean(native_available()),
  })
}

///|
fn permission_name(permission : NotificationPermissionState) -> String {
  match permission {
    Default => "default"
    Granted => "granted"
    Denied => "denied"
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
