///|
fn test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="macOS", source=@lepusa.Source::html("<main>macOS</main>"))
    .with_startup(
      @lepusa.Cmd::batch([
        @lepusa.Cmd::emit(
          @lepusa.Event::new("ready"),
          target=WindowTarget("main"),
        ),
        @lepusa.Cmd::effect("boot"),
        @lepusa.Cmd::navigate(
          "main",
          @lepusa.Source::html("<main>ready</main>"),
        ),
      ]),
    )
    .with_lifecycle(
      @lepusa.LifecycleEvent::app_will_exit(),
      @lepusa.Cmd::effect("flush"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
fn multi_window_test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="main",
      title="Main",
      width=900,
      height=640,
      source=@lepusa.Source::html("<main>Main</main>"),
    )
    .window(
      label="settings",
      title="Settings",
      width=700,
      height=520,
      resizable=false,
      source=@lepusa.Source::html("<main>Settings</main>"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid multi-window runtime plan")
  }
}

///|
fn bridge_test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="macOS", source=@lepusa.Source::html("<main>macOS</main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => {
      let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
        payload,
      ) {
        Ok("{\"seen\":\{payload}}")
      })
      @runtime.RuntimeHost::new(plan, registry~)
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
fn async_bridge_test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="macOS", source=@lepusa.Source::html("<main>macOS</main>"))
    .with_plugin(@lepusa.Plugin::new("fs").command_async("readText"))
    .with_capability(
      @lepusa.Capability::new("fs").window("main").command("fs.readText"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => {
      let registry = @lepusa.CommandRegistry::new().register_async_fn(
        "fs.readText",
        handler=fn(payload) { Ok("{\"read\":\{payload}}") },
      )
      @runtime.RuntimeHost::new(plan, registry~)
    }
    Err(_) => abort("unexpected invalid async runtime plan")
  }
}

///|
test "macos backend exposes wkwebview descriptor" {
  let descriptor = backend()
  assert_eq(descriptor.name(), "macos")
  assert_eq(descriptor.webview_engine(), "WKWebView")
  let capability = launch_capability()
  assert_true(capability.webview_creation())
  assert_true(capability.sync_bridge_evaluate())
  assert_true(capability.async_bridge_drain())
  assert_eq(capability.max_webviews(), 0)
  assert_true(
    capability
    .async_bridge_drain_message()
    .contains("packetized event-loop requests"),
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
    @runtime.NativeExecutableOperation::desktop_shell(
      @runtime.NativeDesktopShellOperation::new(
        domain="app",
        action="exit",
        window_label="main",
      ),
    ),
    @runtime.NativeExecutableOperation::desktop_shell(
      @runtime.NativeDesktopShellOperation::new(
        domain="app",
        action="restart",
        window_label="main",
      ),
    ),
    @runtime.NativeExecutableOperation::desktop_shell(
      @runtime.NativeDesktopShellOperation::new(
        domain="app",
        action="setTheme",
        window_label="main",
        payload="\"dark\"",
      ),
    ),
    @runtime.NativeExecutableOperation::desktop_shell(
      @runtime.NativeDesktopShellOperation::new(
        domain="app",
        action="setDockVisibility",
        window_label="main",
        payload="{\"visible\":false}",
      ),
    ),
    @runtime.NativeExecutableOperation::desktop_shell(
      @runtime.NativeDesktopShellOperation::new(
        domain="menu",
        action="setAppMenu",
        target="app",
        window_label="main",
      ),
    ),
  ])
  assert_eq(execution.executed_count(), 8)
  assert_eq(execution.skipped_count(), 1)
  assert_true(execution.outcomes()[5].status() is NativeOperationExecuted)
  assert_true(execution.outcomes()[6].status() is NativeOperationExecuted)
  assert_true(execution.outcomes()[7].status() is NativeOperationExecuted)
  match execution.outcomes()[8].status() {
    NativeOperationSkipped(message) =>
      assert_true(message.contains("menu.setAppMenu"))
    _ => abort("expected native menu renderer to be skipped")
  }
}

