///|
pub(all) enum RuntimeInvokeAuthorizationKind {
  RuntimeInvokeAuthorized
  RuntimeInvokeInvalidRequest
  RuntimeInvokeUnknownCommand
  RuntimeInvokeUnregisteredCommand
  RuntimeInvokePermissionDenied
} derive(Debug, Eq)

///|
pub struct RuntimeInvokeAuthorization {
  kind : RuntimeInvokeAuthorizationKind
  route : String
  window_label : String
  origin : String
  permission : Permission?
  registered : Bool
  capability : String
  reason : String
} derive(Debug, Eq)

///|
pub fn RuntimeInvokeAuthorizationKind::name(
  self : RuntimeInvokeAuthorizationKind,
) -> String {
  match self {
    RuntimeInvokeAuthorized => "authorized"
    RuntimeInvokeInvalidRequest => "invalid-request"
    RuntimeInvokeUnknownCommand => "unknown-command"
    RuntimeInvokeUnregisteredCommand => "unregistered-command"
    RuntimeInvokePermissionDenied => "permission-denied"
  }
}

///|
fn RuntimeInvokeAuthorization::allow(
  request : InvokeRequest,
  permission~ : Permission,
  registered~ : Bool,
  capability~ : String,
) -> RuntimeInvokeAuthorization {
  {
    kind: RuntimeInvokeAuthorized,
    route: request.route(),
    window_label: request.window_label(),
    origin: request.origin(),
    permission: Some(permission),
    registered,
    capability,
    reason: "",
  }
}

///|
fn RuntimeInvokeAuthorization::deny(
  kind~ : RuntimeInvokeAuthorizationKind,
  request : InvokeRequest,
  permission? : Permission,
  registered~ : Bool,
  reason~ : String,
) -> RuntimeInvokeAuthorization {
  {
    kind,
    route: request.route(),
    window_label: request.window_label(),
    origin: request.origin(),
    permission,
    registered,
    capability: "",
    reason,
  }
}

///|
fn RuntimeInvokeAuthorization::invalid(
  request : InvokeRequest,
  reason~ : String,
) -> RuntimeInvokeAuthorization {
  RuntimeInvokeAuthorization::deny(
    kind=RuntimeInvokeInvalidRequest,
    request,
    registered=false,
    reason~,
  )
}

///|
pub fn RuntimeInvokeAuthorization::kind(
  self : RuntimeInvokeAuthorization,
) -> RuntimeInvokeAuthorizationKind {
  self.kind
}

///|
pub fn RuntimeInvokeAuthorization::allowed(
  self : RuntimeInvokeAuthorization,
) -> Bool {
  self.kind is RuntimeInvokeAuthorized
}

///|
pub fn RuntimeInvokeAuthorization::route(
  self : RuntimeInvokeAuthorization,
) -> String {
  self.route
}

///|
pub fn RuntimeInvokeAuthorization::window_label(
  self : RuntimeInvokeAuthorization,
) -> String {
  self.window_label
}

///|
pub fn RuntimeInvokeAuthorization::origin(
  self : RuntimeInvokeAuthorization,
) -> String {
  self.origin
}

///|
pub fn RuntimeInvokeAuthorization::permission(
  self : RuntimeInvokeAuthorization,
) -> Permission? {
  self.permission
}

///|
pub fn RuntimeInvokeAuthorization::registered(
  self : RuntimeInvokeAuthorization,
) -> Bool {
  self.registered
}

///|
pub fn RuntimeInvokeAuthorization::capability(
  self : RuntimeInvokeAuthorization,
) -> String {
  self.capability
}

///|
pub fn RuntimeInvokeAuthorization::reason(
  self : RuntimeInvokeAuthorization,
) -> String {
  self.reason
}

///|
pub fn RuntimeInvokeAuthorization::to_response(
  self : RuntimeInvokeAuthorization,
  id : String,
) -> InvokeResponse {
  match self.kind {
    RuntimeInvokeAuthorized => InvokeResponse::ok(id, "")
    RuntimeInvokeInvalidRequest =>
      InvokeResponse::invalid_request(id, self.reason)
    RuntimeInvokeUnknownCommand | RuntimeInvokeUnregisteredCommand =>
      InvokeResponse::unknown_command(id, self.route)
    RuntimeInvokePermissionDenied =>
      InvokeResponse::permission_denied(id, self.route)
  }
}

///|
pub fn RuntimeInvokeAuthorization::to_json(
  self : RuntimeInvokeAuthorization,
) -> String {
  let permission = match self.permission {
    Some(permission) => permission.name()
    None => ""
  }
  [
    "{",
    "\"allowed\":\{self.allowed().json_bool()},",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"origin\":\{self.origin.json_string()},",
    "\"permission\":\{permission.json_string()},",
    "\"registered\":\{self.registered.json_bool()},",
    "\"capability\":\{self.capability.json_string()},",
    "\"reason\":\{self.reason.json_string()}",
    "}",
  ].join("")
}

///|
pub fn RuntimePlan::authorize_invoke(
  self : RuntimePlan,
  request : InvokeRequest,
  registered_routes? : Array[String] = [],
  check_registered? : Bool = false,
) -> RuntimeInvokeAuthorization {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return RuntimeInvokeAuthorization::invalid(
      request,
      reason=request_problems[0],
    )
  }
  let route = request.route()
  let registered = registered_routes.contains(route)
  match self.command_manifest().entry(route) {
    None =>
      RuntimeInvokeAuthorization::deny(
        kind=RuntimeInvokeUnknownCommand,
        request,
        registered~,
        reason="command is not declared: \{route}",
      )
    Some(entry) => {
      if check_registered && !registered {
        return RuntimeInvokeAuthorization::deny(
          kind=RuntimeInvokeUnregisteredCommand,
          request,
          permission=entry.permission(),
          registered~,
          reason="command has no registered native handler: \{route}",
        )
      }
      let decision = CapabilityPolicy::new(capabilities=self.capabilities()).evaluate(
        window_label=request.window_label(),
        permission=entry.permission(),
        origin=request.origin(),
      )
      if decision.allowed() {
        RuntimeInvokeAuthorization::allow(
          request,
          permission=entry.permission(),
          registered~,
          capability=decision.capability(),
        )
      } else {
        RuntimeInvokeAuthorization::deny(
          kind=RuntimeInvokePermissionDenied,
          request,
          permission=entry.permission(),
          registered~,
          reason=decision.reason(),
        )
      }
    }
  }
}
