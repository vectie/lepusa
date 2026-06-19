///|
pub struct RuntimeServicePlan {
  services : Array[@lepusa.LocalService]
  startup_services : Array[@lepusa.LocalService]
} derive(Debug, Eq)

///|
pub fn RuntimeServicePlan::new(
  services? : Array[@lepusa.LocalService] = [],
  startup_services? : Array[@lepusa.LocalService] = [],
) -> RuntimeServicePlan {
  { services: services.copy(), startup_services: startup_services.copy() }
}

///|
pub fn RuntimeServicePlan::services(
  self : RuntimeServicePlan,
) -> Array[@lepusa.LocalService] {
  self.services.copy()
}

///|
pub fn RuntimeServicePlan::startup_services(
  self : RuntimeServicePlan,
) -> Array[@lepusa.LocalService] {
  self.startup_services.copy()
}

///|
pub fn RuntimeServicePlan::service_names(
  self : RuntimeServicePlan,
) -> Array[String] {
  service_names(self.services)
}

///|
pub fn RuntimeServicePlan::startup_service_names(
  self : RuntimeServicePlan,
) -> Array[String] {
  service_names(self.startup_services)
}

///|
pub fn RuntimeServicePlan::requires_supervisor(
  self : RuntimeServicePlan,
) -> Bool {
  !self.startup_services.is_empty()
}

///|
pub fn RuntimeServicePlan::validate(self : RuntimeServicePlan) -> Array[String] {
  let problems : Array[String] = []
  let names : Array[String] = []
  for service in self.services {
    problems.append(service.validate())
    let name = service.name()
    if names.contains(name) {
      problems.push("runtime service must be unique: \{name}")
    } else {
      names.push(name)
    }
  }
  for service in self.startup_services {
    let name = service.name()
    if !names.contains(name) {
      problems.push("startup service is not declared: \{name}")
    }
  }
  problems
}

///|
pub fn RuntimeServicePlan::to_json(self : RuntimeServicePlan) -> String {
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
pub fn RuntimeServicePlan::supervisor_plan(
  self : RuntimeServicePlan,
) -> @lepusa.LocalServiceSupervisorPlan {
  @lepusa.LocalServiceSupervisorPlan::new(
    services=self.services,
    startup_services=self.startup_services,
  )
}

///|
pub fn RuntimeHost::service_plan(
  self : RuntimeHost,
) -> Result[RuntimeServicePlan, Array[String]] {
  match self.runner_plan() {
    Ok(plan) => Ok(plan.service_plan())
    Err(problems) => Err(problems)
  }
}

///|
pub fn RuntimeRunnerPlan::service_plan(
  self : RuntimeRunnerPlan,
) -> RuntimeServicePlan {
  RuntimeServicePlan::new(
    services=self.session.local_services(),
    startup_services=runtime_startup_services(self.startup_operations),
  )
}

///|
pub fn RuntimeDevPlan::service_plan(
  self : RuntimeDevPlan,
) -> RuntimeServicePlan {
  RuntimeServicePlan::new(
    services=self.session.local_services(),
    startup_services=runtime_startup_services(self.startup_operations),
  )
}

///|
pub fn NativeRunnerPlan::service_plan(
  self : NativeRunnerPlan,
) -> RuntimeServicePlan {
  RuntimeServicePlan::new(
    services=self.session.local_services(),
    startup_services=native_startup_services(self.startup_operations),
  )
}

///|
pub fn NativeRunnerPlan::service_supervisor_plan(
  self : NativeRunnerPlan,
) -> NativeServiceSupervisorPlan {
  NativeServiceSupervisorPlan::new(
    backend_name=self.backend_name(),
    webview_engine=self.webview_engine(),
    plan=self.service_plan().supervisor_plan(),
  )
}

///|
fn runtime_startup_services(
  operations : Array[RuntimeOperation],
) -> Array[@lepusa.LocalService] {
  let services : Array[@lepusa.LocalService] = []
  for operation in operations {
    match operation {
      RuntimeStartService(service) => services.push(service)
      _ => ()
    }
  }
  services
}

///|
fn native_startup_services(
  operations : Array[NativeOperation],
) -> Array[@lepusa.LocalService] {
  let services : Array[@lepusa.LocalService] = []
  for operation in operations {
    match operation {
      NativeStartService(service) => services.push(service)
      _ => ()
    }
  }
  services
}

///|
fn service_names(services : Array[@lepusa.LocalService]) -> Array[String] {
  let names : Array[String] = []
  for service in services {
    names.push(service.name())
  }
  names
}