///|
test "macos backend links Cocoa and WebKit" {
  match detect() {
    Ok(descriptor) => {
      assert_eq(descriptor.name(), "macos")
      assert_eq(descriptor.webview_engine(), "WKWebView")
    }
    Err(problem) => abort(problem)
  }
}

///|
test "macos backend lowers runtime host to launch plan" {
  match backend().plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "macos")
      assert_eq(plan.webview_engine(), "WKWebView")
      let webviews = plan.webviews()
      assert_eq(webviews.length(), 1)
      assert_eq(webviews[0].title(), "macOS")
      assert_eq(webviews[0].url(), "lepusa://inline/main/index.html")
      assert_true(
        webviews[0].initialization_scripts()[0].contains("__lepusaInvoke"),
      )
      assert_eq(
        plan.runtime_manifest().bridge_url(),
        "lepusa://runtime/bridge.js",
      )
      let json = plan.manifest_json()
      assert_true(json.contains("\"nativeBackend\":\"macos\""))
      assert_true(json.contains("\"webviewEngine\":\"WKWebView\""))
      assert_true(json.contains("\"runtime\""))
      assert_true(json.contains("\"label\":\"main\""))
    }
    Err(_) => abort("unexpected invalid macOS launch plan")
  }
}

///|
test "macos backend prepares startup operations for native runner" {
  match backend().runner_plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "macos")
      assert_eq(plan.webview_engine(), "WKWebView")
      assert_eq(plan.webviews().length(), 1)
      let operations = plan.startup_operations()
      assert_eq(operations.length(), 3)
      assert_true(operations[0] is NativeDispatchEvent(_))
      guard operations[0] is NativeDispatchEvent(dispatch) else {
        fail("expected native frontend event dispatch")
      }
      assert_eq(dispatch.window_label(), "main")
      assert_true(dispatch.script().contains("__lepusaDispatchEvent"))
      assert_true(operations[1] is NativeRunEffect("boot"))
      assert_true(
        operations[2]
        is NativeNavigateWindow("main", "lepusa://inline/main/index.html"),
      )
      assert_eq(
        plan.session().windows()[0].url(),
        "lepusa://inline/main/index.html",
      )
      match plan.session().resolve_asset("lepusa://inline/main/index.html") {
        Ok(asset) =>
          assert_true(asset.body() is VirtualContent("<main>ready</main>"))
        Err(_) => abort("unexpected missing navigated macOS asset")
      }
      let json = plan.bootstrap_json()
      assert_true(json.contains("\"startupOperations\""))
      assert_true(json.contains("\"kind\":\"navigate-window\""))
      assert_true(json.contains("\"lifecycleOperations\""))
      assert_true(json.contains("\"name\":\"flush\""))
      let execution = operation_executor().execute_startup(
        plan.execution_plan(),
      )
      assert_eq(execution.operation_count(), 3)
      assert_eq(execution.executed_count(), 2)
      assert_eq(execution.skipped_count(), 1)
      assert_eq(execution.failed_count(), 0)
    }
    Err(_) => abort("unexpected invalid macOS runner plan")
  }
}

