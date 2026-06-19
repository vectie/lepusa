///|
pub struct InvokeRequest {
  id : String
  window_label : String
  plugin : String
  command : String
  payload : String
} derive(Debug, Eq)

///|
pub fn InvokeRequest::new(
  id~ : String,
  window_label~ : String,
  plugin~ : String,
  command~ : String,
  payload? : String = "",
) -> InvokeRequest {
  { id, window_label, plugin, command, payload }
}

///|
pub fn InvokeRequest::route(self : InvokeRequest) -> String {
  "\{self.plugin}.\{self.command}"
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
