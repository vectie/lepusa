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
  .command_async("list", permission=ServiceDiscovery)
  .command_async("resolve", permission=ServiceDiscovery)
  .command_async("status", permission=ServiceDiscovery)
  .command_async("watch", permission=ServiceDiscovery)
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
