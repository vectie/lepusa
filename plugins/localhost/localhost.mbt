///|
pub struct LocalhostPolicy {
  services : Array[@lepusa.LocalService]
} derive(Debug, Eq)

///|
pub fn LocalhostPolicy::new(
  services? : Array[@lepusa.LocalService] = [],
) -> LocalhostPolicy {
  { services, }
}

///|
pub fn LocalhostPolicy::service(
  self : LocalhostPolicy,
  service : @lepusa.LocalService,
) -> LocalhostPolicy {
  let services = self.services.copy()
  services.push(service)
  { services, }
}

///|
pub fn LocalhostPolicy::services(
  self : LocalhostPolicy,
) -> Array[@lepusa.LocalService] {
  self.services.copy()
}

///|
pub fn LocalhostPolicy::validate(self : LocalhostPolicy) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for service in self.services {
    problems.append(service.validate())
    let name = service.name()
    if name != "" {
      if seen.contains(name) {
        problems.push("localhost service must be unique: \{name}")
      } else {
        seen.push(name)
      }
    }
  }
  problems
}

///|
pub fn LocalhostPolicy::service_names(self : LocalhostPolicy) -> Array[String] {
  let names : Array[String] = []
  for service in self.services {
    names.push(service.name())
  }
  names
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("localhost")
  .command_sync("status", permission=Localhost)
  .command_sync("start", permission=Localhost)
  .command_sync("stop", permission=Localhost)
  .command_sync("restart", permission=Localhost)
  .command_sync("waitUntilReady", permission=Localhost)
}

///|
pub fn capability(name? : String = "localhost") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Localhost)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "localhost",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(
  policy? : LocalhostPolicy = LocalhostPolicy::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : LocalhostPolicy = LocalhostPolicy::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("localhost.status", permission=Localhost, handler=fn(payload) {
    handle_status(policy, payload)
  })
  .register_fn("localhost.start", permission=Localhost, handler=fn(payload) {
    handle_action(policy, payload, action="start")
  })
  .register_fn("localhost.stop", permission=Localhost, handler=fn(payload) {
    handle_action(policy, payload, action="stop")
  })
  .register_fn("localhost.restart", permission=Localhost, handler=fn(payload) {
    handle_action(policy, payload, action="restart")
  })
  .register_fn("localhost.waitUntilReady", permission=Localhost, handler=fn(
    payload,
  ) {
    handle_action(policy, payload, action="wait-ready")
  })
}

///|
fn handle_status(
  policy : LocalhostPolicy,
  payload : String,
) -> Result[String, String] {
  match selected_services(policy, payload, context="localhost status") {
    Ok(services) =>
      Ok(
        Json::object({
          "services": Json::array(
            services.map(fn(service) { service_status_json(service) }),
          ),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
fn handle_action(
  policy : LocalhostPolicy,
  payload : String,
  action~ : String,
) -> Result[String, String] {
  match selected_service(policy, payload, context="localhost \{action}") {
    Ok(service) =>
      Ok(
        Json::object({
          "name": Json::string(service.name()),
          "action": Json::string(action),
          "status": Json::string("delegated"),
          "readinessUrl": Json::string(service.readiness_url()),
          "supervised": Json::boolean(!service.command().is_empty()),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
fn selected_services(
  policy : LocalhostPolicy,
  payload : String,
  context~ : String,
) -> Result[Array[@lepusa.LocalService], String] {
  let services = policy.services()
  if payload == "" {
    return Ok(services)
  }
  match service_name_payload(payload, context~) {
    Ok(name) =>
      match service_by_name(services, name) {
        Some(service) => Ok([service])
        None => Err("\{context} service not found: \{name}")
      }
    Err(problem) => Err(problem)
  }
}

///|
fn selected_service(
  policy : LocalhostPolicy,
  payload : String,
  context~ : String,
) -> Result[@lepusa.LocalService, String] {
  let services = policy.services()
  let name = if payload == "" && services.length() == 1 {
    services[0].name()
  } else {
    match service_name_payload(payload, context~) {
      Ok(name) => name
      Err(problem) => return Err(problem)
    }
  }
  match service_by_name(services, name) {
    Some(service) => Ok(service)
    None => Err("\{context} service not found: \{name}")
  }
}

///|
fn service_by_name(
  services : Array[@lepusa.LocalService],
  name : String,
) -> @lepusa.LocalService? {
  for service in services {
    if service.name() == name {
      return Some(service)
    }
  }
  None
}

///|
fn service_name_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  let name = match json {
    String(value) => value
    Object(object) => string_field(object, "name").unwrap_or("")
    _ => return Err("\{context} payload must be a string or object")
  }
  if name == "" {
    Err("\{context} service name is required")
  } else {
    Ok(name)
  }
}

///|
fn service_status_json(service : @lepusa.LocalService) -> Json {
  Json::object({
    "name": Json::string(service.name()),
    "status": Json::string("configured"),
    "readinessUrl": Json::string(service.readiness_url()),
    "command": Json::array(
      service.command().map(fn(part) { Json::string(part) }),
    ),
    "supervised": Json::boolean(!service.command().is_empty()),
  })
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