///|
test "macos backend exposes native runtime facade" {
  match runtime(test_host()) {
    Ok(runtime) => {
      assert_eq(runtime.backend().name(), "macos")
      assert_true(
        runtime.bootstrap_json().contains("\"nativeBackend\":\"macos\""),
      )
      assert_true(
        runtime
        .resolve_asset_json("lepusa://inline/main/index.html")
        .contains("\"kind\":\"virtual\""),
      )
    }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos backend prepares first webview load url" {
  match runtime(test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          let webviews = plan.webviews()
          assert_eq(webviews.length(), 1)
          let webview = webviews[0]
          assert_eq(webview.label(), "main")
          assert_eq(webview.title(), "macOS")
          assert_eq(webview.url(), "lepusa://inline/main/index.html")
          assert_eq(webview.load_url(), "lepusa://inline/main/index.html")
          assert_eq(webview.asset_protocol(), "lepusa")
          assert_true(
            webview.initialization_script().contains("webkit.messageHandlers"),
          )
          assert_true(
            webview.initialization_script().contains("__lepusaInvokeResponse"),
          )
          assert_true(webview.initialization_script().contains("windowLabel"))
          assert_true(
            webview.initialization_script().contains("__lepusaDispatchEvent"),
          )
          assert_true(webview.initialization_script().contains("ready"))
          assert_eq(webview.width(), 1000)
          assert_eq(webview.height(), 720)
          let execution = plan.execution()
          assert_eq(execution.startup_operations().length(), 3)
          assert_eq(execution.startup_operations()[1].kind(), "run-effect")
          assert_eq(
            execution.startup_operations()[1].effect_name().unwrap(),
            "boot",
          )
          let lifecycle_steps = execution.lifecycle_steps()
          assert_eq(lifecycle_steps.length(), 1)
          assert_true(
            lifecycle_steps[0]
            .event_json()
            .contains("\"kind\":\"app-will-exit\""),
          )
          assert_eq(lifecycle_steps[0].operations()[0].kind(), "run-effect")
          assert_eq(
            lifecycle_steps[0].operations()[0].effect_name().unwrap(),
            "flush",
          )
          let supervisor = plan.service_supervisor_plan()
          assert_eq(supervisor.backend_name(), "macos")
          assert_eq(supervisor.webview_engine(), "WKWebView")
          assert_false(supervisor.requires_supervisor())
          let report = plan.service_supervisor_report()
          assert_true(report.ok())
          assert_eq(report.action_count(), 0)
          assert_eq(plan.execute_service_startup().action_count(), 0)
          let shutdown = plan.execute_app_will_exit()
          assert_true(shutdown.ok())
          assert_eq(shutdown.operation_count(), 1)
          assert_eq(shutdown.skipped_count(), 1)
          let bridge = plan.bridge()
          assert_eq(bridge.sync_command_routes().length(), 0)
          assert_eq(bridge.async_command_routes().length(), 0)
          assert_false(bridge.requires_async_dispatch())
          let session = plan.launch_session_with_capability(launch_capability())
          assert_eq(session.webviews().length(), 1)
          assert_eq(session.execution().startup_operations().length(), 3)
          assert_eq(session.service_supervisor().backend_name(), "macos")
          assert_true(session.can_launch())
        }
        Err(_) => abort("unexpected invalid macOS run plan")
      }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos backend marks async bridge routes" {
  match runtime(async_bridge_test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          let bridge = plan.bridge()
          assert_eq(bridge.sync_command_routes().length(), 0)
          let async_routes = bridge.async_command_routes()
          assert_eq(async_routes.length(), 1)
          assert_eq(async_routes[0], "fs.readText")
          assert_true(bridge.requires_async_dispatch())
          let session = plan.launch_session_with_capability(launch_capability())
          assert_true(session.can_launch())
          assert_true(session.launch_blocker("macOS") is None)
          assert_true(
            plan.launch_blocker_with_capability("macOS", launch_capability())
            is None,
          )
        }
        Err(_) => abort("unexpected invalid async macOS run plan")
      }
    Err(_) => abort("unexpected invalid async macOS runtime")
  }
}

///|
test "macos open-window launch allows async bridge routes" {
  match runtime(async_bridge_test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          assert_true(plan.bridge().requires_async_dispatch())
          assert_true(
            plan.launch_blocker_with_capability("macOS", launch_capability())
            is None,
          )
        }
        Err(_) => abort("unexpected invalid async macOS run plan")
      }
    Err(_) => abort("unexpected invalid async macOS runtime")
  }
}

