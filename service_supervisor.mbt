///|
pub(all) enum LocalServiceSupervisorAction {
  StartLocalService(LocalService)
  WaitLocalServiceReady(LocalService)
  StopLocalService(LocalService)
} derive(Debug, Eq)

///|
pub struct LocalServiceSupervisorPlan {
  services : Array[LocalService]
  startup_services : Array[LocalService]
  startup_actions : Array[LocalServiceSupervisorAction]
  shutdown_actions : Array[LocalServiceSupervisorAction]
} derive(Debug, Eq)

///|
pub fn LocalServiceSupervisorPlan::new(
  services? : Array[LocalService] = [],
  startup_services? : Array[LocalService] = [],
) -> LocalServiceSupervisorPlan {
  let startup_actions : Array[LocalServiceSupervisorAction] = []
  for service in startup_services {
    startup_actions.push(StartLocalService(service))
    startup_actions.push(WaitLocalServiceReady(service))
  }
  let shutdown_actions : Array[LocalServiceSupervisorAction] = []
  for i in 0..<startup_services.length() {
    let service = startup_services[startup_services.length() - 1 - i]
    shutdown_actions.push(StopLocalService(service))
  }
  {
    services: services.copy(),
    startup_services: startup_services.copy(),
    startup_actions,
    shutdown_actions,
  }
}

///|
pub fn LocalServiceSupervisorPlan::services(
  self : LocalServiceSupervisorPlan,
) -> Array[LocalService] {
  self.services.copy()
}

///|
pub fn LocalServiceSupervisorPlan::startup_services(
  self : LocalServiceSupervisorPlan,
) -> Array[LocalService] {
  self.startup_services.copy()
}

///|
pub fn LocalServiceSupervisorPlan::startup_actions(
  self : LocalServiceSupervisorPlan,
) -> Array[LocalServiceSupervisorAction] {
  self.startup_actions.copy()
}

///|
pub fn LocalServiceSupervisorPlan::shutdown_actions(
  self : LocalServiceSupervisorPlan,
) -> Array[LocalServiceSupervisorAction] {
  self.shutdown_actions.copy()
}

///|
pub fn LocalServiceSupervisorPlan::requires_supervisor(
  self : LocalServiceSupervisorPlan,
) -> Bool {
  !self.startup_services.is_empty()
}

///|
pub fn LocalServiceSupervisorPlan::start_order(
  self : LocalServiceSupervisorPlan,
) -> Array[String] {
  self.startup_services.map(fn(service) { service.name() })
}

///|
pub fn LocalServiceSupervisorPlan::validate(
  self : LocalServiceSupervisorPlan,
) -> Array[String] {
  let problems : Array[String] = []
  let names : Array[String] = []
  for service in self.services {
    problems.append(service.validate())
    let name = service.name()
    if names.contains(name) {
      problems.push("local service supervisor service must be unique: \{name}")
    } else {
      names.push(name)
    }
  }
  for service in self.startup_services {
    let name = service.name()
    if !names.contains(name) {
      problems.push(
        "local service supervisor startup service is not declared: \{name}",
      )
    }
  }
  problems
}

///|
pub fn LocalServiceSupervisorPlan::to_json(
  self : LocalServiceSupervisorPlan,
) -> String {
  [
    "{",
    "\"services\":[\{self.services.map(fn(service) { service.to_json() }).join(",")}],",
    "\"startupServices\":[\{self.startup_services.map(fn(service) { service.to_json() }).join(",")}],",
    "\"startOrder\":[\{self.start_order().map(fn(name) { name.json_string() }).join(",")}],",
    "\"startupActions\":[\{self.startup_actions.map(fn(action) { action.to_json() }).join(",")}],",
    "\"shutdownActions\":[\{self.shutdown_actions.map(fn(action) { action.to_json() }).join(",")}],",
    "\"requiresSupervisor\":\{self.requires_supervisor().json_bool()}",
    "}",
  ].join("")
}

///|
pub fn LocalServiceSupervisorAction::service(
  self : LocalServiceSupervisorAction,
) -> LocalService {
  match self {
    StartLocalService(service)
    | WaitLocalServiceReady(service)
    | StopLocalService(service) => service
  }
}

///|
pub fn LocalServiceSupervisorAction::kind(
  self : LocalServiceSupervisorAction,
) -> String {
  match self {
    StartLocalService(_) => "start-service"
    WaitLocalServiceReady(_) => "wait-ready"
    StopLocalService(_) => "stop-service"
  }
}

///|
pub fn LocalServiceSupervisorAction::to_json(
  self : LocalServiceSupervisorAction,
) -> String {
  let service = self.service()
  match self {
    StartLocalService(_) =>
      [
        "{",
        "\"kind\":\"start-service\",",
        "\"service\":\{service.to_json()}",
        "}",
      ].join("")
    WaitLocalServiceReady(_) =>
      [
        "{",
        "\"kind\":\"wait-ready\",",
        "\"service\":\{service.name().json_string()},",
        "\"url\":\{service.readiness_url().json_string()}",
        "}",
      ].join("")
    StopLocalService(_) =>
      [
        "{",
        "\"kind\":\"stop-service\",",
        "\"service\":\{service.name().json_string()}",
        "}",
      ].join("")
  }
}
