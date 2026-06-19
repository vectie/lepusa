///|
fn test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      title="Windows",
      source=@lepusa.Source::html("<main>Windows</main>"),
    )
    .with_startup(@lepusa.Cmd::effect("boot"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "windows backend exposes webview2 descriptor" {
  let descriptor = backend()
  assert_eq(descriptor.name(), "windows")
  assert_eq(descriptor.webview_engine(), "WebView2")
}

///|
test "windows backend reports host availability" {
  match detect() {
    Ok(descriptor) => assert_eq(descriptor.name(), "windows")
    Err(problem) =>
      assert_eq(problem, "Windows WebView2 backend is not available")
  }
}

///|
test "windows backend lowers runtime host to native runner contract" {
  match backend().runner_plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "windows")
      assert_eq(plan.webview_engine(), "WebView2")
      assert_eq(plan.webviews().length(), 1)
      assert_true(plan.startup_operations()[0] is NativeRunEffect("boot"))
      assert_true(
        plan.bootstrap_json().contains("\"nativeBackend\":\"windows\""),
      )
    }
    Err(_) => abort("unexpected invalid Windows runner plan")
  }
}

///|
test "windows backend exposes native runtime facade" {
  match runtime(test_host()) {
    Ok(runtime) => {
      assert_eq(runtime.backend().name(), "windows")
      assert_true(
        runtime.bootstrap_json().contains("\"nativeBackend\":\"windows\""),
      )
    }
    Err(_) => abort("unexpected invalid Windows native runtime")
  }
}

///|
test "windows backend prepares run plan and reports unsupported launch" {
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
              assert_eq(webview.title(), "Windows")
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
                webview.initialization_script().contains("chrome.webview"),
              )
            }
            Err(problem) => abort(problem)
          }
          assert_eq(result.plan().startup_operation_count(), 1)
          assert_eq(
            result.plan().service_supervisor_plan().backend_name(),
            "windows",
          )
          assert_false(
            result.plan().service_supervisor_plan().requires_supervisor(),
          )
          assert_true(result.plan().service_supervisor_report().ok())
          assert_eq(result.plan().service_supervisor_report().action_count(), 0)
          assert_eq(result.plan().execute_service_startup().action_count(), 0)
        }
        Err(_) => abort("unexpected invalid Windows dry run")
      }
      match launch(runtime) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(message.contains("WebView2 launch loop"))
            _ => abort("unexpected Windows launch status")
          }
        Err(_) => abort("unexpected invalid Windows launch plan")
      }
    }
    Err(_) => abort("unexpected invalid Windows native runtime")
  }
}

///|
test "windows backend prepares bundled runtime contract" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      windows_bundled_manifest(),
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
            plan.bootstrap_json().contains("\"nativeBackend\":\"windows\""),
          )
          assert_true(
            plan.bootstrap_json().contains("\"webviewEngine\":\"WebView2\""),
          )
          assert_true(plan.bootstrap_json().contains("\"serviceSupervisor\""))
          let supervisor = plan.service_supervisor_plan()
          assert_eq(supervisor.backend_name(), "windows")
          assert_eq(supervisor.webview_engine(), "WebView2")
          assert_true(supervisor.requires_supervisor())
          assert_eq(supervisor.start_order()[0], "api")
          assert_true(supervisor.startup_actions()[0] is StartLocalService(_))
          assert_true(
            supervisor.startup_actions()[1] is WaitLocalServiceReady(_),
          )
          assert_true(supervisor.shutdown_actions()[0] is StopLocalService(_))
          let report = plan.service_supervisor_report()
          assert_eq(report.backend_name(), "windows")
          assert_true(report.ok())
          assert_eq(report.action_count(), 3)
          match plan.first_webview() {
            Ok(webview) => {
              assert_eq(webview.asset_protocol(), "lepusa")
              assert_eq(webview.native_hook(), "__lepusaInvoke")
              assert_true(
                webview.initialization_script().contains("chrome.webview"),
              )
            }
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid Windows bundled run plan")
      }
      match run_bundled(manifest) {
        Ok(result) => {
          assert_true(result.status() is RunPrepared)
          assert_eq(result.report().target(), "windows")
          assert_eq(result.report().backend(), "windows")
          assert_eq(result.report().engine(), "WebView2")
          assert_eq(result.report().startup_operations(), 2)
          assert_eq(
            result.report().load_url(),
            "lepusa://rabbita/main/index.html",
          )
        }
        Err(_) => abort("unexpected invalid Windows bundled dry run")
      }
      match launch_bundled(manifest) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(message.contains("WebView2 launch loop"))
            _ => abort("unexpected Windows bundled launch status")
          }
        Err(_) => abort("unexpected invalid Windows bundled launch plan")
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "windows service executor reports native service failures" {
  let service = @lepusa.LocalService::new(
    name="missing",
    command=["C:\\definitely\\not\\a\\lepusa\\service.exe"],
    readiness_url="not-a-url",
  )
  let plan = @runtime.NativeServiceSupervisorPlan::new(
    backend_name="windows",
    webview_engine="WebView2",
    plan=@lepusa.LocalServiceSupervisorPlan::new(services=[service], startup_services=[
      service,
    ]),
  )
  let startup = service_executor().execute_startup(plan)
  assert_false(startup.ok())
  assert_eq(startup.action_count(), 2)
  assert_true(
    startup.action_reports()[0].status() is NativeServiceActionFailed(message) &&
    message.contains("Windows service start failed"),
  )
  assert_true(
    startup.action_reports()[1].status() is NativeServiceActionFailed(message) &&
    message.contains("Windows service readiness failed"),
  )
  let shutdown = service_executor().execute_shutdown(plan)
  assert_true(shutdown.ok())
  assert_true(
    shutdown.action_reports()[0].status() is NativeServiceActionSkipped(message) &&
    message.contains("process is not tracked"),
  )
}

///|
test "windows backend rejects mismatched bundled target" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      windows_bundled_manifest().replace_all(
        old="\"target\": \"windows\"",
        new="\"target\": \"linux\"",
      ),
    ) {
    Ok(manifest) =>
      match prepare_bundled_run(manifest) {
        Ok(_) => abort("unexpected Windows bundled target match")
        Err(problems) =>
          assert_eq(
            problems[0],
            "Windows bundled run requires target windows: linux",
          )
      }
    Err(problem) => abort(problem)
  }
}

///|
fn windows_bundled_manifest() -> String {
  (
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "windows",
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
