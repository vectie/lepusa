///|
pub struct NativeServiceSupervisorPlan {
  backend_name : String
  webview_engine : String
  plan : @lepusa.LocalServiceSupervisorPlan
} derive(Debug, Eq)

///|
pub fn NativeServiceSupervisorPlan::new(
  backend_name~ : String,
  webview_engine~ : String,
  plan~ : @lepusa.LocalServiceSupervisorPlan,
) -> NativeServiceSupervisorPlan {
  { backend_name, webview_engine, plan }
}

///|
pub fn NativeServiceSupervisorPlan::backend_name(
  self : NativeServiceSupervisorPlan,
) -> String {
  self.backend_name
}

///|
pub fn NativeServiceSupervisorPlan::webview_engine(
  self : NativeServiceSupervisorPlan,
) -> String {
  self.webview_engine
}

///|
pub fn NativeServiceSupervisorPlan::service_plan(
  self : NativeServiceSupervisorPlan,
) -> @lepusa.LocalServiceSupervisorPlan {
  self.plan
}

///|
pub fn NativeServiceSupervisorPlan::services(
  self : NativeServiceSupervisorPlan,
) -> Array[@lepusa.LocalService] {
  self.plan.services()
}

///|
pub fn NativeServiceSupervisorPlan::startup_actions(
  self : NativeServiceSupervisorPlan,
) -> Array[@lepusa.LocalServiceSupervisorAction] {
  self.plan.startup_actions()
}

///|
pub fn NativeServiceSupervisorPlan::shutdown_actions(
  self : NativeServiceSupervisorPlan,
) -> Array[@lepusa.LocalServiceSupervisorAction] {
  self.plan.shutdown_actions()
}

///|
pub fn NativeServiceSupervisorPlan::requires_supervisor(
  self : NativeServiceSupervisorPlan,
) -> Bool {
  self.plan.requires_supervisor()
}

///|
pub fn NativeServiceSupervisorPlan::start_order(
  self : NativeServiceSupervisorPlan,
) -> Array[String] {
  self.plan.start_order()
}

///|
pub fn NativeServiceSupervisorPlan::validate(
  self : NativeServiceSupervisorPlan,
) -> Array[String] {
  let problems : Array[String] = []
  if self.backend_name == "" {
    problems.push("native service supervisor backend is required")
  }
  if self.webview_engine == "" {
    problems.push("native service supervisor webview engine is required")
  }
  problems.append(self.plan.validate())
  problems
}

///|
pub fn NativeServiceSupervisorPlan::to_json(
  self : NativeServiceSupervisorPlan,
) -> String {
  [
    "{",
    "\"nativeBackend\":\{self.backend_name.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"services\":[\{self.services().map(fn(service) { service.to_json() }).join(",")}],",
    "\"startOrder\":[\{self.start_order().map(fn(name) { name.json_string() }).join(",")}],",
    "\"startupActions\":[\{self.startup_actions().map(fn(action) { action.to_json() }).join(",")}],",
    "\"shutdownActions\":[\{self.shutdown_actions().map(fn(action) { action.to_json() }).join(",")}],",
    "\"requiresSupervisor\":\{self.requires_supervisor().json_bool()}",
    "}",
  ].join("")
}
