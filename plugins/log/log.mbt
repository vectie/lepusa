///|
pub struct LogEntry {
  level : String
  message : String
  target : String
} derive(Debug, Eq)

///|
pub fn LogEntry::new(
  message~ : String,
  level? : String = "info",
  target? : String = "app",
) -> LogEntry {
  { level, message, target }
}

///|
pub fn LogEntry::level(self : LogEntry) -> String {
  self.level
}

///|
pub fn LogEntry::message(self : LogEntry) -> String {
  self.message
}

///|
pub fn LogEntry::target(self : LogEntry) -> String {
  self.target
}

///|
pub fn LogEntry::to_json(self : LogEntry) -> String {
  Json::object({
    "level": Json::string(self.level),
    "message": Json::string(self.message),
    "target": Json::string(self.target),
  }).stringify()
}

///|
pub struct LogBuffer {
  entries : Array[LogEntry]
}

///|
pub fn LogBuffer::new() -> LogBuffer {
  { entries: [] }
}

///|
pub fn LogBuffer::write(self : LogBuffer, entry : LogEntry) -> Unit {
  self.entries.push(entry)
}

///|
pub fn LogBuffer::entries(self : LogBuffer) -> Array[LogEntry] {
  self.entries.copy()
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("log").command_sync("write")
}

///|
pub fn capability(name? : String = "log") -> @lepusa.Capability {
  @lepusa.Capability::new(name).command("log.write")
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "log",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(
  buffer? : LogBuffer = LogBuffer::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), buffer~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  buffer? : LogBuffer = LogBuffer::new(),
) -> @lepusa.CommandRegistry {
  registry.register_fn("log.write", handler=fn(payload) {
    match decode_write_payload(payload) {
      Ok(entry) => {
        buffer.write(entry)
        Ok(entry.to_json())
      }
      Err(problem) => Err(problem)
    }
  })
}

///|
fn decode_write_payload(payload : String) -> Result[LogEntry, String] {
  if payload == "" {
    return Err("log payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid log payload: \{error}")
  }
  match json {
    String(message) =>
      log_entry_from_parts(message~, level="info", target="app")
    Object(object) => {
      let message = required_string_field(object, "message")
      let level = string_field(object, "level").unwrap_or("info")
      let target = string_field(object, "target").unwrap_or("app")
      log_entry_from_parts(message~, level~, target~)
    }
    _ => Err("log payload must be a string or object")
  }
}

///|
fn log_entry_from_parts(
  message~ : String,
  level~ : String,
  target~ : String,
) -> Result[LogEntry, String] {
  if message == "" {
    Err("log message is required")
  } else if level == "" {
    Err("log level is required")
  } else if target == "" {
    Err("log target is required")
  } else {
    Ok(LogEntry::new(message~, level~, target~))
  }
}

///|
fn required_string_field(object : Map[String, Json], key : String) -> String {
  string_field(object, key).unwrap_or("")
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
