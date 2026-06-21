///|
pub(all) enum NativeOperationExecutionStatus {
  NativeOperationExecuted
  NativeOperationSkipped(String)
  NativeOperationFailed(String)
} derive(Debug, Eq)

///|
pub struct NativeOperationExecutionOutcome {
  operation : NativeExecutableOperation
  status : NativeOperationExecutionStatus
} derive(Debug, Eq)

///|
pub struct NativeOperationExecutionReport {
  outcomes : Array[NativeOperationExecutionOutcome]
} derive(Debug, Eq)

///|
pub struct NativeOperationExecutor {
  start_service : (@lepusa.LocalService) -> NativeOperationExecutionStatus
  open_window : (RuntimeWindowOpenPlan) -> NativeOperationExecutionStatus
  close_window : (NativeWindowClose) -> NativeOperationExecutionStatus
  evaluate_script : (NativeEvaluationScript) -> NativeOperationExecutionStatus
  drain_bridge : (NativeBridgeDrain) -> NativeOperationExecutionStatus
  run_effect : (String) -> NativeOperationExecutionStatus
  navigate_window : (NativeNavigation) -> NativeOperationExecutionStatus
  control_window : (NativeWindowControl) -> NativeOperationExecutionStatus
}

///|
pub fn NativeOperationExecutor::new(
  start_service? : (@lepusa.LocalService) -> NativeOperationExecutionStatus = fn(
    _,
  ) {
    NativeOperationSkipped(
      "native service startup is handled by NativeServiceExecutor",
    )
  },
  open_window? : (RuntimeWindowOpenPlan) -> NativeOperationExecutionStatus = fn(
    _,
  ) {
    NativeOperationSkipped("native dynamic window open handler is unavailable")
  },
  close_window? : (NativeWindowClose) -> NativeOperationExecutionStatus = fn(
    _,
  ) {
    NativeOperationSkipped("native dynamic window close handler is unavailable")
  },
  evaluate_script? : (NativeEvaluationScript) -> NativeOperationExecutionStatus = fn(
    _,
  ) {
    NativeOperationSkipped("native script evaluation handler is unavailable")
  },
  drain_bridge? : (NativeBridgeDrain) -> NativeOperationExecutionStatus = fn(
    _,
  ) {
    NativeOperationSkipped("native bridge drain handler is unavailable")
  },
  run_effect? : (String) -> NativeOperationExecutionStatus = fn(_) {
    NativeOperationSkipped("native effect handler is unavailable")
  },
  navigate_window? : (NativeNavigation) -> NativeOperationExecutionStatus = fn(
    _,
  ) {
    NativeOperationSkipped("native window navigation handler is unavailable")
  },
  control_window? : (NativeWindowControl) -> NativeOperationExecutionStatus = fn(
    _,
  ) {
    NativeOperationSkipped("native window control handler is unavailable")
  },
) -> NativeOperationExecutor {
  {
    start_service,
    open_window,
    close_window,
    evaluate_script,
    drain_bridge,
    run_effect,
    navigate_window,
    control_window,
  }
}

///|
pub fn NativeOperationExecutor::execute(
  self : NativeOperationExecutor,
  operation : NativeExecutableOperation,
) -> NativeOperationExecutionOutcome {
  let status = match operation {
    NativeExecutableStartService(service) => (self.start_service)(service)
    NativeExecutableOpenWindow(open_plan) => (self.open_window)(open_plan)
    NativeExecutableCloseWindow(close) => (self.close_window)(close)
    NativeExecutableEvaluateScript(script) => (self.evaluate_script)(script)
    NativeExecutableDrainBridge(drain) => (self.drain_bridge)(drain)
    NativeExecutableRunEffect(name) => (self.run_effect)(name)
    NativeExecutableNavigate(navigation) => (self.navigate_window)(navigation)
    NativeExecutableWindowControl(control) => (self.control_window)(control)
  }
  { operation, status }
}

///|
pub fn NativeOperationExecutor::execute_all(
  self : NativeOperationExecutor,
  operations : Array[NativeExecutableOperation],
) -> NativeOperationExecutionReport {
  { outcomes: operations.map(fn(operation) { self.execute(operation) }) }
}

///|
pub fn NativeOperationExecutor::execute_plan(
  self : NativeOperationExecutor,
  plan : NativeBridgeLoopEvaluationPlan,
) -> NativeOperationExecutionReport {
  self.execute_all(plan.operations())
}

///|
pub fn NativeOperationExecutor::execute_delivery(
  self : NativeOperationExecutor,
  delivery : NativeBridgeLoopDelivery,
) -> NativeOperationExecutionReport {
  self.execute_plan(delivery.evaluation_plan())
}