///|
test "macos backend preserves all webviews in run plan" {
  match runtime(multi_window_test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          let webviews = plan.webviews()
          assert_eq(webviews.length(), 2)
          assert_eq(webviews[0].label(), "main")
          assert_eq(webviews[0].title(), "Main")
          assert_eq(webviews[0].width(), 900)
          assert_eq(webviews[0].load_url(), "lepusa://inline/main/index.html")
          assert_eq(webviews[1].label(), "settings")
          assert_eq(webviews[1].title(), "Settings")
          assert_eq(webviews[1].width(), 700)
          assert_eq(webviews[1].height(), 520)
          assert_eq(webviews[1].resizable(), false)
          assert_eq(
            webviews[1].load_url(),
            "lepusa://inline/settings/index.html",
          )
          match plan.first_webview() {
            Ok(first) => assert_eq(first.label(), "main")
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid multi-window macOS run plan")
      }
    Err(_) => abort("unexpected invalid multi-window macOS runtime")
  }
}

///|
test "macos open-window launch prepares initial extra window operations" {
  match runtime(multi_window_test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          assert_true(
            plan.launch_blocker_with_capability("macOS", launch_capability())
            is None,
          )
          let packet = plan.initial_open_packet()
          assert_true(packet.contains("lepusa-ops-v3"))
          assert_true(packet.contains("open-window"))
          assert_true(packet.contains("settings"))
          assert_true(packet.contains("lepusa://inline/settings/index.html"))
          assert_true(packet.contains("Settings"))
        }
        Err(_) => abort("unexpected invalid multi-window macOS run")
      }
    Err(_) => abort("unexpected invalid multi-window macOS runtime")
  }
}

///|
test "macos backend dry run does not enter native loop" {
  match runtime(test_host()) {
    Ok(runtime) =>
      match run(runtime) {
        Ok(result) => {
          assert_true(result.status() is RunPrepared)
          match result.plan().first_webview() {
            Ok(webview) =>
              assert_eq(webview.load_url(), "lepusa://inline/main/index.html")
            Err(problem) => abort(problem)
          }
          assert_true(
            result.plan().webviews()[0]
            .initialization_script()
            .contains("__lepusaInvoke"),
          )
        }
        Err(_) => abort("unexpected invalid macOS dry run")
      }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos backend prepares bundled runtime manifest" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/Example.app/Contents/Resources/lepusa/runtime.json",
      bundled_macos_manifest(),
    ) {
    Ok(manifest) =>
      match prepare_bundled_run(manifest) {
        Ok(plan) => {
          let webviews = plan.webviews()
          assert_eq(webviews.length(), 1)
          let webview = webviews[0]
          assert_eq(webview.title(), "Bundled App")
          assert_eq(webview.url(), "lepusa://rabbita/main/index.html")
          assert_eq(webview.load_url(), "lepusa://rabbita/main/index.html")
          assert_eq(webview.asset_protocol(), "lepusa")
          assert_true(
            webview.initialization_script().contains("webkit.messageHandlers"),
          )
          assert_true(
            webview.initialization_script().contains("__lepusaInvokeResponse"),
          )
          assert_true(webview.initialization_script().contains("bridge ready"))
          assert_true(
            webview.initialization_script().contains("__lepusaDispatchEvent"),
          )
          assert_eq(webview.width(), 900)
          assert_eq(webview.height(), 640)
          assert_eq(webview.resizable(), false)
          let execution = plan.execution()
          assert_eq(execution.startup_operations().length(), 3)
          assert_eq(execution.startup_operations()[0].kind(), "start-service")
          assert_eq(
            execution.startup_operations()[0].service().unwrap().name(),
            "api",
          )
          assert_eq(execution.startup_operations()[1].kind(), "run-effect")
          assert_eq(
            execution.startup_operations()[1].effect_name().unwrap(),
            "boot",
          )
          assert_eq(execution.startup_operations()[2].kind(), "evaluate-script")
          assert_eq(
            execution.startup_operations()[2].window_label().unwrap(),
            "main",
          )
          let lifecycle_steps = execution.lifecycle_steps()
          assert_eq(lifecycle_steps.length(), 1)
          assert_true(
            lifecycle_steps[0]
            .event_json()
            .contains("\"kind\":\"app-will-exit\""),
          )
          assert_eq(lifecycle_steps[0].operations()[0].kind(), "run-effect")
          assert_eq(
            lifecycle_steps[0].operations()[0].effect_name().unwrap(),
            "flush",
          )
          let bridge = plan.bridge()
          let sync_routes = bridge.sync_command_routes()
          assert_eq(sync_routes.length(), 1)
          assert_eq(sync_routes[0], "log.write")
          let async_routes = bridge.async_command_routes()
          assert_eq(async_routes.length(), 1)
          assert_eq(async_routes[0], "fs.writeText")
          assert_true(bridge.requires_async_dispatch())
          let session = plan.launch_session_with_capability(launch_capability())
          assert_eq(session.webviews().length(), 1)
          assert_eq(session.execution().startup_operations().length(), 3)
          assert_true(session.can_launch())
          let supervisor = plan.service_supervisor_plan()
          assert_eq(supervisor.backend_name(), "macos")
          assert_eq(supervisor.webview_engine(), "WKWebView")
          assert_true(supervisor.requires_supervisor())
          assert_eq(supervisor.start_order()[0], "api")
          assert_true(supervisor.startup_actions()[0] is StartLocalService(_))
          assert_true(
            supervisor.startup_actions()[1] is WaitLocalServiceReady(_),
          )
          assert_true(supervisor.shutdown_actions()[0] is StopLocalService(_))
          let report = plan.service_supervisor_report()
          assert_eq(report.backend_name(), "macos")
          assert_true(report.ok())
          assert_eq(report.action_count(), 3)
        }
        Err(_) => abort("unexpected invalid bundled macOS plan")
      }
    Err(problem) => abort(problem)
  }
}

