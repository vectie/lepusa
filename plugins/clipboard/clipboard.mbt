///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("clipboard")
  .command_async("readText", permission=Clipboard)
  .command_async("writeText", permission=Clipboard)
  .command_async("clear", permission=Clipboard)
}

///|
pub fn capability(name? : String = "clipboard") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Clipboard)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "clipboard",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub struct ClipboardStore {
  values : Map[String, String]
}

///|
pub fn ClipboardStore::new() -> ClipboardStore {
  { values: {} }
}

///|
pub fn ClipboardStore::read_text(self : ClipboardStore) -> String? {
  self.values.get("text")
}

///|
pub fn ClipboardStore::write_text(self : ClipboardStore, text : String) -> Unit {
  self.values["text"] = text
}

///|
pub fn ClipboardStore::clear(self : ClipboardStore) -> Bool {
  let existed = self.values.contains("text")
  self.values.remove("text")
  existed
}

///|
pub fn registry(
  store? : ClipboardStore = ClipboardStore::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), store~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  store? : ClipboardStore = ClipboardStore::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_async_fn("clipboard.readText", permission=Clipboard, handler=_ => {
    handle_read_text(store)
  })
  .register_async_fn("clipboard.writeText", permission=Clipboard, handler=payload => {
    handle_write_text(store, payload)
  })
  .register_async_fn("clipboard.clear", permission=Clipboard, handler=_ => {
    handle_clear(store)
  })
}

///|
async fn handle_read_text(store : ClipboardStore) -> Result[String, String] {
  @async.sleep(0)
  match store.read_text() {
    Some(text) =>
      Ok(
        Json::object({
          "text": Json::string(text),
          "found": Json::boolean(true),
        }).stringify(),
      )
    None =>
      Ok(
        Json::object({ "text": Json::string(""), "found": Json::boolean(false) }).stringify(),
      )
  }
}

///|
async fn handle_write_text(
  store : ClipboardStore,
  payload : String,
) -> Result[String, String] {
  @async.sleep(0)
  match decode_text_payload(payload, context="clipboard writeText") {
    Ok(text) => {
      store.write_text(text)
      Ok(
        Json::object({
          "text": Json::string(text),
          "written": Json::boolean(true),
        }).stringify(),
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
async fn handle_clear(store : ClipboardStore) -> Result[String, String] {
  @async.sleep(0)
  let cleared = store.clear()
  Ok(Json::object({ "cleared": Json::boolean(cleared) }).stringify())
}

///|
fn decode_text_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    String(text) => Ok(text)
    Object(object) =>
      match object.get("text") {
        Some(String(text)) => Ok(text)
        _ => Err("\{context} text is required")
      }
    _ => Err("\{context} payload must be a string or object")
  }
}
