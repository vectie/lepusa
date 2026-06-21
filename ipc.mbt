///|
pub struct InvokeRequest {
  id : String
  window_label : String
  plugin : String
  command : String
  payload : String
  origin : String
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
  origin? : String = "",
  callback_id? : String = "",
  error_id? : String = "",
) -> InvokeRequest {
  { id, window_label, plugin, command, payload, origin, callback_id, error_id }
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
pub fn InvokeRequest::origin(self : InvokeRequest) -> String {
  self.origin
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
pub(all) enum InvokeErrorKind {
  InvalidRequest
  UnknownCommand
  PermissionDenied
  AsyncRequired
  HandlerError
  TransportError
  Timeout
  Cancelled
} derive(Debug, Eq)

///|
pub struct InvokeFailure {
  kind : InvokeErrorKind
  message : String
  route : String
} derive(Debug, Eq)

///|
pub(all) enum InvokeResponse {
  InvokeOk(String, String)
  InvokeError(String, InvokeFailure)
} derive(Debug, Eq)

///|
pub fn InvokeErrorKind::name(self : InvokeErrorKind) -> String {
  match self {
    InvalidRequest => "invalid-request"
    UnknownCommand => "unknown-command"
    PermissionDenied => "permission-denied"
    AsyncRequired => "async-required"
    HandlerError => "handler-error"
    TransportError => "transport-error"
    Timeout => "timeout"
    Cancelled => "cancelled"
  }
}

///|
pub fn InvokeFailure::new(
  kind~ : InvokeErrorKind,
  message~ : String,
  route? : String = "",
) -> InvokeFailure {
  { kind, message, route }
}

///|
pub fn InvokeFailure::invalid_request(message : String) -> InvokeFailure {
  InvokeFailure::new(kind=InvalidRequest, message~)
}

///|
pub fn InvokeFailure::unknown_command(route : String) -> InvokeFailure {
  InvokeFailure::new(
    kind=UnknownCommand,
    message="unknown command: \{route}",
    route~,
  )
}

///|
pub fn InvokeFailure::permission_denied(route : String) -> InvokeFailure {
  InvokeFailure::new(
    kind=PermissionDenied,
    message="permission denied: \{route}",
    route~,
  )
}

///|
pub fn InvokeFailure::async_required(route : String) -> InvokeFailure {
  InvokeFailure::new(
    kind=AsyncRequired,
    message="command requires async dispatch: \{route}",
    route~,
  )
}

///|
pub fn InvokeFailure::handler_error(
  message : String,
  route? : String = "",
) -> InvokeFailure {
  InvokeFailure::new(kind=HandlerError, message~, route~)
}

///|
pub fn InvokeFailure::transport_error(message : String) -> InvokeFailure {
  InvokeFailure::new(kind=TransportError, message~)
}

///|
pub fn InvokeFailure::timeout(
  message? : String = "invoke timed out",
  route? : String = "",
) -> InvokeFailure {
  InvokeFailure::new(kind=Timeout, message~, route~)
}

///|
pub fn InvokeFailure::cancelled(
  message? : String = "invoke cancelled",
  route? : String = "",
) -> InvokeFailure {
  InvokeFailure::new(kind=Cancelled, message~, route~)
}

///|
pub fn InvokeFailure::kind(self : InvokeFailure) -> InvokeErrorKind {
  self.kind
}

///|
pub fn InvokeFailure::message(self : InvokeFailure) -> String {
  self.message
}

///|
pub fn InvokeFailure::route(self : InvokeFailure) -> String? {
  if self.route == "" {
    None
  } else {
    Some(self.route)
  }
}

///|
pub fn InvokeFailure::to_json(self : InvokeFailure) -> String {
  [
    "{",
    "\"code\":\{self.kind.name().json_string()},",
    "\"message\":\{self.message.json_string()},",
    "\"route\":\{self.route_json()}",
    "}",
  ].join("")
}

///|
fn InvokeFailure::route_json(self : InvokeFailure) -> String {
  match self.route() {
    Some(route) => route.json_string()
    None => "null"
  }
}

///|
pub fn InvokeResponse::ok(id : String, payload : String) -> InvokeResponse {
  InvokeOk(id, payload)
}

///|
pub fn InvokeResponse::failure(
  id : String,
  failure : InvokeFailure,
) -> InvokeResponse {
  InvokeError(id, failure)
}

///|
pub fn InvokeResponse::error(id : String, message : String) -> InvokeResponse {
  InvokeResponse::failure(id, InvokeFailure::handler_error(message))
}

///|
pub fn InvokeResponse::invalid_request(
  id : String,
  message : String,
) -> InvokeResponse {
  InvokeResponse::failure(id, InvokeFailure::invalid_request(message))
}

///|
pub fn InvokeResponse::unknown_command(
  id : String,
  route : String,
) -> InvokeResponse {
  InvokeResponse::failure(id, InvokeFailure::unknown_command(route))
}

///|
pub fn InvokeResponse::permission_denied(
  id : String,
  route : String,
) -> InvokeResponse {
  InvokeResponse::failure(id, InvokeFailure::permission_denied(route))
}

///|
pub fn InvokeResponse::async_required(
  id : String,
  route : String,
) -> InvokeResponse {
  InvokeResponse::failure(id, InvokeFailure::async_required(route))
}

///|
pub fn InvokeResponse::handler_error(
  id : String,
  message : String,
  route? : String = "",
) -> InvokeResponse {
  InvokeResponse::failure(id, InvokeFailure::handler_error(message, route~))
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
pub fn InvokeResponse::failure_info(self : InvokeResponse) -> InvokeFailure? {
  match self {
    InvokeOk(_) => None
    InvokeError(_, failure) => Some(failure)
  }
}

///|
pub fn InvokeResponse::error_kind(self : InvokeResponse) -> InvokeErrorKind? {
  match self.failure_info() {
    Some(failure) => Some(failure.kind())
    None => None
  }
}

///|
pub fn InvokeResponse::error_message(self : InvokeResponse) -> String? {
  match self.failure_info() {
    Some(failure) => Some(failure.message())
    None => None
  }
}