///|
test "macos service executor reports native service failures" {
  let service = @lepusa.LocalService::new(
    name="missing",
    command=["/definitely/not/a/lepusa/service"],
    readiness_url="not-a-url",
  )
  let plan = @runtime.NativeServiceSupervisorPlan::new(
    backend_name="macos",
    webview_engine="WKWebView",
    plan=@lepusa.LocalServiceSupervisorPlan::new(services=[service], startup_services=[
      service,
    ]),
  )
  let startup = service_executor().execute_startup(plan)
  assert_false(startup.ok())
  assert_eq(startup.action_count(), 2)
  match startup.first_failure_message(context="macOS service startup") {
    Some(message) => {
      assert_true(message.contains("macOS service startup"))
      assert_true(message.contains("start-service missing"))
      assert_true(message.contains("macOS service start failed"))
    }
    None => abort("expected macOS service startup failure message")
  }
  assert_true(
    startup.action_reports()[0].status() is NativeServiceActionFailed(message) &&
    message.contains("macOS service start failed"),
  )
  assert_true(
    startup.action_reports()[1].status() is NativeServiceActionFailed(message) &&
    message.contains("macOS service readiness failed"),
  )
  let shutdown = service_executor().execute_shutdown(plan)
  assert_true(shutdown.ok())
  assert_true(
    shutdown.action_reports()[0].status() is NativeServiceActionSkipped(message) &&
    message.contains("process is not tracked"),
  )
}

///|
test "macos bundled open-window launch allows async bridge routes" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/Example.app/Contents/Resources/lepusa/runtime.json",
      bundled_macos_manifest(),
    ) {
    Ok(manifest) =>
      match prepare_bundled_run(manifest) {
        Ok(plan) => {
          assert_true(plan.bridge().requires_async_dispatch())
          assert_true(
            plan
            .launch_session_with_capability(launch_capability())
            .can_launch(),
          )
        }
        Err(_) => abort("unexpected invalid bundled macOS run plan")
      }
    Err(problem) => abort(problem)
  }
}