///|
pub fn NativeOperationExecutor::execute_startup(
  self : NativeOperationExecutor,
  execution : NativeExecutionPlan,
) -> NativeOperationExecutionReport {
  self.execute_all(execution.startup_operations())
}

///|
pub fn NativeOperationExecutor::execute_lifecycle_step(
  self : NativeOperationExecutor,
  step : NativeExecutionStep,
) -> NativeOperationExecutionReport {
  self.execute_all(step.operations())
}

///|
pub fn NativeOperationExecutor::execute_app_will_exit(
  self : NativeOperationExecutor,
  execution : NativeExecutionPlan,
) -> NativeOperationExecutionReport {
  match execution.app_will_exit_step() {
    Some(step) => self.execute_lifecycle_step(step)
    None => self.execute_all([])
  }
}

///|
pub fn NativeOperationExecutionStatus::name(
  self : NativeOperationExecutionStatus,
) -> String {
  match self {
    NativeOperationExecuted => "executed"
    NativeOperationSkipped(_) => "skipped"
    NativeOperationFailed(_) => "failed"
  }
}

///|
pub fn NativeOperationExecutionStatus::message(
  self : NativeOperationExecutionStatus,
) -> String {
  match self {
    NativeOperationExecuted => ""
    NativeOperationSkipped(message) | NativeOperationFailed(message) => message
  }
}

///|
pub fn NativeOperationExecutionStatus::ok(
  self : NativeOperationExecutionStatus,
) -> Bool {
  !(self is NativeOperationFailed(_))
}

///|
pub fn NativeOperationExecutionStatus::to_json(
  self : NativeOperationExecutionStatus,
) -> String {
  [
    "{",
    "\"name\":\{self.name().json_string()},",
    "\"message\":\{self.message().json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeOperationExecutionOutcome::operation(
  self : NativeOperationExecutionOutcome,
) -> NativeExecutableOperation {
  self.operation
}

///|
pub fn NativeOperationExecutionOutcome::status(
  self : NativeOperationExecutionOutcome,
) -> NativeOperationExecutionStatus {
  self.status
}

///|
pub fn NativeOperationExecutionOutcome::ok(
  self : NativeOperationExecutionOutcome,
) -> Bool {
  self.status.ok()
}

///|
pub fn NativeOperationExecutionOutcome::to_json(
  self : NativeOperationExecutionOutcome,
) -> String {
  [
    "{",
    "\"operation\":\{self.operation.to_json()},",
    "\"status\":\{self.status.to_json()}",
    "}",
  ].join("")
}

///|
pub fn NativeOperationExecutionReport::outcomes(
  self : NativeOperationExecutionReport,
) -> Array[NativeOperationExecutionOutcome] {
  self.outcomes.copy()
}

///|
pub fn NativeOperationExecutionReport::operation_count(
  self : NativeOperationExecutionReport,
) -> Int {
  self.outcomes.length()
}

///|
pub fn NativeOperationExecutionReport::executed_count(
  self : NativeOperationExecutionReport,
) -> Int {
  self.count_status("executed")
}

///|
pub fn NativeOperationExecutionReport::skipped_count(
  self : NativeOperationExecutionReport,
) -> Int {
  self.count_status("skipped")
}

///|
pub fn NativeOperationExecutionReport::failed_count(
  self : NativeOperationExecutionReport,
) -> Int {
  self.count_status("failed")
}

///|
pub fn NativeOperationExecutionReport::ok(
  self : NativeOperationExecutionReport,
) -> Bool {
  self.failed_count() == 0
}

///|
pub fn NativeOperationExecutionReport::first_failure_message(
  self : NativeOperationExecutionReport,
) -> String? {
  for outcome in self.outcomes {
    match outcome.status() {
      NativeOperationFailed(message) => return Some(message)
      _ => ()
    }
  }
  None
}

///|
pub fn NativeOperationExecutionReport::to_json(
  self : NativeOperationExecutionReport,
) -> String {
  [
    "{",
    "\"operationCount\":\{self.operation_count()},",
    "\"executedCount\":\{self.executed_count()},",
    "\"skippedCount\":\{self.skipped_count()},",
    "\"failedCount\":\{self.failed_count()},",
    "\"ok\":\{self.ok().json_bool()},",
    "\"outcomes\":[\{self.outcomes.map(fn(outcome) { outcome.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn NativeOperationExecutionReport::count_status(
  self : NativeOperationExecutionReport,
  name : String,
) -> Int {
  let mut count = 0
  for outcome in self.outcomes {
    if outcome.status().name() == name {
      count += 1
    }
  }
  count
}
