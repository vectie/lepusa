///|
fn required_config_string(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> String {
  match optional_config_string(object, key) {
    Some(value) => value
    None => {
      problems.push("project \{key} is required")
      ""
    }
  }
}

///|
fn required_config_int(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> Int {
  match optional_config_int(object, key) {
    Some(value) => value
    None => {
      problems.push("project \{key} is required")
      0
    }
  }
}

///|
fn optional_config_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_config_array(
  object : Map[String, Json],
  key : String,
) -> Array[Json]? {
  match object.get(key) {
    Some(Array(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_config_string_array(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> Array[String]? {
  match object.get(key) {
    Some(Array(items)) => {
      let values : Array[String] = []
      for item in items {
        match item {
          String(value) => values.push(value)
          _ => problems.push("project \{key} entries must be strings")
        }
      }
      Some(values)
    }
    _ => None
  }
}

///|
fn optional_config_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_config_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn optional_config_int(object : Map[String, Json], key : String) -> Int? {
  match object.get(key) {
    Some(value) =>
      try @json.from_json(value) catch {
        _ => None
      } noraise {
        value => Some(value)
      }
    None => None
  }
}

///|
fn config_path(base_dir : String, path : String) -> String {
  if path == "" ||
    base_dir == "" ||
    base_dir == "." ||
    is_absolute_config_path(path) ||
    path.contains("://") {
    path
  } else {
    join_path(base_dir, path)
  }
}

///|
fn join_path(base : String, path : String) -> String {
  if base == "" {
    path
  } else if base.has_suffix("/") || base.has_suffix("\\") {
    base + path
  } else {
    base + "/" + path
  }
}

///|
fn is_absolute_config_path(path : String) -> Bool {
  if path.has_prefix("/") || path.has_prefix("\\") {
    return true
  }
  path.length() >= 3 &&
  path[1:2] == ":" &&
  (path[2:3] == "\\" || path[2:3] == "/")
}
