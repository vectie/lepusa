///|
fn test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="Linux", source=@lepusa.Source::html("<main>Linux</main>"))
    .with_startup(@lepusa.Cmd::effect("boot"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
fn async_test_host() -> @runtime.RuntimeHost {
  let registry = @lepusa.CommandRegistry::new().register_async_fn(
    "core.invoke",
    handler=fn(payload) { Ok(payload) },
  )
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="Linux", source=@lepusa.Source::html("<main>Linux</main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_async("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan, registry~)
    Err(_) => abort("unexpected invalid async Linux runtime plan")
  }
}

///|
test "linux backend exposes webkitgtk descriptor" {
  let descriptor = backend()
  assert_eq(descriptor.name(), "linux")
  assert_eq(descriptor.webview_engine(), "WebKitGTK")
  let capability = launch_capability()
  assert_true(capability.webview_creation())
  assert_true(capability.sync_bridge_evaluate())
  assert_false(capability.async_bridge_drain())
  assert_eq(capability.max_webviews(), 0)
  assert_true(
    capability
    .async_bridge_drain_message()
    .contains("async MoonBit-to-native callback ABI"),
  )
  let execution = operation_executor().execute_all([
    @runtime.NativeExecutableOperation::evaluate_script(
      @runtime.NativeEvaluationScript::new(
        window_label="main",
        script="resolve()",
      ),
    ),
    @runtime.NativeExecutableOperation::window_control(
      @runtime.NativeWindowControl::new(
        window_label="main",
        action="setTitle",
        payload="{\"title\":\"Ready\"}",
      ),
    ),
    @runtime.NativeExecutableOperation::close_window(
      @runtime.NativeWindowClose::new(window_label="main"),
    ),
    @runtime.NativeExecutableOperation::navigate(
      @runtime.NativeNavigation::new(
        window_label="main",
        url="lepusa://inline/main/index.html",
      ),
    ),
  ])
  assert_eq(execution.executed_count(), 4)
  assert_eq(execution.skipped_count(), 0)
}

///|
test "linux backend reports host availability" {
  match detect() {
    Ok(descriptor) => assert_eq(descriptor.name(), "linux")
    Err(problem) =>
      assert_eq(problem, "Linux WebKitGTK backend is not available")
  }
}

///|
test "linux backend lowers runtime host to native runner contract" {
  match backend().runner_plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "linux")
      assert_eq(plan.webview_engine(), "WebKitGTK")
      assert_eq(plan.webviews().length(), 1)
      assert_true(plan.startup_operations()[0] is NativeRunEffect("boot"))
      assert_true(plan.bootstrap_json().contains("\"nativeBackend\":\"linux\""))
    }
    Err(_) => abort("unexpected invalid Linux runner plan")
  }
}

///|
test "linux backend exposes native runtime facade" {
  match runtime(test_host()) {
    Ok(runtime) => {
      assert_eq(runtime.backend().name(), "linux")
      assert_true(
        runtime.bootstrap_json().contains("\"nativeBackend\":\"linux\""),
      )
    }
    Err(_) => abort("unexpected invalid Linux native runtime")
  }
}

///|
test "linux backend prepares run plan and reports unsupported launch" {
  match runtime(test_host()) {
    Ok(runtime) => {
      match run(runtime) {
        Ok(result) => {
          assert_true(result.status() is RunPrepared)
          assert_eq(result.plan().webview_count(), 1)
          assert_eq(
            result.plan().first_webview_url(),
            "lepusa://inline/main/index.html",
          )
          assert_eq(
            result.plan().first_webview_load_url(),
            "lepusa://inline/main/index.html",
          )
          match result.plan().first_webview() {
            Ok(webview) => {
              assert_eq(webview.title(), "Linux")
              assert_eq(webview.width(), 1000)
              assert_eq(webview.height(), 720)
              assert_eq(webview.native_hook(), "__lepusaInvoke")
              assert_eq(webview.asset_protocol(), "lepusa")
              assert_true(
                webview.initialization_script().contains("__lepusaInvoke"),
              )
              assert_true(
                webview
                .initialization_script()
                .contains("__lepusaInvokeResponse"),
              )
              assert_true(
                webview
                .initialization_script()
                .contains("webkit.messageHandlers"),
              )
            }
            Err(problem) => abort(problem)
          }
          assert_eq(result.plan().startup_operation_count(), 1)
          let execution = result.execution_plan()
          assert_eq(execution.startup_operations().length(), 1)
          assert_eq(execution.startup_operations()[0].kind(), "run-effect")
          assert_eq(
            execution.startup_operations()[0].effect_name().unwrap(),
            "boot",
          )
          let session = result.launch_session()
          assert_eq(session.webviews().length(), 1)
          assert_eq(
            session.execution().startup_operations()[0].kind(),
            "run-effect",
          )
          assert_eq(session.service_supervisor().backend_name(), "linux")
          assert_true(session.can_launch())
          assert_eq(
            result.plan().service_supervisor_plan().backend_name(),
            "linux",
          )
          assert_false(
            result.plan().service_supervisor_plan().requires_supervisor(),
          )
          assert_true(result.plan().service_supervisor_report().ok())
          assert_eq(result.plan().service_supervisor_report().action_count(), 0)
          assert_eq(execute_service_startup(result.plan()).action_count(), 0)
        }
        Err(_) => abort("unexpected invalid Linux dry run")
      }
      match launch(runtime) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(message.contains("WebKitGTK launch loop"))
            RunFailed(message) =>
              assert_true(message.contains("WebKitGTK launch failed"))
            _ => abort("unexpected Linux launch status")
          }
        Err(_) => abort("unexpected invalid Linux launch plan")
      }
    }
    Err(_) => abort("unexpected invalid Linux native runtime")
  }
}

