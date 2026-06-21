///|
pub fn WindowConfig::parse_open_payload(
  payload : String,
) -> Result[WindowConfig, String] {
  if payload == "" {
    return Err("window open payload is required")
  }
  let parsed = @json.parse(payload) catch {
    error => return Err("invalid window open payload: \{error}")
  }
  match parsed {
    Object(object) => window_config_from_open_object(object)
    _ => Err("window open payload must be an object")
  }
}

///|
fn window_config_from_open_object(
  object : Map[String, Json],
) -> Result[WindowConfig, String] {
  let label = match window_json_string(object, "label") {
    Some(value) => value
    None => return Err("window open label is required")
  }
  let source = match object.get("source") {
    Some(value) => window_source_from_json(value)
    None => Err("window open source is required")
  }
  match source {
    Err(problem) => Err(problem)
    Ok(source) =>
      Ok(
        WindowConfig::new(
          label~,
          title=window_json_string(object, "title").unwrap_or("Lepusa"),
          width=window_json_int(object, "width").unwrap_or(1000),
          height=window_json_int(object, "height").unwrap_or(720),
          resizable=window_json_bool(object, "resizable").unwrap_or(true),
          source~,
        ),
      )
  }
}

///|
fn window_source_from_json(value : Json) -> Result[Source, String] {
  match value {
    Object(object) => {
      let kind = window_json_string(object, "kind").unwrap_or("html").to_lower()
      match kind {
        "html" | "inline-html" =>
          match window_json_string(object, "content") {
            Some(content) => Ok(Source::html(content))
            None => Err("window open html source content is required")
          }
        "url" | "remote-url" =>
          match window_json_string(object, "url") {
            Some(url) => Ok(Source::url(url))
            None => Err("window open url source url is required")
          }
        "local" | "local-path" =>
          match window_json_string(object, "path") {
            Some(path) => Ok(Source::local_path(path))
            None => Err("window open local source path is required")
          }
        "packaged" | "packaged-assets" =>
          match window_json_string(object, "path") {
            Some(path) => Ok(Source::packaged(path))
            None => Err("window open packaged source path is required")
          }
        "localhost" =>
          match window_json_int(object, "port") {
            Some(port) =>
              Ok(
                Source::localhost(
                  port~,
                  host=window_json_string(object, "host").unwrap_or("127.0.0.1"),
                  path=window_json_string(object, "path").unwrap_or("/"),
                  readiness_path?=window_json_string(object, "readinessPath"),
                  command=window_json_string_array(object, "command"),
                ),
              )
            None => Err("window open localhost source port is required")
          }
        _ => Err("unknown window open source kind: \{kind}")
      }
    }
    _ => Err("window open source must be an object")
  }
}

///|
fn window_json_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn window_json_int(object : Map[String, Json], key : String) -> Int? {
  match object.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn window_json_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn window_json_string_array(
  object : Map[String, Json],
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  match object.get(key) {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(value) => values.push(value)
          _ => ()
        }
      }
    _ => ()
  }
  values
}
