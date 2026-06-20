///|
pub struct ServiceEndpoint {
  name : String
  url : String
  health_path : String?
} derive(Debug, Eq)

///|
pub struct ServiceDiscoveryPolicy {
  services : Array[ServiceEndpoint]
} derive(Debug, Eq)

///|
pub fn ServiceEndpoint::new(
  name~ : String,
  url~ : String,
  health_path? : String,
) -> ServiceEndpoint {
  { name, url, health_path }
}

///|
pub fn ServiceEndpoint::name(self : ServiceEndpoint) -> String {
  self.name
}

///|
pub fn ServiceEndpoint::url(self : ServiceEndpoint) -> String {
  self.url
}

///|
pub fn ServiceEndpoint::health_path(self : ServiceEndpoint) -> String? {
  self.health_path
}

///|
pub fn ServiceEndpoint::validate(self : ServiceEndpoint) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("service discovery name is required")
  } else if invalid_service_name(self.name) {
    problems.push("service discovery name is invalid: \{self.name}")
  }
  if self.url == "" {
    problems.push("service discovery url is required")
  } else if !valid_service_url(self.url) {
    problems.push("service discovery url must use http, https, ws, or wss")
  }
  match self.health_path {
    Some("") => problems.push("service discovery health path is required")
    Some(path) if !path.has_prefix("/") =>
      problems.push("service discovery health path must start with /")
    _ => ()
  }
  problems
}

///|
pub fn ServiceDiscoveryPolicy::new(
  services? : Array[ServiceEndpoint] = [],
) -> ServiceDiscoveryPolicy {
  { services, }
}

///|
pub fn ServiceDiscoveryPolicy::service(
  self : ServiceDiscoveryPolicy,
  service : ServiceEndpoint,
) -> ServiceDiscoveryPolicy {
  let services = self.services.copy()
  services.push(service)
  { services, }
}

///|
pub fn ServiceDiscoveryPolicy::services(
  self : ServiceDiscoveryPolicy,
) -> Array[ServiceEndpoint] {
  self.services.copy()
}

///|
pub fn ServiceDiscoveryPolicy::service_names(
  self : ServiceDiscoveryPolicy,
) -> Array[String] {
  let names : Array[String] = []
  for service in self.services {
    names.push(service.name())
  }
  names
}

///|
pub fn ServiceDiscoveryPolicy::validate(
  self : ServiceDiscoveryPolicy,
) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for service in self.services {
    problems.append(service.validate())
    let name = service.name()
    if name != "" {
      if seen.contains(name) {
        problems.push("service discovery name must be unique: \{name}")
      } else {
        seen.push(name)
      }
    }
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("serviceDiscovery")
  .command_sync("list", permission=ServiceDiscovery)
  .command_sync("resolve", permission=ServiceDiscovery)
  .command_sync("status", permission=ServiceDiscovery)
  .command_sync("watch", permission=ServiceDiscovery)
  .command_event("onServiceChanged", permission=ServiceDiscovery)
}

///|
pub fn capability(name? : String = "service-discovery") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(ServiceDiscovery)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "service-discovery",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(
  policy? : ServiceDiscoveryPolicy = ServiceDiscoveryPolicy::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : ServiceDiscoveryPolicy = ServiceDiscoveryPolicy::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("serviceDiscovery.list", permission=ServiceDiscovery, handler=fn(
    _,
  ) {
    handle_list(policy)
  })
  .register_fn("serviceDiscovery.resolve", permission=ServiceDiscovery, handler=fn(
    payload,
  ) {
    handle_resolve(policy, payload)
  })
  .register_fn("serviceDiscovery.status", permission=ServiceDiscovery, handler=fn(
    payload,
  ) {
    handle_status(policy, payload)
  })
  .register_fn("serviceDiscovery.watch", permission=ServiceDiscovery, handler=fn(
    payload,
  ) {
    handle_watch(policy, payload)
  })
}

///|
pub fn ServiceDiscoveryPolicy::from_local_services(
  services : Array[@lepusa.LocalService],
) -> ServiceDiscoveryPolicy {
  let policy = ServiceDiscoveryPolicy::new()
  for service in services {
    let health_path = health_path_from_url(service.readiness_url())
    policy.services.push(
      match health_path {
        Some(path) =>
          ServiceEndpoint::new(
            name=service.name(),
            url=service.readiness_url(),
            health_path=path,
          )
        None =>
          ServiceEndpoint::new(name=service.name(), url=service.readiness_url())
      },
    )
  }
  policy
}

///|
fn handle_list(policy : ServiceDiscoveryPolicy) -> Result[String, String] {
  Ok(
    Json::object({
      "services": Json::array(
        policy.services().map(fn(service) { service_endpoint_json(service) }),
      ),
    }).stringify(),
  )
}

///|
fn handle_resolve(
  policy : ServiceDiscoveryPolicy,
  payload : String,
) -> Result[String, String] {
  match
    selected_endpoint(policy, payload, context="service discovery resolve") {
    Ok(service) => Ok(service_endpoint_json(service).stringify())
    Err(problem) => Err(problem)
  }
}

///|
fn handle_status(
  policy : ServiceDiscoveryPolicy,
  payload : String,
) -> Result[String, String] {
  match selected_endpoint(policy, payload, context="service discovery status") {
    Ok(service) =>
      Ok(
        Json::object({
          "name": Json::string(service.name()),
          "url": Json::string(service.url()),
          "healthPath": optional_string_json(service.health_path()),
          "status": Json::string("configured"),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
fn handle_watch(
  policy : ServiceDiscoveryPolicy,
  payload : String,
) -> Result[String, String] {
  let service = if payload == "" {
    None
  } else {
    match
      selected_endpoint(policy, payload, context="service discovery watch") {
      Ok(service) => Some(service)
      Err(problem) => return Err(problem)
    }
  }
  Ok(
    Json::object({
      "event": Json::string("serviceDiscovery.onServiceChanged"),
      "status": Json::string("registered"),
      "name": optional_string_json(service.map(fn(service) { service.name() })),
    }).stringify(),
  )
}

///|
fn selected_endpoint(
  policy : ServiceDiscoveryPolicy,
  payload : String,
  context~ : String,
) -> Result[ServiceEndpoint, String] {
  let services = policy.services()
  let name = if payload == "" && services.length() == 1 {
    services[0].name()
  } else {
    match service_name_payload(payload, context~) {
      Ok(name) => name
      Err(problem) => return Err(problem)
    }
  }
  for service in services {
    if service.name() == name {
      return Ok(service)
    }
  }
  Err("\{context} service not found: \{name}")
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
fn service_endpoint_json(service : ServiceEndpoint) -> Json {
  Json::object({
    "name": Json::string(service.name()),
    "url": Json::string(service.url()),
    "healthPath": optional_string_json(service.health_path()),
  })
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn health_path_from_url(url : String) -> String? {
  let scheme_index = url.find("://")
  let path_start = match scheme_index {
    Some(index) =>
      url[index + 3:].find("/").map(fn(offset) { index + 3 + offset })
    None => url.find("/")
  }
  match path_start {
    Some(index) => Some(url[index:].to_owned())
    None => None
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn invalid_service_name(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}

///|
fn valid_service_url(value : String) -> Bool {
  value.has_prefix("http://") ||
  value.has_prefix("https://") ||
  value.has_prefix("ws://") ||
  value.has_prefix("wss://")
}
