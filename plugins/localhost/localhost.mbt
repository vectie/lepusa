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
  .command_async("status", permission=Localhost)
  .command_async("start", permission=Localhost)
  .command_async("stop", permission=Localhost)
  .command_async("restart", permission=Localhost)
  .command_async("waitUntilReady", permission=Localhost)
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
