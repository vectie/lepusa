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
