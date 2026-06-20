///|
test "native operation executor runs executable operation batches" {
  let started : Array[String] = []
  let scripts : Array[String] = []
  let drains : Array[String] = []
  let navigations : Array[String] = []
  let window_controls : Array[String] = []
  let executor = NativeOperationExecutor::new(
    start_service=fn(service) {
      started.push(service.name())
      NativeOperationExecuted
    },
    evaluate_script=fn(script) {
      scripts.push(script.script())
      NativeOperationExecuted
    },
    drain_bridge=fn(drain) {
      drains.push(drain.callback())
      NativeOperationExecuted
    },
    run_effect=fn(name) { NativeOperationSkipped("effect delegated: \{name}") },
    navigate_window=fn(navigation) {
      navigations.push(navigation.url())
      NativeOperationExecuted
    },
    control_window=fn(control) {
      window_controls.push(control.action())
      NativeOperationExecuted
    },
  )
  let service = @lepusa.LocalService::new(
    name="api",
    command=["moon", "run", "cmd/server"],
    readiness_url="http://127.0.0.1:4317/ready",
  )
  let operations = [
    NativeExecutableOperation::start_service(service),
    NativeExecutableOperation::evaluate_script(
      NativeEvaluationScript::new(window_label="main", script="render()"),
    ),
    NativeExecutableOperation::drain_bridge(
      NativeBridgeDrain::new(
        window_label="main",
        callback="bridge_loop_adapter().callbacks(main).drain_window_scripts",
      ),
    ),
    NativeExecutableOperation::run_effect("boot"),
    NativeExecutableOperation::navigate(
      NativeNavigation::new(window_label="main", url="lepusa://inline/main"),
    ),
    NativeExecutableOperation::window_control(
      NativeWindowControl::new(
        window_label="main",
        action="setTitle",
        payload="{\"title\":\"Ready\"}",
      ),
    ),
  ]
  let report = executor.execute_all(operations)
  assert_true(report.ok())
  assert_eq(report.operation_count(), 6)
  assert_eq(report.executed_count(), 5)
  assert_eq(report.skipped_count(), 1)
  assert_eq(report.failed_count(), 0)
  assert_true(report.first_failure_message() is None)
  assert_eq(started[0], "api")
  assert_eq(scripts[0], "render()")
  assert_eq(
    drains[0],
    "bridge_loop_adapter().callbacks(main).drain_window_scripts",
  )
  assert_eq(navigations[0], "lepusa://inline/main")
  assert_eq(window_controls[0], "setTitle")
  assert_eq(report.outcomes()[3].status().name(), "skipped")
  assert_eq(report.outcomes()[3].status().message(), "effect delegated: boot")
  let json = report.to_json()
  assert_true(json.contains("\"operationCount\":6"))
  assert_true(json.contains("\"executedCount\":5"))
  assert_true(json.contains("\"skippedCount\":1"))
  assert_true(json.contains("\"kind\":\"drain-bridge-window\""))
  assert_true(json.contains("\"kind\":\"navigate-window\""))
  assert_true(json.contains("\"kind\":\"window-control\""))
}

///|
test "native operation executor runs bridge drain deliveries" {
  let scripts : Array[String] = []
  let executor = NativeOperationExecutor::new(evaluate_script=fn(script) {
    scripts.push(script.script())
    if script.script().contains("fail") {
      NativeOperationFailed("evaluate failed for \{script.window_label()}")
    } else {
      NativeOperationExecuted
    }
  })
  let plan = NativeBridgeLoopEvaluationPlan::from_scripts(window_label="main", scripts=[
    "resolve(1)", "fail()",
  ])
  let report = executor.execute_plan(plan)
  assert_false(report.ok())
  assert_eq(report.operation_count(), 2)
  assert_eq(report.executed_count(), 1)
  assert_eq(report.failed_count(), 1)
  assert_eq(report.first_failure_message().unwrap(), "evaluate failed for main")
  assert_eq(scripts[0], "resolve(1)")
  assert_eq(scripts[1], "fail()")
  let delivery = NativeBridgeLoopDelivery::from_result(
    window_label="main",
    result=NativeBridgeLoopResult::new(immediate_script="resolve(2)"),
  )
  let delivery_report = executor.execute_delivery(delivery)
  assert_true(delivery_report.ok())
  assert_eq(delivery_report.executed_count(), 1)
}
