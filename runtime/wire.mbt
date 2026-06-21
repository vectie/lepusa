///|
pub fn decode_invoke_request_json(
  input : String,
) -> Result[@lepusa.InvokeRequest, String] {
  let parsed = @json.parse(input) catch {
    error => return Err("invalid invoke json: \{error}")
  }
  match parsed {
    Object(object) => {
      let id = required_string_field(object, "id")
      let window_label = match string_field(object, "window_label") {
        Some(value) => value
        None => string_field(object, "windowLabel").unwrap_or("")
      }
      let plugin = required_string_field(object, "plugin")
      let command = required_string_field(object, "command")
      let payload = payload_field(object)
      let origin = string_field(object, "origin").unwrap_or("")
      let callback_id = string_field(object, "callback_id").unwrap_or("")
      let error_id = string_field(object, "error_id").unwrap_or("")
      if id == "" {
        Err("invoke id is required")
      } else if window_label == "" {
        Err("invoke window label is required")
      } else if plugin == "" {
        Err("invoke plugin is required")
      } else if command == "" {
        Err("invoke command is required")
      } else {
        Ok(
          @lepusa.InvokeRequest::new(
            id~,
            window_label~,
            plugin~,
            command~,
            payload~,
            origin~,
            callback_id~,
            error_id~,
          ),
        )
      }
    }
    _ => Err("invoke json must be an object")
  }
}

///|
pub fn encode_invoke_request_json(request : @lepusa.InvokeRequest) -> String {
  Json::object({
    "id": Json::string(request.id()),
    "window_label": Json::string(request.window_label()),
    "plugin": Json::string(request.plugin()),
    "command": Json::string(request.command()),
    "payload": Json::string(request.payload()),
    "origin": Json::string(request.origin()),
    "callback_id": Json::string(request.callback_id()),
    "error_id": Json::string(request.error_id()),
  }).stringify()
}

///|
pub fn encode_invoke_response_json(response : @lepusa.InvokeResponse) -> String {
  match response.failure_info() {
    Some(failure) =>
      Json::object({
        "id": Json::string(response.id()),
        "error": Json::string(failure.message()),
        "errorCode": Json::string(failure.kind().name()),
        "failure": Json::object({
          "code": Json::string(failure.kind().name()),
          "message": Json::string(failure.message()),
          "route": Json::string(failure.route().unwrap_or("")),
        }),
      }).stringify()
    None =>
      Json::object({
        "id": Json::string(response.id()),
        "payload": Json::string(response.payload().unwrap_or("")),
      }).stringify()
  }
}

///|
pub fn RuntimeHost::dispatch_json(self : RuntimeHost, input : String) -> String {
  match decode_invoke_request_json(input) {
    Ok(request) => encode_invoke_response_json(self.dispatch(request))
    Err(problem) =>
      encode_invoke_response_json(
        @lepusa.InvokeResponse::invalid_request("", problem),
      )
  }
}

///|
pub async fn RuntimeHost::dispatch_json_async(
  self : RuntimeHost,
  input : String,
) -> String {
  match decode_invoke_request_json(input) {
    Ok(request) => encode_invoke_response_json(self.dispatch_async(request))
    Err(problem) =>
      encode_invoke_response_json(
        @lepusa.InvokeResponse::invalid_request("", problem),
      )
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

///|
fn payload_field(object : Map[String, Json]) -> String {
  match object.get("payload") {
    None | Some(Null) => ""
    Some(String(value)) => value
    Some(value) => value.stringify()
  }
}
