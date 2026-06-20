///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("clipboard")
  .command_sync("readText", permission=Clipboard)
  .command_sync("writeText", permission=Clipboard)
  .command_sync("clear", permission=Clipboard)
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
#cfg(target="native")
extern "c" fn native_available_code() -> Int = "lepusa_clipboard_available"

///|
#cfg(target="native")
extern "c" fn native_read_text_packet() -> Bytes = "lepusa_clipboard_read_text"

///|
#cfg(target="native")
#borrow(text)
extern "c" fn native_write_text_code(text : Bytes) -> Int = "lepusa_clipboard_write_text"

///|
#cfg(target="native")
extern "c" fn native_clear_code() -> Int = "lepusa_clipboard_clear"

///|
#cfg(not(target="native"))
fn native_available_code() -> Int {
  0
}

///|
#cfg(not(target="native"))
fn native_read_text_packet() -> Bytes {
  b"err\nnative clipboard is unavailable"
}

///|
#cfg(not(target="native"))
fn native_write_text_code(_text : Bytes) -> Int {
  2
}

///|
#cfg(not(target="native"))
fn native_clear_code() -> Int {
  2
}

///|
pub fn native_available() -> Bool {
  native_available_code() == 1
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
pub fn native_registry() -> @lepusa.CommandRegistry {
  register_native(@lepusa.CommandRegistry::new())
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  store? : ClipboardStore = ClipboardStore::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("clipboard.readText", permission=Clipboard, handler=_ => {
    handle_read_text(store)
  })
  .register_fn("clipboard.writeText", permission=Clipboard, handler=payload => {
    handle_write_text(store, payload)
  })
  .register_fn("clipboard.clear", permission=Clipboard, handler=_ => {
    handle_clear(store)
  })
}

///|
pub fn register_native(
  registry : @lepusa.CommandRegistry,
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("clipboard.readText", permission=Clipboard, handler=_ => {
    handle_native_read_text()
  })
  .register_fn("clipboard.writeText", permission=Clipboard, handler=payload => {
    handle_native_write_text(payload)
  })
  .register_fn("clipboard.clear", permission=Clipboard, handler=_ => {
    handle_native_clear()
  })
}

///|
fn handle_read_text(store : ClipboardStore) -> Result[String, String] {
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
fn handle_write_text(
  store : ClipboardStore,
  payload : String,
) -> Result[String, String] {
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
fn handle_clear(store : ClipboardStore) -> Result[String, String] {
  let cleared = store.clear()
  Ok(Json::object({ "cleared": Json::boolean(cleared) }).stringify())
}

///|
fn handle_native_read_text() -> Result[String, String] {
  match decode_native_read_packet(native_read_text_packet()) {
    Ok(text) =>
      Ok(
        Json::object({
          "text": Json::string(text),
          "found": Json::boolean(text != ""),
          "native": Json::boolean(true),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
fn handle_native_write_text(payload : String) -> Result[String, String] {
  match decode_text_payload(payload, context="clipboard writeText") {
    Ok(text) =>
      match native_write_text_code(@utf8.encode(text)) {
        0 =>
          Ok(
            Json::object({
              "text": Json::string(text),
              "written": Json::boolean(true),
              "native": Json::boolean(true),
            }).stringify(),
          )
        2 => Err("native clipboard is unavailable on this platform")
        code => Err("native clipboard writeText failed: code \{code}")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_native_clear() -> Result[String, String] {
  match native_clear_code() {
    0 =>
      Ok(
        Json::object({
          "cleared": Json::boolean(true),
          "native": Json::boolean(true),
        }).stringify(),
      )
    2 => Err("native clipboard is unavailable on this platform")
    code => Err("native clipboard clear failed: code \{code}")
  }
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

///|
fn decode_native_read_packet(packet : Bytes) -> Result[String, String] {
  let text = @utf8.decode(packet) catch {
    _ => return Err("native clipboard readText returned invalid utf8")
  }
  match text.find("\n") {
    Some(index) => {
      let status = text[:index]
      let body = text[index + 1:]
      if status == "ok" {
        Ok(body.to_owned())
      } else {
        Err(body.to_owned())
      }
    }
    None => Err("native clipboard readText returned malformed packet")
  }
}
