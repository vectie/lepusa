///|
pub struct NativeServiceSupervisorPlan {
  backend_name : String
  webview_engine : String
  plan : @lepusa.LocalServiceSupervisorPlan
} derive(Debug, Eq)

///|
pub(all) enum NativeServiceActionStatus {
  NativeServiceActionPrepared
  NativeServiceActionStarted
  NativeServiceActionReady
  NativeServiceActionStopped
  NativeServiceActionSkipped(String)
  NativeServiceActionFailed(String)
} derive(Debug, Eq)

///|
pub struct NativeServiceActionReport {
  action : @lepusa.LocalServiceSupervisorAction
  status : NativeServiceActionStatus
} derive(Debug, Eq)

///|
pub struct NativeServiceSupervisorReport {
  backend_name : String
  webview_engine : String
  action_reports : Array[NativeServiceActionReport]
} derive(Debug, Eq)

///|
pub type NativeServiceActionHandler = (@lepusa.LocalService) -> NativeServiceActionStatus

///|
pub fn native_service_command_packet(command : Array[String]) -> Bytes {
  let chunks : Array[String] = []
  for part in command {
    chunks.push("\{@utf8.encode(part).length()}\n\{part}")
  }
  @utf8.encode(chunks.join(""))
}

///|
pub struct NativeServiceExecutor {
  backend_name : String
  webview_engine : String
  start_service : NativeServiceActionHandler
  wait_until_ready : NativeServiceActionHandler
  stop_service : NativeServiceActionHandler
}

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
pub fn NativeServiceSupervisorPlan::prepared_report(
  self : NativeServiceSupervisorPlan,
) -> NativeServiceSupervisorReport {
  let reports : Array[NativeServiceActionReport] = []
  for action in self.startup_actions() {
    reports.push(NativeServiceActionReport::new(action~))
  }
  for action in self.shutdown_actions() {
    reports.push(NativeServiceActionReport::new(action~))
  }
  NativeServiceSupervisorReport::new(
    backend_name=self.backend_name,
    webview_engine=self.webview_engine,
    action_reports=reports,
  )
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

///|
pub fn NativeServiceSupervisorPlan::executor(
  self : NativeServiceSupervisorPlan,
  start_service~ : NativeServiceActionHandler,
  wait_until_ready~ : NativeServiceActionHandler,
  stop_service~ : NativeServiceActionHandler,
) -> NativeServiceExecutor {
  NativeServiceExecutor::new(
    backend_name=self.backend_name,
    webview_engine=self.webview_engine,
    start_service~,
    wait_until_ready~,
    stop_service~,
  )
}

///|
pub fn NativeServiceActionReport::new(
  action~ : @lepusa.LocalServiceSupervisorAction,
  status? : NativeServiceActionStatus = NativeServiceActionPrepared,
) -> NativeServiceActionReport {
  { action, status }
}

///|
pub fn NativeServiceActionReport::action(
  self : NativeServiceActionReport,
) -> @lepusa.LocalServiceSupervisorAction {
  self.action
}

///|
pub fn NativeServiceActionReport::status(
  self : NativeServiceActionReport,
) -> NativeServiceActionStatus {
  self.status
}

///|
pub fn NativeServiceActionReport::service_name(
  self : NativeServiceActionReport,
) -> String {
  self.action.service().name()
}

///|
pub fn NativeServiceActionReport::action_kind(
  self : NativeServiceActionReport,
) -> String {
  self.action.kind()
}

///|
pub fn NativeServiceActionReport::failed(
  self : NativeServiceActionReport,
) -> Bool {
  self.status is NativeServiceActionFailed(_)
}

///|
pub fn NativeServiceActionReport::to_json(
  self : NativeServiceActionReport,
) -> String {
  [
    "{",
    "\"action\":\{self.action.to_json()},",
    "\"service\":\{self.service_name().json_string()},",
    "\"actionKind\":\{self.action_kind().json_string()},",
    "\"status\":\{self.status.to_json()}",
    "}",
  ].join("")
}

///|
pub fn NativeServiceExecutor::new(
  backend_name~ : String,
  webview_engine~ : String,
  start_service~ : NativeServiceActionHandler,
  wait_until_ready~ : NativeServiceActionHandler,
  stop_service~ : NativeServiceActionHandler,
) -> NativeServiceExecutor {
  {
    backend_name,
    webview_engine,
    start_service,
    wait_until_ready,
    stop_service,
  }
}

///|
pub fn NativeServiceExecutor::prepared(
  backend_name~ : String,
  webview_engine~ : String,
) -> NativeServiceExecutor {
  NativeServiceExecutor::new(
    backend_name~,
    webview_engine~,
    start_service=fn(_) { NativeServiceActionPrepared },
    wait_until_ready=fn(_) { NativeServiceActionPrepared },
    stop_service=fn(_) { NativeServiceActionPrepared },
  )
}

///|
pub fn NativeServiceExecutor::backend_name(
  self : NativeServiceExecutor,
) -> String {
  self.backend_name
}

///|
pub fn NativeServiceExecutor::webview_engine(
  self : NativeServiceExecutor,
) -> String {
  self.webview_engine
}

///|
pub fn NativeServiceExecutor::execute_startup(
  self : NativeServiceExecutor,
  plan : NativeServiceSupervisorPlan,
) -> NativeServiceSupervisorReport {
  self.execute_actions(plan.startup_actions())
}

///|
pub fn NativeServiceExecutor::execute_shutdown(
  self : NativeServiceExecutor,
  plan : NativeServiceSupervisorPlan,
) -> NativeServiceSupervisorReport {
  self.execute_actions(plan.shutdown_actions())
}

///|
pub fn NativeServiceExecutor::execute_all(
  self : NativeServiceExecutor,
  plan : NativeServiceSupervisorPlan,
) -> NativeServiceSupervisorReport {
  let actions = plan.startup_actions()
  actions.append(plan.shutdown_actions())
  self.execute_actions(actions)
}

///|
pub fn NativeServiceExecutor::execute_action(
  self : NativeServiceExecutor,
  action : @lepusa.LocalServiceSupervisorAction,
) -> NativeServiceActionReport {
  match action {
    StartLocalService(service) =>
      NativeServiceActionReport::new(
        action~,
        status=(self.start_service)(service),
      )
    WaitLocalServiceReady(service) =>
      NativeServiceActionReport::new(
        action~,
        status=(self.wait_until_ready)(service),
      )
    StopLocalService(service) =>
      NativeServiceActionReport::new(
        action~,
        status=(self.stop_service)(service),
      )
  }
}

///|
fn NativeServiceExecutor::execute_actions(
  self : NativeServiceExecutor,
  actions : Array[@lepusa.LocalServiceSupervisorAction],
) -> NativeServiceSupervisorReport {
  let reports : Array[NativeServiceActionReport] = []
  for action in actions {
    reports.push(self.execute_action(action))
  }
  NativeServiceSupervisorReport::new(
    backend_name=self.backend_name,
    webview_engine=self.webview_engine,
    action_reports=reports,
  )
}

///|
pub fn NativeServiceActionStatus::name(
  self : NativeServiceActionStatus,
) -> String {
  match self {
    NativeServiceActionPrepared => "prepared"
    NativeServiceActionStarted => "started"
    NativeServiceActionReady => "ready"
    NativeServiceActionStopped => "stopped"
    NativeServiceActionSkipped(_) => "skipped"
    NativeServiceActionFailed(_) => "failed"
  }
}

///|
pub fn NativeServiceActionStatus::message(
  self : NativeServiceActionStatus,
) -> String {
  match self {
    NativeServiceActionSkipped(message) | NativeServiceActionFailed(message) =>
      message
    _ => ""
  }
}

///|
pub fn NativeServiceActionStatus::to_json(
  self : NativeServiceActionStatus,
) -> String {
  [
    "{",
    "\"name\":\{self.name().json_string()},",
    "\"message\":\{self.message().json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeServiceSupervisorReport::new(
  backend_name~ : String,
  webview_engine~ : String,
  action_reports? : Array[NativeServiceActionReport] = [],
) -> NativeServiceSupervisorReport {
  { backend_name, webview_engine, action_reports: action_reports.copy() }
}

///|
pub fn NativeServiceSupervisorReport::backend_name(
  self : NativeServiceSupervisorReport,
) -> String {
  self.backend_name
}

///|
pub fn NativeServiceSupervisorReport::webview_engine(
  self : NativeServiceSupervisorReport,
) -> String {
  self.webview_engine
}

///|
pub fn NativeServiceSupervisorReport::action_reports(
  self : NativeServiceSupervisorReport,
) -> Array[NativeServiceActionReport] {
  self.action_reports.copy()
}

///|
pub fn NativeServiceSupervisorReport::action_count(
  self : NativeServiceSupervisorReport,
) -> Int {
  self.action_reports.length()
}

///|
pub fn NativeServiceSupervisorReport::failed_count(
  self : NativeServiceSupervisorReport,
) -> Int {
  let mut count = 0
  for report in self.action_reports {
    if report.failed() {
      count += 1
    }
  }
  count
}

///|
pub fn NativeServiceSupervisorReport::ok(
  self : NativeServiceSupervisorReport,
) -> Bool {
  self.failed_count() == 0
}

///|
pub fn NativeServiceSupervisorReport::first_failure_message(
  self : NativeServiceSupervisorReport,
  context? : String = "native service supervisor",
) -> String? {
  for report in self.action_reports {
    match report.status() {
      NativeServiceActionFailed(message) =>
        return Some(
          "\{context}: \{report.action_kind()} \{report.service_name()}: \{message}",
        )
      _ => ()
    }
  }
  None
}

///|
pub fn NativeServiceSupervisorReport::to_json(
  self : NativeServiceSupervisorReport,
) -> String {
  [
    "{",
    "\"nativeBackend\":\{self.backend_name.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"ok\":\{self.ok().json_bool()},",
    "\"actionCount\":\{self.action_count()},",
    "\"failedCount\":\{self.failed_count()},",
    "\"actions\":[\{self.action_reports.map(fn(report) { report.to_json() }).join(",")}]",
    "}",
  ].join("")
}
