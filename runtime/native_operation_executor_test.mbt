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
  let packet = native_executable_operations_packet([
    NativeExecutableOperation::evaluate_script(
      NativeEvaluationScript::new(
        window_label="main",
        script="globalThis.done = true",
      ),
    ),
  ])
  assert_true(packet.contains("evaluate-script"))
  assert_true(packet.contains("globalThis.done = true"))
}

///|
test "native operation executor runs dynamic window operations" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    label="main",
    source=@lepusa.Source::html("<main></main>"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) =>
      match RuntimeHost::new(plan).snapshot() {
        Ok(session) => {
          let window = @lepusa.WindowConfig::new(
            label="tools",
            title="Tools",
            source=@lepusa.Source::html("<aside>tools</aside>"),
          )
          match session.open_window(window) {
            Ok(step) =>
              match step.operations()[0] {
                RuntimeOpenWindow(open_plan) => {
                  let opened : Array[String] = []
                  let closed : Array[String] = []
                  let executor = NativeOperationExecutor::new(
                    open_window=fn(plan) {
                      opened.push(plan.label())
                      NativeOperationExecuted
                    },
                    close_window=fn(close) {
                      closed.push(close.window_label())
                      NativeOperationExecuted
                    },
                  )
                  let report = executor.execute_all([
                    NativeExecutableOperation::open_window(open_plan),
                    NativeExecutableOperation::close_window(
                      NativeWindowClose::new(window_label="tools"),
                    ),
                  ])
                  assert_true(report.ok())
                  assert_eq(report.operation_count(), 2)
                  assert_eq(report.executed_count(), 2)
                  assert_eq(opened[0], "tools")
                  assert_eq(closed[0], "tools")
                  assert_true(
                    report.to_json().contains("\"kind\":\"open-window\""),
                  )
                  assert_true(
                    report.to_json().contains("\"kind\":\"close-window\""),
                  )
                }
                _ => fail("expected open-window runtime operation")
              }
            Err(_) => abort("unexpected dynamic window open failure")
          }
        }
        Err(_) => abort("unexpected invalid runtime session")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
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

///|
test "native operation executor runs app-will-exit lifecycle operations" {
  let effects : Array[String] = []
  let executor = NativeOperationExecutor::new(run_effect=fn(name) {
    effects.push(name)
    NativeOperationExecuted
  })
  let execution = NativeExecutionPlan::new(startup_operations=[], lifecycle_steps=[
    NativeExecutionStep::new(
      event_json=@lepusa.LifecycleEvent::app_will_exit().to_json(),
      operations=[NativeExecutableOperation::run_effect("flush")],
    ),
  ])
  match execution.app_will_exit_step() {
    Some(step) => assert_eq(step.operations()[0].kind(), "run-effect")
    None => fail("expected app-will-exit lifecycle step")
  }
  let report = executor.execute_app_will_exit(execution)
  assert_true(report.ok())
  assert_eq(report.operation_count(), 1)
  assert_eq(report.executed_count(), 1)
  assert_eq(effects[0], "flush")
}

///|
test "native operation executor treats missing app-will-exit as empty" {
  let execution = NativeExecutionPlan::new(startup_operations=[], lifecycle_steps=[])
  let report = NativeOperationExecutor::new().execute_app_will_exit(execution)
  assert_true(report.ok())
  assert_eq(report.operation_count(), 0)
  assert_true(execution.app_will_exit_step() is None)
}
