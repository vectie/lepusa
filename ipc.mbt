///|
pub struct InvokeRequest {
  id : String
  window_label : String
  plugin : String
  command : String
  payload : String
  callback_id : String
  error_id : String
} derive(Debug, Eq)

///|
pub fn InvokeRequest::new(
  id~ : String,
  window_label~ : String,
  plugin~ : String,
  command~ : String,
  payload? : String = "",
  callback_id? : String = "",
  error_id? : String = "",
) -> InvokeRequest {
  { id, window_label, plugin, command, payload, callback_id, error_id }
}

///|
pub fn InvokeRequest::route(self : InvokeRequest) -> String {
  "\{self.plugin}.\{self.command}"
}

///|
pub fn InvokeRequest::id(self : InvokeRequest) -> String {
  self.id
}

///|
pub fn InvokeRequest::window_label(self : InvokeRequest) -> String {
  self.window_label
}

///|
pub fn InvokeRequest::plugin(self : InvokeRequest) -> String {
  self.plugin
}

///|
pub fn InvokeRequest::command(self : InvokeRequest) -> String {
  self.command
}

///|
pub fn InvokeRequest::payload(self : InvokeRequest) -> String {
  self.payload
}

///|
pub fn InvokeRequest::callback_id(self : InvokeRequest) -> String {
  self.callback_id
}

///|
pub fn InvokeRequest::error_id(self : InvokeRequest) -> String {
  self.error_id
}

///|
pub fn InvokeRequest::has_resolver_ids(self : InvokeRequest) -> Bool {
  self.callback_id != "" && self.error_id != ""
}

///|
pub fn InvokeRequest::validate(self : InvokeRequest) -> Array[String] {
  let problems : Array[String] = []
  if self.id == "" {
    problems.push("invoke id is required")
  }
  if self.window_label == "" {
    problems.push("invoke window label is required")
  }
  if self.plugin == "" {
    problems.push("invoke plugin is required")
  }
  if self.command == "" {
    problems.push("invoke command is required")
  }
  problems
}

///|
pub(all) enum InvokeResponse {
  InvokeOk(String, String)
  InvokeError(String, String)
} derive(Debug, Eq)

///|
pub fn InvokeResponse::ok(id : String, payload : String) -> InvokeResponse {
  InvokeOk(id, payload)
}

///|
pub fn InvokeResponse::error(id : String, message : String) -> InvokeResponse {
  InvokeError(id, message)
}

///|
pub fn InvokeResponse::id(self : InvokeResponse) -> String {
  match self {
    InvokeOk(id, _) | InvokeError(id, _) => id
  }
}

///|
pub fn InvokeResponse::payload(self : InvokeResponse) -> String? {
  match self {
    InvokeOk(_, payload) => Some(payload)
    InvokeError(_) => None
  }
}

///|
pub fn InvokeResponse::error_message(self : InvokeResponse) -> String? {
  match self {
    InvokeOk(_) => None
    InvokeError(_, message) => Some(message)
  }
}
