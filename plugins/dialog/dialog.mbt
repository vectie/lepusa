///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("dialog")
  .command_async("message", permission=Dialog, affinity=MainThread)
  .command_async("confirm", permission=Dialog, affinity=MainThread)
  .command_async("prompt", permission=Dialog, affinity=MainThread)
}

///|
pub fn capability(name? : String = "dialog") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Dialog)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "dialog",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub struct DialogPolicy {
  confirm_default : Bool
  prompt_default : String
}

///|
pub fn DialogPolicy::new(
  confirm_default? : Bool = false,
  prompt_default? : String = "",
) -> DialogPolicy {
  { confirm_default, prompt_default }
}

///|
pub fn DialogPolicy::confirm_default(self : DialogPolicy) -> Bool {
  self.confirm_default
}

///|
pub fn DialogPolicy::prompt_default(self : DialogPolicy) -> String {
  self.prompt_default
}

///|
pub fn registry(
  policy? : DialogPolicy = DialogPolicy::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : DialogPolicy = DialogPolicy::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_async_fn("dialog.message", permission=Dialog, handler=payload => {
    handle_message(payload)
  })
  .register_async_fn("dialog.confirm", permission=Dialog, handler=payload => {
    handle_confirm(policy, payload)
  })
  .register_async_fn("dialog.prompt", permission=Dialog, handler=payload => {
    handle_prompt(policy, payload)
  })
}

///|
async fn handle_message(payload : String) -> Result[String, String] {
  @async.sleep(0)
  match decode_dialog_payload(payload, context="dialog message") {
    Ok((title, message)) =>
      Ok(
        Json::object({
          "title": Json::string(title),
          "message": Json::string(message),
          "status": Json::string("acknowledged"),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_confirm(
  policy : DialogPolicy,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_dialog_payload(payload, context="dialog confirm") {
    Ok((title, message)) =>
      Ok(
        Json::object({
          "title": Json::string(title),
          "message": Json::string(message),
          "confirmed": Json::boolean(confirm_default(payload, policy)),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_prompt(
  policy : DialogPolicy,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_dialog_payload(payload, context="dialog prompt") {
    Ok((title, message)) => {
      let value = prompt_default(payload, policy)
      Ok(
        Json::object({
          "title": Json::string(title),
          "message": Json::string(message),
          "value": Json::string(value),
          "submitted": Json::boolean(value != ""),
        }).stringify(),
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
fn decode_dialog_payload(
  payload : String,
  context~ : String,
) -> Result[(String, String), String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    String(message) => Ok(("", message))
    Object(object) => {
      let title = string_field(object, "title").unwrap_or("")
      let message = string_field(object, "message").unwrap_or(
        string_field(object, "text").unwrap_or(""),
      )
      if message == "" {
        Err("\{context} message is required")
      } else {
        Ok((title, message))
      }
    }
    _ => Err("\{context} payload must be a string or object")
  }
}

///|
fn confirm_default(payload : String, policy : DialogPolicy) -> Bool {
  match parse_object(payload) {
    Some(object) =>
      match object.get("default") {
        Some(True) => true
        Some(False) => false
        _ => policy.confirm_default()
      }
    None => policy.confirm_default()
  }
}

///|
fn prompt_default(payload : String, policy : DialogPolicy) -> String {
  match parse_object(payload) {
    Some(object) =>
      string_field(object, "defaultValue").unwrap_or(policy.prompt_default())
    None => policy.prompt_default()
  }
}

///|
fn parse_object(payload : String) -> Map[String, Json]? {
  let json = @json.parse(payload) catch { _ => return None }
  match json {
    Object(object) => Some(object)
    _ => None
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
