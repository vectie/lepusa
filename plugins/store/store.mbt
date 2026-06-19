///|
pub struct Store {
  values : Map[String, String]
}

///|
pub fn Store::new() -> Store {
  { values: {} }
}

///|
pub fn Store::get(self : Store, key : String) -> String? {
  self.values.get(key)
}

///|
pub fn Store::set(self : Store, key : String, value : String) -> Unit {
  self.values[key] = value
}

///|
pub fn Store::delete(self : Store, key : String) -> Bool {
  let existed = self.values.contains(key)
  self.values.remove(key)
  existed
}

///|
pub fn Store::clear(self : Store) -> Int {
  let count = self.values.length()
  self.values.clear()
  count
}

///|
pub fn Store::keys(self : Store) -> Array[String] {
  let keys : Array[String] = []
  self.values.each(fn(key, _) { keys.push(key) })
  keys.sort()
  keys
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("store")
  .command_sync("get")
  .command_sync("set")
  .command_sync("delete")
  .command_sync("clear")
  .command_sync("keys")
}

///|
pub fn capability(name? : String = "store") -> @lepusa.Capability {
  @lepusa.Capability::new(name)
  .command("store.get")
  .command("store.set")
  .command("store.delete")
  .command("store.clear")
  .command("store.keys")
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "store",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(store? : Store = Store::new()) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), store~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  store? : Store = Store::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("store.get", handler=fn(payload) { handle_get(store, payload) })
  .register_fn("store.set", handler=fn(payload) { handle_set(store, payload) })
  .register_fn("store.delete", handler=fn(payload) {
    handle_delete(store, payload)
  })
  .register_fn("store.clear", handler=fn(_) { handle_clear(store) })
  .register_fn("store.keys", handler=fn(_) { handle_keys(store) })
}

///|
fn handle_get(store : Store, payload : String) -> Result[String, String] {
  match decode_key_payload(payload) {
    Ok(key) =>
      match store.get(key) {
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
fn handle_set(store : Store, payload : String) -> Result[String, String] {
  match decode_set_payload(payload) {
    Ok((key, value)) => {
      store.set(key, value)
      Ok(
        Json::object({ "key": Json::string(key), "value": Json::string(value) }).stringify(),
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_delete(store : Store, payload : String) -> Result[String, String] {
  match decode_key_payload(payload) {
    Ok(key) => {
      let deleted = store.delete(key)
      Ok(
        Json::object({
          "key": Json::string(key),
          "deleted": Json::boolean(deleted),
        }).stringify(),
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_clear(store : Store) -> Result[String, String] {
  let count = store.clear()
  Ok(
    Json::object({
      "cleared": Json::number(count.to_double(), repr=count.to_string()),
    }).stringify(),
  )
}

///|
fn handle_keys(store : Store) -> Result[String, String] {
  Ok(
    Json::object({
      "keys": Json::array(store.keys().map(fn(key) { Json::string(key) })),
    }).stringify(),
  )
}

///|
fn decode_key_payload(payload : String) -> Result[String, String] {
  match parse_payload(payload) {
    Ok(json) =>
      match json {
        String(key) => validate_key(key)
        Object(object) => validate_key(required_string_field(object, "key"))
        _ => Err("store key payload must be a string or object")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn decode_set_payload(payload : String) -> Result[(String, String), String] {
  match parse_payload(payload) {
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
        _ => Err("store set payload must be an object")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn parse_payload(payload : String) -> Result[Json, String] {
  if payload == "" {
    return Err("store payload is required")
  }
  try @json.parse(payload) catch {
    error => Err("invalid store payload: \{error}")
  } noraise {
    json => Ok(json)
  }
}

///|
fn validate_key(key : String) -> Result[String, String] {
  if key == "" {
    Err("store key is required")
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
