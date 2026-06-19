///|
pub struct BundledServicePlan {
  services : Array[@lepusa.LocalService]
  startup_services : Array[@lepusa.LocalService]
} derive(Debug, Eq)

///|
pub fn BundledRuntimeManifest::service_plan(
  self : BundledRuntimeManifest,
) -> Result[BundledServicePlan, String] {
  let services : Array[@lepusa.LocalService] = []
  for item in optional_array(self.runtime, "localServices").unwrap_or([]) {
    match bundled_service_from_json(item) {
      Ok(service) => services.push(service)
      Err(problem) => return Err(problem)
    }
  }
  let plan = BundledServicePlan::new(services~)
  match plan.validate() {
    [] => Ok(plan)
    problems => Err(problems[0])
  }
}

///|
pub fn BundledServicePlan::new(
  services~ : Array[@lepusa.LocalService],
) -> BundledServicePlan {
  { services: services.copy(), startup_services: services.copy() }
}

///|
pub fn BundledServicePlan::services(
  self : BundledServicePlan,
) -> Array[@lepusa.LocalService] {
  self.services.copy()
}

///|
pub fn BundledServicePlan::startup_services(
  self : BundledServicePlan,
) -> Array[@lepusa.LocalService] {
  self.startup_services.copy()
}

///|
pub fn BundledServicePlan::service_names(
  self : BundledServicePlan,
) -> Array[String] {
  bundled_service_names(self.services)
}

///|
pub fn BundledServicePlan::startup_service_names(
  self : BundledServicePlan,
) -> Array[String] {
  bundled_service_names(self.startup_services)
}

///|
pub fn BundledServicePlan::requires_supervisor(
  self : BundledServicePlan,
) -> Bool {
  !self.startup_services.is_empty()
}

///|
pub fn BundledServicePlan::validate(self : BundledServicePlan) -> Array[String] {
  let problems : Array[String] = []
  let names : Array[String] = []
  for service in self.services {
    problems.append(service.validate())
    let name = service.name()
    if names.contains(name) {
      problems.push("bundled service must be unique: \{name}")
    } else {
      names.push(name)
    }
  }
  problems
}

///|
pub fn BundledServicePlan::to_json(self : BundledServicePlan) -> String {
  [
    "{",
    "\"services\":[\{self.services.map(fn(service) { service.to_json() }).join(",")}],",
    "\"startupServices\":[\{self.startup_services.map(fn(service) { service.to_json() }).join(",")}],",
    "\"startOrder\":[\{self.startup_service_names().map(fn(name) { name.json_string() }).join(",")}],",
    "\"requiresSupervisor\":\{self.requires_supervisor().json_bool()}",
    "}",
  ].join("")
}

///|
pub fn BundledServicePlan::supervisor_plan(
  self : BundledServicePlan,
) -> @lepusa.LocalServiceSupervisorPlan {
  @lepusa.LocalServiceSupervisorPlan::new(
    services=self.services,
    startup_services=self.startup_services,
  )
}

///|
fn bundled_service_from_json(
  item : Json,
) -> Result[@lepusa.LocalService, String] {
  match item {
    Object(object) => {
      let service = @lepusa.LocalService::new(
        name=optional_string(object, "name").unwrap_or(""),
        command=optional_string_array(object, "command"),
        readiness_url=optional_string(object, "readinessUrl").unwrap_or(""),
      )
      match service.validate() {
        [] => Ok(service)
        problems => Err(problems[0])
      }
    }
    _ => Err("runtime local service must be a json object")
  }
}

///|
fn bundled_service_names(
  services : Array[@lepusa.LocalService],
) -> Array[String] {
  let names : Array[String] = []
  for service in services {
    names.push(service.name())
  }
  names
}
