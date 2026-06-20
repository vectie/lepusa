///|
test "native operation executor runs executable operation batches" {
  let started : Array[String] = []
  let scripts : Array[String] = []
  let navigations : Array[String] = []
  let executor = NativeOperationExecutor::new(
    start_service=fn(service) {
      started.push(service.name())
      NativeOperationExecuted
    },
    evaluate_script=fn(script) {
      scripts.push(script.script())
      NativeOperationExecuted
    },
    run_effect=fn(name) { NativeOperationSkipped("effect delegated: \{name}") },
    navigate_window=fn(navigation) {
      navigations.push(navigation.url())
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
    NativeExecutableOperation::run_effect("boot"),
    NativeExecutableOperation::navigate(
      NativeNavigation::new(window_label="main", url="lepusa://inline/main"),
    ),
  ]
  let report = executor.execute_all(operations)
  assert_true(report.ok())
  assert_eq(report.operation_count(), 4)
  assert_eq(report.executed_count(), 3)
  assert_eq(report.skipped_count(), 1)
  assert_eq(report.failed_count(), 0)
  assert_true(report.first_failure_message() is None)
  assert_eq(started[0], "api")
  assert_eq(scripts[0], "render()")
  assert_eq(navigations[0], "lepusa://inline/main")
  assert_eq(report.outcomes()[2].status().name(), "skipped")
  assert_eq(report.outcomes()[2].status().message(), "effect delegated: boot")
  let json = report.to_json()
  assert_true(json.contains("\"operationCount\":4"))
  assert_true(json.contains("\"executedCount\":3"))
  assert_true(json.contains("\"skippedCount\":1"))
  assert_true(json.contains("\"kind\":\"navigate-window\""))
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
