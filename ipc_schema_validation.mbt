///|
pub fn IpcSchema::validate_payload(
  self : IpcSchema,
  payload : String,
) -> String? {
  match self.name() {
    "any" | "string" => None
    "unit" =>
      if payload == "" || payload == "null" {
        None
      } else {
        Some("expected unit payload")
      }
    "json" => validate_json_payload(payload, "expected json payload")
    "boolean" =>
      match parse_schema_json(payload) {
        Ok(True | False) => None
        Ok(_) => Some("expected boolean payload")
        Err(problem) => Some(problem)
      }
    "number" =>
      match parse_schema_json(payload) {
        Ok(Number(_, ..)) => None
        Ok(_) => Some("expected number payload")
        Err(problem) => Some(problem)
      }
    name =>
      if name.has_suffix("[]") || self.typescript().has_prefix("ReadonlyArray<") {
        match parse_schema_json(payload) {
          Ok(Array(_)) => None
          Ok(_) => Some("expected array payload")
          Err(problem) => Some(problem)
        }
      } else if self.typescript().has_prefix("{") {
        match parse_schema_json(payload) {
          Ok(Object(_)) => None
          Ok(_) => Some("expected object payload")
          Err(problem) => Some(problem)
        }
      } else {
        None
      }
  }
}

///|
pub fn IpcSchema::accepts_payload(self : IpcSchema, payload : String) -> Bool {
  self.validate_payload(payload) is None
}

///|
fn validate_json_payload(payload : String, message : String) -> String? {
  match parse_schema_json(payload) {
    Ok(_) => None
    Err(_) => Some(message)
  }
}

///|
fn parse_schema_json(payload : String) -> Result[Json, String] {
  if payload == "" {
    return Err("expected json payload")
  }
  try @json.parse(payload) catch {
    error => Err("invalid json payload: \{error}")
  } noraise {
    json => Ok(json)
  }
}