///|
test "linux launch reports async bridge scheduler requirement" {
  match runtime(async_test_host()) {
    Ok(runtime) =>
      match launch(runtime) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(
                message.contains("async MoonBit-to-native callback ABI"),
              )
            _ => abort("unexpected Linux async launch status")
          }
        Err(_) => abort("unexpected invalid Linux async launch plan")
      }
    Err(_) => abort("unexpected invalid Linux async native runtime")
  }
  match
    @bundled.BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      linux_async_bundled_manifest(),
    ) {
    Ok(manifest) =>
      match launch_bundled(manifest) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(
                message.contains("async MoonBit-to-native callback ABI"),
              )
            _ => abort("unexpected Linux bundled async launch status")
          }
        Err(_) => abort("unexpected invalid Linux bundled async launch plan")
      }
    Err(problem) => abort(problem)
  }
}

///|
test "linux backend prepares bundled runtime contract" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      linux_bundled_manifest(),
    ) {
    Ok(manifest) => {
      match prepare_bundled_run(manifest) {
        Ok(plan) => {
          assert_eq(plan.webview_count(), 1)
          assert_eq(
            plan.first_webview_url(),
            "lepusa://rabbita/main/index.html",
          )
          assert_eq(
            plan.first_webview_load_url(),
            "lepusa://rabbita/main/index.html",
          )
          assert_eq(plan.startup_operation_count(), 2)
          assert_eq(plan.lifecycle_step_count(), 1)
          assert_true(
            plan.bootstrap_json().contains("\"nativeBackend\":\"linux\""),
          )
          assert_true(
            plan.bootstrap_json().contains("\"webviewEngine\":\"WebKitGTK\""),
          )
          assert_true(plan.bootstrap_json().contains("\"serviceSupervisor\""))
          let supervisor = plan.service_supervisor_plan()
          assert_eq(supervisor.backend_name(), "linux")
          assert_eq(supervisor.webview_engine(), "WebKitGTK")
          assert_true(supervisor.requires_supervisor())
          assert_eq(supervisor.start_order()[0], "api")
          assert_true(supervisor.startup_actions()[0] is StartLocalService(_))
          assert_true(
            supervisor.startup_actions()[1] is WaitLocalServiceReady(_),
          )
          assert_true(supervisor.shutdown_actions()[0] is StopLocalService(_))
          let report = plan.service_supervisor_report()
          assert_eq(report.backend_name(), "linux")
          assert_true(report.ok())
          assert_eq(report.action_count(), 3)
          match execute_bundled_app_will_exit(plan) {
            Ok(lifecycle) => {
              assert_true(lifecycle.ok())
              assert_eq(lifecycle.operation_count(), 1)
              assert_eq(lifecycle.skipped_count(), 1)
            }
            Err(problem) => abort(problem)
          }
          match plan.first_webview() {
            Ok(webview) => {
              assert_eq(webview.asset_protocol(), "lepusa")
              assert_eq(webview.native_hook(), "__lepusaInvoke")
              assert_true(
                webview
                .initialization_script()
                .contains("webkit.messageHandlers"),
              )
            }
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid Linux bundled run plan")
      }
      match run_bundled(manifest) {
        Ok(result) => {
          assert_true(result.status() is RunPrepared)
          assert_eq(result.report().target(), "linux")
          assert_eq(result.report().backend(), "linux")
          assert_eq(result.report().engine(), "WebKitGTK")
          assert_eq(result.report().startup_operations(), 2)
          assert_eq(result.report().executable_operations(), 2)
          assert_eq(result.report().skipped_operations(), 2)
          assert_eq(result.report().failed_operations(), 0)
          assert_eq(
            result.report().load_url(),
            "lepusa://rabbita/main/index.html",
          )
          match result.execution_plan() {
            Ok(execution) => {
              assert_eq(execution.startup_operations().length(), 2)
              assert_eq(
                execution.startup_operations()[0].kind(),
                "start-service",
              )
              assert_eq(
                execution.startup_operations()[0].service().unwrap().name(),
                "api",
              )
              assert_eq(execution.startup_operations()[1].kind(), "run-effect")
            }
            Err(problem) => abort(problem)
          }
          match result.launch_session() {
            Ok(session) => {
              assert_eq(session.webviews().length(), 1)
              assert_eq(session.execution().startup_operations().length(), 2)
              assert_true(session.service_supervisor().requires_supervisor())
              assert_true(session.can_launch())
            }
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid Linux bundled dry run")
      }
      match launch_bundled(manifest) {
        Ok(result) =>
          match result.status() {
            RunFailed(message) => {
              assert_true(message.contains("Linux bundled service startup"))
              assert_true(message.contains("start-service api"))
            }
            _ => abort("unexpected Linux bundled launch status")
          }
        Err(_) => abort("unexpected invalid Linux bundled launch plan")
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "linux service executor reports native service failures" {
  let service = @lepusa.LocalService::new(
    name="missing",
    command=["/definitely/not/a/lepusa/service"],
    readiness_url="not-a-url",
  )
  let plan = @runtime.NativeServiceSupervisorPlan::new(
    backend_name="linux",
    webview_engine="WebKitGTK",
    plan=@lepusa.LocalServiceSupervisorPlan::new(services=[service], startup_services=[
      service,
    ]),
  )
  let startup = service_executor().execute_startup(plan)
  assert_false(startup.ok())
  assert_eq(startup.action_count(), 2)
  match startup.first_failure_message(context="Linux service startup") {
    Some(message) => {
      assert_true(message.contains("Linux service startup"))
      assert_true(message.contains("start-service missing"))
      assert_true(message.contains("Linux service start failed"))
    }
    None => abort("expected Linux service startup failure message")
  }
  assert_true(
    startup.action_reports()[0].status() is NativeServiceActionFailed(message) &&
    message.contains("Linux service start failed"),
  )
  assert_true(
    startup.action_reports()[1].status() is NativeServiceActionFailed(message) &&
    message.contains("Linux service readiness failed"),
  )
  let shutdown = service_executor().execute_shutdown(plan)
  assert_true(shutdown.ok())
  assert_true(
    shutdown.action_reports()[0].status() is NativeServiceActionSkipped(message) &&
    message.contains("process is not tracked"),
  )
}

///|
test "linux backend rejects mismatched bundled target" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      linux_bundled_manifest().replace_all(
        old="\"target\": \"linux\"",
        new="\"target\": \"windows\"",
      ),
    ) {
    Ok(manifest) =>
      match prepare_bundled_run(manifest) {
        Ok(_) => abort("unexpected Linux bundled target match")
        Err(problems) =>
          assert_eq(
            problems[0],
            "Linux bundled run requires target linux: windows",
          )
      }
    Err(problem) => abort(problem)
  }
}

///|
fn linux_async_bundled_manifest() -> String {
  linux_bundled_manifest()
  .replace_all(
    old="\"allowedRoutes\": [\"log.write\"]",
    new="\"allowedRoutes\": [\"fs.readText\"]",
  )
  .replace_all(
    old="\"registeredRoutes\": [\"log.write\"]",
    new="\"registeredRoutes\": [\"fs.readText\"]",
  )
}

///|
fn linux_bundled_manifest() -> String {
  (
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "linux",
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "headless",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Runtime App",
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "allowedRoutes": ["log.write"]
    #|    }],
    #|    "localServices": [{
    #|      "name": "api",
    #|      "command": ["moon", "run", "cmd/server"],
    #|      "readinessUrl": "http://127.0.0.1:4317/ready"
    #|    }],
    #|    "startupActions": [{ "kind": "effect", "name": "boot" }],
    #|    "lifecycleHooks": [
    #|      {
    #|        "event": { "kind": "app-will-exit" },
    #|        "actions": [{ "kind": "effect", "name": "flush" }]
    #|      }
    #|    ],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  )
}
