///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("process")
  .command_sync("info", permission=ProcessInfo)
  .command_sync("cwd", permission=ProcessInfo)
  .command_sync("env", permission=ProcessEnvironment)
  .command_sync("setEnv", permission=ProcessEnvironment)
  .command_async("exit", permission=ProcessControl)
}

///|
pub fn info_capability(name? : String = "process-info") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(ProcessInfo)
}

///|
pub fn environment_capability(
  name? : String = "process-environment",
) -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(ProcessEnvironment)
}

///|
pub fn control_capability(
  name? : String = "process-control",
) -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(ProcessControl)
}

///|
pub fn capability(name? : String = "process") -> @lepusa.Capability {
  @lepusa.Capability::new(name)
  .permission(ProcessInfo)
  .permission(ProcessEnvironment)
  .permission(ProcessControl)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "process",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn register(registry : @lepusa.CommandRegistry) -> @lepusa.CommandRegistry {
  registry
  .register_fn("process.info", permission=ProcessInfo, handler=handle_info)
  .register_fn("process.cwd", permission=ProcessInfo, handler=handle_cwd)
  .register_fn("process.env", permission=ProcessEnvironment, handler=handle_env)
  .register_fn(
    "process.setEnv",
    permission=ProcessEnvironment,
    handler=handle_set_env,
  )
}

///|
fn handle_info(_payload : String) -> Result[String, String] {
  let cwd = @env.current_dir().unwrap_or("")
  let args = @env.args().length()
  let env_count = @env.get_env_vars().length()
  Ok(
    Json::object({
      "cwd": Json::string(cwd),
      "args": json_int(args),
      "env": json_int(env_count),
    }).stringify(),
  )
}

///|
fn handle_cwd(_payload : String) -> Result[String, String] {
  match @env.current_dir() {
    Some(cwd) => Ok(Json::object({ "cwd": Json::string(cwd) }).stringify())
    None => Err("process cwd is unavailable")
  }
}

///|
fn handle_env(payload : String) -> Result[String, String] {
  match decode_key_payload(payload, context="process env") {
    Ok(key) =>
      match @env.get_env_var(key) {
        Some(value) =>
          Ok(
            Json::object({
              "key": Json::string(key),
              "value": Json::string(value),
              "found": Json::boolean(true),
            }).stringify(),
          )
        None =>
          Ok(
            Json::object({
              "key": Json::string(key),
              "value": Json::string(""),
              "found": Json::boolean(false),
            }).stringify(),
          )
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set_env(payload : String) -> Result[String, String] {
  match decode_set_env_payload(payload) {
    Ok((key, value)) => {
      @env.set_env_var(key, value)
      Ok(
        Json::object({
          "key": Json::string(key),
          "value": Json::string(value),
          "set": Json::boolean(true),
        }).stringify(),
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
fn decode_key_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  match parse_payload(payload, context~) {
    Ok(json) =>
      match json {
        String(key) => validate_key(key)
        Object(object) => validate_key(required_string_field(object, "key"))
        _ => Err("\{context} payload must be a string or object")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn decode_set_env_payload(payload : String) -> Result[(String, String), String] {
  match parse_payload(payload, context="process setEnv") {
    Ok(json) =>
      match json {
        Object(object) => {
          let key = required_string_field(object, "key")
          let value = required_string_field(object, "value")
          match validate_key(key) {
            Ok(key) => Ok((key, value))
            Err(problem) => Err(problem)
          }
        }
        _ => Err("process setEnv payload must be an object")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn parse_payload(payload : String, context~ : String) -> Result[Json, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  try @json.parse(payload) catch {
    error => Err("invalid \{context} payload: \{error}")
  } noraise {
    json => Ok(json)
  }
}

///|
fn validate_key(key : String) -> Result[String, String] {
  if key == "" {
    Err("process env key is required")
  } else {
    Ok(key)
  }
}

///|
fn required_string_field(object : Map[String, Json], key : String) -> String {
  match object.get(key) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
fn json_int(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}
