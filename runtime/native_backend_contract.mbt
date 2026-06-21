///|
pub struct NativeBackendContract {
  backend_name : String
  webview_engine : String
  platform_name : String
  capability : NativeLaunchCapability
  bridge_scheduler : NativeBridgeScheduler
  async_executor : NativeBridgeAsyncExecutor
  bridge_loop : NativeBridgeLoopContract
  invoke_contract_report : @lepusa.InvokeContractReport
  webview_count : Int
  launch_blocker : String?
  problems : Array[String]
} derive(Debug, Eq)

///|
pub fn NativeBackend::contract(
  self : NativeBackend,
  host : RuntimeHost,
  capability~ : NativeLaunchCapability,
  platform_name? : String = self.name,
) -> Result[NativeBackendContract, Array[String]] {
  match self.runner_plan(host) {
    Ok(runner) =>
      Ok(
        NativeBackendContract::from_runner(
          runner,
          capability~,
          invoke_contract_report=host.invoke_contract_report(),
          platform_name~,
        ),
      )
    Err(problems) => Err(problems)
  }
}

///|
pub fn NativeRuntime::backend_contract(
  self : NativeRuntime,
  capability~ : NativeLaunchCapability,
  platform_name? : String = self.backend().name(),
) -> NativeBackendContract {
  NativeBackendContract::from_runner(
    self.runner_plan(),
    capability~,
    invoke_contract_report=self.host().invoke_contract_report(),
    platform_name~,
  )
}

///|
pub fn NativePreparedRunPlan::backend_contract(
  self : NativePreparedRunPlan,
  capability~ : NativeLaunchCapability,
  invoke_contract_report~ : @lepusa.InvokeContractReport,
  platform_name~ : String,
) -> NativeBackendContract {
  NativeBackendContract::from_runner(
    self.runner(),
    capability~,
    invoke_contract_report~,
    platform_name~,
    webview_count=self.webview_count(),
  )
}

///|
fn NativeBackendContract::from_runner(
  runner : NativeRunnerPlan,
  capability~ : NativeLaunchCapability,
  invoke_contract_report~ : @lepusa.InvokeContractReport,
  platform_name~ : String,
  webview_count? : Int = runner.webview_specs().length(),
) -> NativeBackendContract {
  let bridge_scheduler = runner.bridge_scheduler(mode=capability.bridge_mode())
  let launch_blocker = match
    capability.launch_blocker(platform_name, bridge_scheduler) {
    Some(message) => Some(message)
    None => capability.webview_count_blocker(platform_name, webview_count)
  }
  let problems : Array[String] = []
  match launch_blocker {
    Some(message) => native_backend_contract_push_unique(problems, message)
    None => ()
  }
  for problem in invoke_contract_report.problems() {
    native_backend_contract_push_unique(problems, "invoke contract: \{problem}")
  }
  let dispatchable_routes = invoke_contract_report.dispatchable_routes()
  for route in bridge_scheduler.sync_routes() {
    if !dispatchable_routes.contains(route) {
      native_backend_contract_push_unique(
        problems,
        "bridge sync route is not dispatchable by invoke contract: \{route}",
      )
    }
  }
  for route in bridge_scheduler.async_routes() {
    if !dispatchable_routes.contains(route) {
      native_backend_contract_push_unique(
        problems,
        "bridge async route is not dispatchable by invoke contract: \{route}",
      )
    }
  }
  {
    backend_name: runner.backend_name(),
    webview_engine: runner.webview_engine(),
    platform_name,
    capability,
    bridge_scheduler,
    async_executor: bridge_scheduler.async_executor(),
    bridge_loop: bridge_scheduler.bridge_loop_contract(),
    invoke_contract_report,
    webview_count,
    launch_blocker,
    problems,
  }
}

///|
pub fn NativeBackendContract::backend_name(
  self : NativeBackendContract,
) -> String {
  self.backend_name
}

///|
pub fn NativeBackendContract::webview_engine(
  self : NativeBackendContract,
) -> String {
  self.webview_engine
}

///|
pub fn NativeBackendContract::platform_name(
  self : NativeBackendContract,
) -> String {
  self.platform_name
}

///|
pub fn NativeBackendContract::capability(
  self : NativeBackendContract,
) -> NativeLaunchCapability {
  self.capability
}

///|
pub fn NativeBackendContract::bridge_scheduler(
  self : NativeBackendContract,
) -> NativeBridgeScheduler {
  self.bridge_scheduler
}

///|
pub fn NativeBackendContract::async_executor(
  self : NativeBackendContract,
) -> NativeBridgeAsyncExecutor {
  self.async_executor
}

///|
pub fn NativeBackendContract::bridge_loop(
  self : NativeBackendContract,
) -> NativeBridgeLoopContract {
  self.bridge_loop
}

///|
pub fn NativeBackendContract::invoke_contract_report(
  self : NativeBackendContract,
) -> @lepusa.InvokeContractReport {
  self.invoke_contract_report
}

///|
pub fn NativeBackendContract::webview_count(
  self : NativeBackendContract,
) -> Int {
  self.webview_count
}

///|
pub fn NativeBackendContract::launch_blocker(
  self : NativeBackendContract,
) -> String? {
  self.launch_blocker
}

///|
pub fn NativeBackendContract::problems(
  self : NativeBackendContract,
) -> Array[String] {
  self.problems.copy()
}

///|
pub fn NativeBackendContract::ok(self : NativeBackendContract) -> Bool {
  self.problems.is_empty()
}

///|
pub fn NativeBackendContract::can_launch(self : NativeBackendContract) -> Bool {
  self.ok()
}

///|
pub fn NativeBackendContract::to_json(self : NativeBackendContract) -> String {
  [
    "{",
    "\"ok\":\{self.ok().json_bool()},",
    "\"canLaunch\":\{self.can_launch().json_bool()},",
    "\"backendName\":\{self.backend_name.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"platformName\":\{self.platform_name.json_string()},",
    "\"webviewCount\":\{self.webview_count},",
    "\"launchBlocker\":\{native_backend_contract_optional_json(self.launch_blocker)},",
    "\"problems\":[\{self.problems.map(fn(problem) { problem.json_string() }).join(",")}],",
    "\"capability\":\{self.capability.to_json()},",
    "\"bridgeScheduler\":\{self.bridge_scheduler.to_json()},",
    "\"asyncExecutor\":\{self.async_executor.to_json()},",
    "\"bridgeLoop\":\{self.bridge_loop.to_json()},",
    "\"invokeContractReport\":\{self.invoke_contract_report.to_json()}",
    "}",
  ].join("")
}

///|
fn native_backend_contract_optional_json(value : String?) -> String {
  match value {
    Some(text) => text.json_string()
    None => "null"
  }
}

///|
fn native_backend_contract_push_unique(
  values : Array[String],
  value : String,
) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}