///|
async test "macos bridge dispatch returns response callback script" {
  match runtime(bridge_test_host()) {
    Ok(runtime) => {
      let message = "{\"id\":\"42\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}"
      match runtime.dispatch_bridge_message(message) {
        Ok(dispatch) => {
          assert_eq(dispatch.window_label(), "main")
          assert_eq(dispatch.response_hook(), "__lepusaInvokeResponse")
          assert_eq(dispatch.message(), message)
          assert_true(dispatch.response_json().contains("\"id\":\"42\""))
          assert_true(
            dispatch
            .response_json()
            .contains("\"payload\":\"{\\\"seen\\\":true}\""),
          )
          assert_true(
            dispatch
            .evaluation_script()
            .contains("globalThis[\"__lepusaInvokeResponse\"]"),
          )
          assert_true(dispatch.evaluation_script().contains("\"id\":\"42\""))
        }
        Err(_) => abort("unexpected bridge dispatch failure")
      }
    }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
async test "macos bridge prepares async messages before dispatch" {
  match runtime(async_bridge_test_host()) {
    Ok(runtime) => {
      let message = "{\"id\":\"44\",\"window_label\":\"main\",\"plugin\":\"fs\",\"command\":\"readText\",\"payload\":\"true\"}"
      match runtime.prepare_bridge_message(message) {
        Ok(prepared) => {
          assert_eq(prepared.window_label(), "main")
          assert_eq(prepared.response_hook(), "__lepusaInvokeResponse")
          assert_eq(prepared.message(), message)
          let dispatch = prepared.dispatch(runtime)
          assert_eq(dispatch.window_label(), "main")
          assert_eq(dispatch.response_hook(), "__lepusaInvokeResponse")
          assert_true(dispatch.response_json().contains("\"id\":\"44\""))
          assert_true(
            dispatch
            .response_json()
            .contains("\"payload\":\"{\\\"read\\\":true}\""),
          )
          assert_true(
            dispatch
            .evaluation_script()
            .contains("globalThis[\"__lepusaInvokeResponse\"]"),
          )
        }
        Err(_) => abort("unexpected bridge prepare failure")
      }
    }
    Err(_) => abort("unexpected invalid async macOS native runtime")
  }
}

///|
fn bundled_macos_manifest() -> String {
  (
    #|{
    #|  "identifier": "dev.vectie.bundle",
    #|  "productName": "Bundled App",
    #|  "target": "macos",
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "macos",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Bundled App",
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "width": 900,
    #|      "height": 640,
    #|      "resizable": false,
    #|      "nativeHook": "__lepusaInvoke",
    #|      "initializationScripts": ["console.log(\"bridge ready\")"]
    #|    }],
    #|    "protocolMappings": [
    #|      { "windowLabel": "main", "scheme": "lepusa", "root": "memory:main" }
    #|    ],
    #|    "virtualFiles": [
    #|      {
    #|        "windowLabel": "main",
    #|        "path": "index.html",
    #|        "mimeType": "text/html",
    #|        "content": "<main>bundled</main>"
    #|      }
    #|    ],
    #|    "localServices": [
    #|      {
    #|        "name": "api",
    #|        "url": "http://127.0.0.1:4317/",
    #|        "readinessUrl": "http://127.0.0.1:4317/ready",
    #|        "command": ["moon", "run", "cmd/server"]
    #|      }
    #|    ],
    #|    "startupActions": [
    #|      { "kind": "effect", "name": "boot" },
    #|      {
    #|        "kind": "emit",
    #|        "target": { "kind": "window", "label": "main" },
    #|        "event": { "name": "ready", "payload": "{}" }
    #|      }
    #|    ],
    #|    "lifecycleHooks": [
    #|      {
    #|        "event": { "kind": "app-will-exit" },
    #|        "actions": [{ "kind": "effect", "name": "flush" }]
    #|      }
    #|    ],
    #|    "registeredRoutes": ["log.write", "fs.writeText"]
    #|  }
    #|}
  )
}

///|
async test "macos bridge dispatch reports missing window" {
  match runtime(bridge_test_host()) {
    Ok(runtime) => {
      let message = "{\"id\":\"43\",\"window_label\":\"other\",\"plugin\":\"core\",\"command\":\"invoke\"}"
      match runtime.dispatch_bridge_message(message) {
        Ok(_) => abort("unexpected bridge dispatch success")
        Err(problems) =>
          assert_eq(problems[0], "native bridge window not found: other")
      }
    }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}
