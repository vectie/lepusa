///|
fn test_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="main",
      title="Runtime",
      width=900,
      height=640,
      source=@lepusa.Source::html("<main>runtime</main>"),
    )
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
    .with_startup(@lepusa.Cmd::effect("boot"))
    .on_shutdown(@lepusa.Cmd::effect("flush"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime host snapshots windows protocols and bridge" {
  let host = RuntimeHost::new(test_plan())
  match host.snapshot() {
    Ok(session) => {
      assert_true(session.backend() is Headless)
      assert_eq(session.asset_protocol(), "lepusa")
      assert_eq(session.command_routes()[0], "core.invoke")
      assert_eq(session.registered_routes().length(), 0)
      assert_true(session.startup_actions()[0] is RuntimeEffect("boot"))
      assert_true(session.lifecycle_hooks()[0].event() is AppStarted)
      assert_true(session.lifecycle_hooks()[1].event() is AppWillExit)
      assert_true(session.bridge_source().contains("__lepusaInvoke"))
      let windows = session.windows()
      assert_eq(windows.length(), 1)
      assert_eq(windows[0].title(), "Runtime")
      assert_eq(windows[0].width(), 900)
      assert_eq(windows[0].height(), 640)
      assert_eq(windows[0].url(), "lepusa://inline/main/index.html")
      let mappings = session.protocol_mappings()
      assert_eq(mappings.length(), 1)
      assert_eq(mappings[0].window_label(), "main")
      assert_eq(mappings[0].scheme(), "lepusa")
      let files = session.virtual_files()
      assert_eq(files.length(), 1)
      assert_eq(files[0].path(), "index.html")
      assert_eq(files[0].content(), "<main>runtime</main>")
    }
    Err(_) => abort("unexpected invalid runtime session")
  }
}

///|
test "runtime host carries localhost service metadata" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    label="gateway",
    source=@lepusa.Source::localhost(
      port=4317,
      path="/",
      readiness_path="/ready",
      command=["moon", "run", "cmd/server"],
    ),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => {
      let host = RuntimeHost::new(plan)
      match host.snapshot() {
        Ok(session) => {
          assert_eq(session.windows()[0].url(), "http://127.0.0.1:4317/")
          let services = session.local_services()
          assert_eq(services.length(), 1)
          assert_eq(services[0].name(), "gateway")
          assert_eq(services[0].readiness_url(), "http://127.0.0.1:4317/ready")
        }
        Err(_) => abort("unexpected invalid runtime session")
      }
      match host.launch_manifest() {
        Ok(manifest) => {
          assert_eq(manifest.local_services().length(), 1)
          assert_true(manifest.to_json().contains("\"localServices\""))
          assert_true(manifest.to_json().contains("\"cmd/server\""))
        }
        Err(_) => abort("unexpected invalid launch manifest")
      }
      match host.runner_plan() {
        Ok(runner) => {
          let operations = runner.startup_operations()
          assert_eq(operations.length(), 1)
          assert_true(operations[0] is RuntimeStartService(_))
        }
        Err(_) => abort("unexpected invalid runner plan")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "native backend lowers host runner plan with portable operations" {
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match backend.runner_plan(RuntimeHost::new(test_plan())) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "test")
      assert_eq(plan.webview_engine(), "SystemWebView")
      assert_eq(plan.webviews().length(), 1)
      assert_eq(plan.webview_specs().length(), 1)
      assert_eq(plan.webview_specs()[0].native_hook(), "__lepusaInvoke")
      assert_true(plan.startup_operations()[0] is NativeRunEffect("boot"))
      assert_eq(plan.lifecycle_steps().length(), 1)
      assert_true(plan.lifecycle_steps()[0].event() is AppWillExit)
      match plan.lifecycle_step(AppWillExit) {
        Ok(step) => {
          let step_json = step.to_json()
          assert_true(step.event() is AppWillExit)
          assert_true(step.operations()[0] is NativeRunEffect("flush"))
          assert_true(step_json.has_prefix("{\"event\":"))
          assert_false(
            step_json.contains(
              "\"event\":{\"kind\":\"app-will-exit\"},\"event\"",
            ),
          )
          assert_true(step_json.contains("\"kind\":\"app-will-exit\""))
          assert_true(step_json.contains("\"name\":\"flush\""))
          assert_true(step_json.contains("\"session\""))
          assert_true(step_json.contains("\"bridgeSource\""))
        }
        Err(_) => abort("unexpected invalid native lifecycle step")
      }
      let json = plan.bootstrap_json()
      assert_true(json.contains("\"nativeBackend\":\"test\""))
      assert_true(json.contains("\"webviewSpecs\""))
      assert_true(json.contains("\"nativeHook\":\"__lepusaInvoke\""))
      assert_true(json.contains("\"startupOperations\""))
      assert_true(json.contains("\"lifecycleOperations\""))
      assert_true(json.contains("\"kind\":\"app-will-exit\""))
      assert_true(json.contains("\"session\""))
    }
    Err(_) => abort("unexpected invalid native runner plan")
  }
}

///|
test "native runner exposes executable operation views" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="main",
      source=@lepusa.Source::localhost(port=4317, readiness_path="/ready", command=[
        "moon", "run", "cmd/server",
      ]),
    )
    .with_startup(
      @lepusa.Cmd::batch([
        @lepusa.Cmd::emit(
          @lepusa.Event::new("ready", payload="{\"ok\":true}"),
          target=WindowTarget("main"),
        ),
        @lepusa.Cmd::effect("boot"),
        @lepusa.Cmd::navigate(
          "main",
          @lepusa.Source::html("<main>after</main>"),
        ),
      ]),
    )
    .on_window_close_requested(
      "main",
      @lepusa.Cmd::emit(@lepusa.Event::new("closing")),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => {
      let backend = NativeBackend::new(
        name="test",
        webview_engine="SystemWebView",
      )
      match backend.runner_plan(RuntimeHost::new(plan)) {
        Ok(runner) => {
          let startup = runner.startup_operations()
          assert_eq(startup.length(), 4)
          assert_eq(startup[0].kind(), "start-service")
          assert_eq(startup[0].service().unwrap().name(), "main")
          assert_eq(startup[1].kind(), "evaluate-script")
          assert_eq(startup[1].window_label().unwrap(), "main")
          assert_true(
            startup[1]
            .evaluation_script()
            .unwrap()
            .script()
            .contains("__lepusaDispatchEvent"),
          )
          assert_eq(startup[2].kind(), "run-effect")
          assert_eq(startup[2].effect_name().unwrap(), "boot")
          assert_eq(startup[3].kind(), "navigate-window")
          assert_eq(startup[3].navigation().unwrap().window_label(), "main")
          assert_eq(
            startup[3].navigation().unwrap().url(),
            "lepusa://inline/main/index.html",
          )
          let executable = runner.startup_executable_operations()
          assert_eq(executable.length(), 4)
          assert_eq(executable[0].kind(), "start-service")
          assert_eq(
            executable[0].service().unwrap().readiness_url(),
            "http://127.0.0.1:4317/ready",
          )
          assert_eq(executable[1].kind(), "evaluate-script")
          assert_eq(executable[1].window_label().unwrap(), "main")
          assert_true(executable[1].to_json().contains("\"script\""))
          assert_eq(executable[2].kind(), "run-effect")
          assert_eq(executable[2].effect_name().unwrap(), "boot")
          assert_eq(executable[3].kind(), "navigate-window")
          assert_eq(
            executable[3].navigation().unwrap().url(),
            "lepusa://inline/main/index.html",
          )
          let execution = runner.execution_plan()
          assert_eq(execution.startup_operations().length(), 4)
          assert_eq(execution.startup_operations()[0].kind(), "start-service")
          assert_eq(execution.startup_operations()[3].kind(), "navigate-window")
          assert_true(
            execution.startup_operation_jsons()[1].contains(
              "\"kind\":\"evaluate-script\"",
            ),
          )
          let scripts = runner.startup_evaluation_scripts()
          assert_eq(scripts.length(), 1)
          assert_eq(scripts[0].window_label(), "main")
          assert_true(scripts[0].to_json().contains("\"script\""))
          let navigations = runner.startup_navigations()
          assert_eq(navigations.length(), 1)
          assert_eq(navigations[0].window_label(), "main")
          assert_true(navigations[0].to_json().contains("\"url\""))
          match runner.lifecycle_step(WindowCloseRequested("main")) {
            Ok(step) => {
              let lifecycle_executable = step.executable_operations()
              assert_eq(lifecycle_executable.length(), 1)
              assert_eq(lifecycle_executable[0].kind(), "evaluate-script")
              let lifecycle_steps = execution.lifecycle_steps()
              assert_eq(lifecycle_steps.length(), 1)
              assert_true(
                lifecycle_steps[0]
                .event_json()
                .contains("\"kind\":\"window-close-requested\""),
              )
              assert_eq(
                lifecycle_steps[0].operations()[0].kind(),
                "evaluate-script",
              )
              let lifecycle_scripts = step.evaluation_scripts()
              assert_eq(lifecycle_scripts.length(), 1)
              assert_true(lifecycle_scripts[0].script().contains("closing"))
              assert_eq(step.navigations().length(), 0)
            }
            Err(_) => abort("unexpected invalid native lifecycle step")
          }
        }
        Err(_) => abort("unexpected invalid native runner plan")
      }
    }
    Err(_) => abort("unexpected invalid native executable operation plan")
  }
}

///|
test "native runtime facade exposes platform loop hooks" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  let host = RuntimeHost::new(test_plan(), registry~)
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, host) {
    Ok(runtime) => {
      let bootstrap = runtime.bootstrap_json()
      assert_true(runtime.backend().name() == "test")
      assert_true(bootstrap.contains("\"nativeBackend\":\"test\""))
      assert_true(bootstrap.contains("\"startupOperations\""))
      assert_true(bootstrap.contains("\"webviewSpecs\""))
      let asset = runtime.resolve_asset_json("lepusa://inline/main/index.html")
      assert_true(asset.contains("\"ok\":true"))
      assert_true(asset.contains("\"kind\":\"virtual\""))
      let dispatch = runtime.dispatch_json(
        "{\"id\":\"1\",\"windowLabel\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"ok\"}",
      )
      assert_true(dispatch.contains("\"payload\":\"ok\""))
      match runtime.lifecycle_step_json(AppWillExit) {
        Ok(step) => {
          assert_true(step.has_prefix("{\"event\":"))
          assert_false(
            step.contains("\"event\":{\"kind\":\"app-will-exit\"},\"event\""),
          )
          assert_true(step.contains("\"kind\":\"app-will-exit\""))
          assert_true(step.contains("\"name\":\"flush\""))
        }
        Err(_) => abort("unexpected invalid native runtime lifecycle step")
      }
    }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "native asset protocol packet encodes runtime responses" {
  match RuntimeHost::new(test_plan()).snapshot() {
    Ok(session) =>
      match session.resolve_asset("lepusa://inline/main/index.html") {
        Ok(asset) => {
          let packet = @utf8.decode(asset.to_native_protocol_packet()) catch {
            _ => abort("unexpected invalid virtual packet")
          }
          assert_eq(packet, "ok\nvirtual\ntext/html\n<main>runtime</main>")
        }
        Err(problem) => abort(problem)
      }
    Err(_) => abort("unexpected invalid runtime session")
  }
}

///|
test "native runtime owns bridge and asset callbacks" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, RuntimeHost::new(test_plan(), registry~)) {
    Ok(runtime) => {
      let dispatch = runtime.bridge_dispatch_callback()
      let message = "{\"id\":\"1\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}"
      let script = @utf8.decode(dispatch(@utf8.encode(message))) catch {
        _ => abort("unexpected invalid callback response")
      }
      assert_true(script.contains("__lepusaInvokeResponse"))
      assert_true(script.contains("\"id\":\"1\""))
      assert_true(script.contains("\"payload\":\"true\""))
      let resolve_asset = runtime.asset_protocol_resolver_callback()
      let packet = @utf8.decode(
        resolve_asset(@utf8.encode("lepusa://inline/main/index.html")),
      ) catch {
        _ => abort("unexpected invalid asset callback response")
      }
      assert_eq(packet, "ok\nvirtual\ntext/html\n<main>runtime</main>")
    }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "native asset protocol packet encodes json envelopes" {
  let virtual_json =
    #|{
    #|  "ok": true,
    #|  "url": "lepusa://runtime/bridge.js",
    #|  "mimeType": "application/javascript",
    #|  "body": { "kind": "virtual", "content": "console.log(\"ready\")" }
    #|}
  let virtual_packet = @utf8.decode(
    native_asset_protocol_packet_from_json(virtual_json),
  ) catch {
    _ => abort("unexpected invalid virtual packet")
  }
  assert_true(
    virtual_packet.has_prefix("ok\nvirtual\napplication/javascript\n"),
  )
  assert_true(virtual_packet.contains("console.log"))
  let file_json =
    #|{
    #|  "ok": true,
    #|  "url": "lepusa://packaged/main/app.css",
    #|  "mimeType": "text/css",
    #|  "body": { "kind": "packaged-file", "path": "/tmp/app.css" }
    #|}
  let file_packet = @utf8.decode(
    native_asset_protocol_packet_from_json(file_json),
  ) catch {
    _ => abort("unexpected invalid file packet")
  }
  assert_eq(file_packet, "ok\nfile\ntext/css\n/tmp/app.css")
  let error_packet = @utf8.decode(
    native_asset_protocol_packet_from_json(
      "{\"ok\":false,\"error\":\"missing\"}",
    ),
  ) catch {
    _ => abort("unexpected invalid error packet")
  }
  assert_eq(error_packet, "error\nmissing")
}

///|
test "native asset load urls are runtime-owned" {
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, RuntimeHost::new(test_plan())) {
    Ok(runtime) =>
      match runtime.initial_load_url(runtime.runner_plan().webview_specs()[0]) {
        Ok(load_url) => assert_eq(load_url, "lepusa://inline/main/index.html")
        Err(problem) => abort(problem)
      }
    Err(_) => abort("unexpected invalid native runtime")
  }
  match RuntimeHost::new(test_plan()).snapshot() {
    Ok(session) =>
      match session.resolve_asset("lepusa://inline/main/index.html") {
        Ok(asset) => {
          let load_url = asset.to_native_load_url()
          assert_true(load_url.has_prefix("data:text/html;base64,"))
          assert_false(load_url.contains("<main>runtime</main>"))
        }
        Err(problem) => abort(problem)
      }
    Err(_) => abort("unexpected invalid runtime session")
  }
  assert_true(native_direct_load_url("https://example.test/app"))
  assert_true(
    native_protocol_load_url("lepusa://inline/main/index.html", "lepusa"),
  )
  assert_false(native_protocol_load_url("https://example.test/app", "lepusa"))
}

///|
test "native runtime prepares shared webview plans" {
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, RuntimeHost::new(test_plan())) {
    Ok(runtime) =>
      match
        runtime.webview_plan(
          runtime.runner_plan().webview_specs()[0],
          initialization_script="/* native hook */",
        ) {
        Ok(webview) => {
          assert_eq(webview.label(), "main")
          assert_eq(webview.title(), "Runtime")
          assert_eq(webview.url(), "lepusa://inline/main/index.html")
          assert_eq(webview.load_url(), "lepusa://inline/main/index.html")
          assert_eq(webview.initialization_script(), "/* native hook */")
          assert_eq(webview.asset_protocol(), "lepusa")
          assert_eq(webview.width(), 900)
          assert_eq(webview.height(), 640)
          assert_true(webview.resizable())
        }
        Err(problem) => abort(problem)
      }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "native webview launch packet owns abi lowering" {
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, RuntimeHost::new(test_plan())) {
    Ok(runtime) =>
      match
        runtime.webview_plan(
          runtime.runner_plan().webview_specs()[0],
          initialization_script="/* native hook */",
        ) {
        Ok(webview) => {
          let packet = webview.launch_packet()
          let title = @utf8.decode(packet.title()) catch {
            _ => abort("unexpected invalid packet title")
          }
          let load_url = @utf8.decode(packet.load_url()) catch {
            _ => abort("unexpected invalid packet url")
          }
          let native_hook = @utf8.decode(packet.native_hook()) catch {
            _ => abort("unexpected invalid packet hook")
          }
          assert_eq(title, "Runtime")
          assert_eq(load_url, "lepusa://inline/main/index.html")
          assert_eq(native_hook, "__lepusaInvoke")
          assert_eq(packet.width(), 900)
          assert_eq(packet.height(), 640)
          assert_eq(packet.resizable(), 1)
        }
        Err(problem) => abort(problem)
      }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "native runtime prepares shared run plans" {
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, RuntimeHost::new(test_plan())) {
    Ok(runtime) =>
      match
        runtime.prepare_run_plan(prepare_webview=fn(spec) {
          runtime.webview_plan(
            spec,
            initialization_script="/* prepared hook */",
          )
        }) {
        Ok(plan) => {
          assert_eq(plan.webview_count(), 1)
          assert_eq(plan.first_webview_url(), "lepusa://inline/main/index.html")
          assert_eq(
            plan.first_webview_load_url(),
            "lepusa://inline/main/index.html",
          )
          assert_eq(plan.startup_operation_count(), 1)
          assert_eq(plan.lifecycle_step_count(), 1)
          assert_eq(plan.bridge_sync_routes().length(), 0)
          assert_eq(plan.bridge_async_routes().length(), 0)
          assert_false(plan.requires_async_bridge_dispatch())
          assert_eq(plan.service_supervisor_plan().backend_name(), "test")
          assert_true(plan.service_supervisor_report().ok())
          match plan.first_webview() {
            Ok(webview) =>
              assert_eq(webview.initialization_script(), "/* prepared hook */")
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid native prepared run plan")
      }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "native runner plans expose async bridge blockers" {
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  let registry = @lepusa.CommandRegistry::new().register_async_fn(
    "core.invoke",
    handler=fn(payload) { Ok(payload) },
  )
  match
    NativeRuntime::new(
      backend,
      RuntimeHost::new(async_bridge_plan(), registry~),
    ) {
    Ok(runtime) => {
      let runner = runtime.runner_plan()
      assert_true(runner.requires_async_bridge_dispatch())
      assert_eq(runner.bridge_sync_routes().length(), 0)
      assert_eq(runner.bridge_async_routes().length(), 1)
      assert_eq(runner.bridge_async_routes()[0], "core.invoke")
      assert_true(runner.bootstrap_json().contains("\"bridgeRoutes\""))
      match
        runtime.prepare_run_plan(prepare_webview=fn(spec) {
          runtime.webview_plan(spec, initialization_script="")
        }) {
        Ok(plan) => {
          assert_true(plan.requires_async_bridge_dispatch())
          assert_eq(plan.bridge_async_routes()[0], "core.invoke")
          assert_true(
            plan
            .async_bridge_launch_message("Test")
            .contains("1 async command route"),
          )
        }
        Err(_) => abort("unexpected invalid async native prepared run plan")
      }
    }
    Err(_) => abort("unexpected invalid async native runtime")
  }
}

///|
test "native asset load urls decode json envelopes" {
  let virtual_json =
    #|{
    #|  "ok": true,
    #|  "url": "lepusa://inline/main/index.html",
    #|  "mimeType": "text/html",
    #|  "body": { "kind": "virtual", "content": "<main>runtime</main>" }
    #|}
  match native_asset_load_url_from_json(virtual_json) {
    Ok(load_url) => {
      assert_true(load_url.has_prefix("data:text/html;base64,"))
      assert_false(load_url.contains("<main>runtime</main>"))
    }
    Err(problem) => abort(problem)
  }
  let file_json =
    #|{
    #|  "ok": true,
    #|  "url": "lepusa://packaged/main/app.css",
    #|  "mimeType": "text/css",
    #|  "body": { "kind": "packaged-file", "path": "/tmp/app.css" }
    #|}
  match native_asset_load_url_from_json(file_json) {
    Ok(load_url) => assert_eq(load_url, "file:///tmp/app.css")
    Err(problem) => abort(problem)
  }
  match
    native_asset_load_url_from_json("{\"ok\":false,\"error\":\"missing\"}") {
    Err(problem) => assert_eq(problem, "missing")
    Ok(_) => abort("expected asset load url failure")
  }
}

///|
test "native run report normalizes launch summaries" {
  let host = RuntimeHost::new(test_plan())
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, host) {
    Ok(runtime) => {
      let report = runtime.run_report(
        target="test",
        status=RunUnsupported("not wired"),
        load_url="file:///tmp/index.html",
        bridge_sync_routes=1,
        bridge_async_routes=2,
      )
      assert_eq(report.target(), "test")
      assert_eq(report.backend(), "test")
      assert_eq(report.engine(), "SystemWebView")
      assert_eq(report.status().name(), "unsupported")
      assert_eq(report.status().message(), "not wired")
      assert_eq(report.webviews(), 1)
      assert_eq(report.first_window_title(), "Runtime")
      assert_eq(report.first_window_url(), "lepusa://inline/main/index.html")
      assert_eq(report.load_url(), "file:///tmp/index.html")
      assert_eq(report.bridge_url(), "lepusa://runtime/bridge.js")
      assert_eq(report.startup_operations(), 1)
      assert_eq(report.lifecycle_steps(), 1)
      assert_eq(report.bridge_sync_routes(), 1)
      assert_eq(report.bridge_async_routes(), 2)
      let json = report.to_json()
      assert_true(json.contains("\"target\":\"test\""))
      assert_true(json.contains("\"name\":\"unsupported\""))
      assert_true(json.contains("\"message\":\"not wired\""))
      assert_true(json.contains("\"bridgeAsyncRoutes\":2"))
    }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "runtime host carries filesystem scope metadata" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let manifest = @lepusa.ProjectManifest::new(
      @lepusa.AppMetadata::new(
        identifier="dev.vectie.runtime-scopes",
        product_name="Runtime Scopes",
        version="0.1.0",
      ),
      runtime=@lepusa.RuntimeConfig::headless(),
    )
    .with_window(
      @lepusa.WindowConfig::new(source=@lepusa.Source::html("<main></main>")),
    )
    .with_file_system_scope(
      @lepusa.FileSystemScope::new(name="config", root="/app/config"),
    )
  match manifest.runtime_plan(root) {
    Ok(plan) => {
      let host = RuntimeHost::new(plan)
      match host.snapshot() {
        Ok(session) => {
          assert_eq(session.file_system_scopes().length(), 1)
          assert_eq(session.file_system_scopes()[0].name(), "config")
        }
        Err(_) => abort("unexpected invalid runtime session")
      }
      match host.launch_manifest() {
        Ok(manifest) => {
          assert_eq(manifest.file_system_scopes().length(), 1)
          assert_true(manifest.to_json().contains("\"filesystemScopes\""))
          assert_true(manifest.to_json().contains("\"name\":\"config\""))
        }
        Err(_) => abort("unexpected invalid launch manifest")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime host produces per-window webview boot specs" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="main",
      title="Main",
      width=900,
      height=640,
      source=@lepusa.Source::html("<main></main>"),
    )
    .window(
      label="settings",
      title="Settings",
      width=700,
      height=520,
      resizable=false,
      source=@lepusa.Source::html("<section></section>"),
    )
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(
      @lepusa.Capability::new("main-core").window("main").command("core.invoke"),
    )
    .with_capability(
      @lepusa.Capability::new("settings-core")
      .window("settings")
      .command("core.invoke"),
    )
  match
    app.runtime_plan(
      config=@lepusa.RuntimeConfig::system_webview(devtools=true),
    ) {
    Ok(plan) =>
      match RuntimeHost::new(plan).webviews() {
        Ok(specs) => {
          assert_eq(specs.length(), 2)
          assert_eq(specs[0].label(), "main")
          assert_eq(specs[0].title(), "Main")
          assert_eq(specs[0].url(), "lepusa://inline/main/index.html")
          assert_true(specs[0].devtools())
          assert_eq(specs[0].asset_protocol(), "lepusa")
          assert_eq(specs[0].native_hook(), "__lepusaInvoke")
          assert_eq(specs[0].event_dispatch_hook(), "__lepusaDispatchEvent")
          assert_eq(specs[0].allowed_routes()[0], "core.invoke")
          assert_eq(specs[0].initialization_scripts().length(), 1)
          assert_true(
            specs[0].initialization_scripts()[0].contains(
              "const windowLabel = \"main\";",
            ),
          )
          assert_eq(specs[1].label(), "settings")
          assert_eq(specs[1].width(), 700)
          assert_eq(specs[1].height(), 520)
          assert_eq(specs[1].resizable(), false)
          assert_eq(specs[1].allowed_routes()[0], "core.invoke")
          assert_true(
            specs[1].initialization_scripts()[0].contains(
              "const windowLabel = \"settings\";",
            ),
          )
        }
        Err(_) => abort("unexpected invalid webview specs")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime host serializes native launch manifest" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  let host = RuntimeHost::new(test_plan(), registry~)
  match host.launch_manifest() {
    Ok(manifest) => {
      assert_eq(manifest.backend(), "headless")
      assert_eq(manifest.asset_protocol(), "lepusa")
      assert_eq(manifest.bridge_url(), "lepusa://runtime/bridge.js")
      assert_eq(manifest.webviews().length(), 1)
      assert_eq(manifest.protocol_mappings().length(), 1)
      assert_eq(manifest.virtual_files().length(), 1)
      assert_eq(manifest.virtual_files()[0].mime_type(), "text/html")
      assert_eq(manifest.virtual_files()[0].content(), "<main>runtime</main>")
      assert_true(manifest.startup_actions()[0] is RuntimeEffect("boot"))
      assert_true(manifest.lifecycle_hooks()[0].event() is AppStarted)
      assert_true(manifest.lifecycle_hooks()[1].event() is AppWillExit)
      assert_eq(manifest.command_routes()[0], "core.invoke")
      assert_eq(manifest.registered_routes()[0], "core.invoke")
      let json = manifest.to_json()
      assert_true(json.contains("\"bridgeUrl\":\"lepusa://runtime/bridge.js\""))
      assert_true(json.contains("\"virtualFiles\""))
      assert_true(json.contains("\"titleBar\":\"native\""))
      assert_true(json.contains("\"nativeHook\":\"__lepusaInvoke\""))
      assert_true(
        json.contains("\"eventDispatchHook\":\"__lepusaDispatchEvent\""),
      )
      assert_true(json.contains("\"lifecycleHooks\""))
      assert_true(json.contains("\"kind\":\"app-will-exit\""))
      assert_true(json.contains("\"registeredRoutes\":[\"core.invoke\"]"))
    }
    Err(_) => abort("unexpected invalid runtime launch manifest")
  }
}

///|
test "runtime session resolves virtual runtime and window assets" {
  let host = RuntimeHost::new(test_plan())
  match host.snapshot() {
    Ok(session) => {
      match session.resolve_asset("lepusa://runtime/bridge.js") {
        Ok(response) => {
          assert_eq(response.mime_type(), "application/javascript")
          assert_true(response.body() is VirtualContent(_))
          guard response.body() is VirtualContent(content) else {
            fail("expected virtual bridge")
          }
          assert_true(content.contains("__lepusaInvoke"))
        }
        Err(_) => abort("unexpected missing bridge asset")
      }
      match session.resolve_asset("lepusa://inline/main/index.html") {
        Ok(response) => {
          assert_eq(response.mime_type(), "text/html")
          assert_true(response.body() is VirtualContent("<main>runtime</main>"))
        }
        Err(_) => abort("unexpected missing inline asset")
      }
      match session.resolve_asset("lepusa://inline/main/index.html?v=1#app") {
        Ok(response) => assert_eq(response.mime_type(), "text/html")
        Err(_) => abort("unexpected missing inline asset with suffix")
      }
      let bridge_json = session.resolve_asset_json("lepusa://runtime/bridge.js")
      assert_true(bridge_json.contains("\"ok\":true"))
      assert_true(bridge_json.contains("\"kind\":\"virtual\""))
      assert_true(
        bridge_json.contains("\"mimeType\":\"application/javascript\""),
      )
      let missing_json = session.resolve_asset_json(
        "lepusa://inline/main/missing.js",
      )
      assert_true(missing_json.contains("\"ok\":false"))
      assert_true(
        missing_json.contains(
          "\"error\":\"virtual asset not found: main/missing.js\"",
        ),
      )
    }
    Err(_) => abort("unexpected invalid runtime session")
  }
}

///|
test "runtime session maps local assets without allowing traversal" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(source=@lepusa.Source::local_path("dist"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match RuntimeHost::new(plan).snapshot() {
        Ok(session) => {
          match session.resolve_asset("lepusa://local/main/app.css") {
            Ok(response) => {
              assert_eq(response.mime_type(), "text/css")
              assert_true(response.body() is LocalFile("dist/app.css"))
            }
            Err(_) => abort("unexpected local asset mapping failure")
          }
          match session.resolve_asset("lepusa://local/main/../secret.txt") {
            Ok(_) => abort("unexpected unsafe asset success")
            Err(problem) =>
              assert_eq(problem, "unsafe asset path: ../secret.txt")
          }
          let local_json = session.resolve_asset_json(
            "lepusa://local/main/app.css",
          )
          assert_true(local_json.contains("\"kind\":\"local-file\""))
          assert_true(local_json.contains("\"path\":\"dist/app.css\""))
          let host_json = RuntimeHost::new(plan).resolve_asset_json(
            "lepusa://local/main/app.css",
          )
          assert_true(host_json.contains("\"ok\":true"))
          assert_true(host_json.contains("\"mimeType\":\"text/css\""))
        }
        Err(_) => abort("unexpected invalid runtime session")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime session maps packaged assets distinctly" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    label="ui",
    source=@lepusa.Source::packaged("dist"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match RuntimeHost::new(plan).snapshot() {
        Ok(session) => {
          assert_eq(
            session.windows()[0].url(),
            "lepusa://packaged/ui/index.html",
          )
          match session.resolve_asset("lepusa://packaged/ui/app.css") {
            Ok(response) => {
              assert_eq(response.mime_type(), "text/css")
              assert_true(response.body() is PackagedFile("dist/app.css"))
            }
            Err(_) => abort("unexpected packaged asset mapping failure")
          }
          let packaged_json = session.resolve_asset_json(
            "lepusa://packaged/ui/app.css",
          )
          assert_true(packaged_json.contains("\"kind\":\"packaged-file\""))
          assert_true(packaged_json.contains("\"path\":\"dist/app.css\""))
          match session.resolve_asset("lepusa://packaged/ui/../secret.txt") {
            Ok(_) => abort("unexpected unsafe packaged asset success")
            Err(problem) =>
              assert_eq(problem, "unsafe asset path: ../secret.txt")
          }
        }
        Err(_) => abort("unexpected invalid runtime session")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime host dispatches through plan capabilities" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
    payload,
  ) {
    Ok("ok:\{payload}")
  })
  let host = RuntimeHost::new(test_plan(), registry~)
  let allowed = host.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="core",
      command="invoke",
      payload="payload",
    ),
  )
  assert_true(allowed is InvokeOk("1", "ok:payload"))
  let denied = host.dispatch(
    @lepusa.InvokeRequest::new(
      id="2",
      window_label="other",
      plugin="core",
      command="invoke",
    ),
  )
  assert_true(denied is InvokeError("2", "permission denied: core.invoke"))
  let undeclared = host.dispatch(
    @lepusa.InvokeRequest::new(
      id="3",
      window_label="main",
      plugin="core",
      command="missing",
    ),
  )
  assert_true(undeclared is InvokeError("3", "unknown command: core.missing"))
}

///|
test "runtime host dispatch uses plan command permissions" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("fs").command_sync("read", permission=FileSystemRead),
    )
    .with_capability(
      @lepusa.Capability::new("main-files")
      .window("main")
      .permission(FileSystemRead),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let registry = @lepusa.CommandRegistry::new().register_fn("fs.read", handler=fn(
        payload,
      ) {
        Ok("file:\{payload}")
      })
      let host = RuntimeHost::new(plan, registry~)
      let allowed = host.dispatch(
        @lepusa.InvokeRequest::new(
          id="1",
          window_label="main",
          plugin="fs",
          command="read",
          payload="/tmp/a.txt",
        ),
      )
      assert_true(allowed is InvokeOk("1", "file:/tmp/a.txt"))
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime session applies startup actions as backend operations" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main>before</main>"))
    .with_startup(
      @lepusa.Cmd::batch([
        @lepusa.Cmd::emit(
          @lepusa.Event::new("ready", payload="{}"),
          target=WindowTarget("main"),
        ),
        @lepusa.Cmd::effect("boot"),
        @lepusa.Cmd::navigate(
          "main",
          @lepusa.Source::html("<main>after</main>"),
        ),
      ]),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match RuntimeHost::new(plan).startup_step() {
        Ok(step) => {
          let operations = step.operations()
          assert_eq(operations.length(), 3)
          assert_true(operations[0] is RuntimeDispatchEvent(_))
          guard operations[0] is RuntimeDispatchEvent(dispatch) else {
            fail("expected frontend event dispatch")
          }
          assert_eq(dispatch.window_label(), "main")
          assert_true(dispatch.script().contains("__lepusaDispatchEvent"))
          assert_true(operations[1] is RuntimeRunEffect("boot"))
          assert_true(
            operations[2]
            is RuntimeNavigateWindow("main", "lepusa://inline/main/index.html"),
          )
          match
            step.session().resolve_asset("lepusa://inline/main/index.html") {
            Ok(asset) =>
              assert_true(asset.body() is VirtualContent("<main>after</main>"))
            Err(_) => abort("unexpected missing navigated asset")
          }
        }
        Err(_) => abort("unexpected invalid startup step")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime session applies lifecycle hooks without host state" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main>before</main>"))
    .on_window_close_requested(
      "main",
      @lepusa.Cmd::batch([
        @lepusa.Cmd::effect("persist"),
        @lepusa.Cmd::navigate(
          "main",
          @lepusa.Source::html("<main>closing</main>"),
        ),
      ]),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match RuntimeHost::new(plan).snapshot() {
        Ok(session) =>
          match session.lifecycle_step(WindowCloseRequested("main")) {
            Ok(step) => {
              assert_eq(step.operations().length(), 2)
              assert_true(step.operations()[0] is RuntimeRunEffect("persist"))
              assert_true(
                step.operations()[1]
                is RuntimeNavigateWindow(
                  "main",
                  "lepusa://inline/main/index.html"
                ),
              )
              match
                step.session().resolve_asset("lepusa://inline/main/index.html") {
                Ok(asset) =>
                  assert_true(
                    asset.body() is VirtualContent("<main>closing</main>"),
                  )
                Err(_) => abort("unexpected missing lifecycle asset")
              }
            }
            Err(_) => abort("unexpected invalid lifecycle step")
          }
        Err(_) => abort("unexpected invalid runtime session")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime host builds generic runner plan" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  let host = RuntimeHost::new(test_plan(), registry~)
  match host.runner_plan() {
    Ok(plan) => {
      assert_eq(plan.launch_manifest().registered_routes()[0], "core.invoke")
      assert_eq(plan.webviews().length(), 1)
      assert_eq(plan.webviews()[0].url(), "lepusa://inline/main/index.html")
      assert_eq(
        plan.session().windows()[0].url(),
        "lepusa://inline/main/index.html",
      )
      assert_eq(plan.startup_operations().length(), 1)
      assert_true(plan.startup_operations()[0] is RuntimeRunEffect("boot"))
      assert_eq(plan.lifecycle_steps().length(), 1)
      assert_true(plan.lifecycle_steps()[0].event() is AppWillExit)
      assert_true(
        plan.lifecycle_steps()[0].operations()[0] is RuntimeRunEffect("flush"),
      )
      assert_true(
        plan.lifecycle_step(AppStarted).operations()[0]
        is RuntimeRunEffect("boot"),
      )
      assert_true(
        plan
        .lifecycle_step(AppWillExit)
        .to_json()
        .contains("\"kind\":\"app-will-exit\""),
      )
      assert_true(
        plan.lifecycle_steps()[0]
        .session()
        .to_json()
        .contains("\"assetProtocol\":\"lepusa\""),
      )
    }
    Err(_) => abort("unexpected invalid runner plan")
  }
}

///|
test "runtime runner starts services before app startup actions" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="gateway",
      source=@lepusa.Source::localhost(port=4317, command=[
        "moon", "run", "cmd/server",
      ]),
    )
    .with_startup(@lepusa.Cmd::effect("boot"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) =>
      match RuntimeHost::new(plan).runner_plan() {
        Ok(runner) => {
          let operations = runner.startup_operations()
          assert_eq(operations.length(), 2)
          assert_true(operations[0] is RuntimeStartService(_))
          assert_true(operations[1] is RuntimeRunEffect("boot"))
          let services = runner.service_plan()
          assert_eq(services.services().length(), 1)
          assert_eq(services.service_names()[0], "gateway")
          assert_eq(services.startup_services().length(), 1)
          assert_eq(services.startup_service_names()[0], "gateway")
          assert_true(services.requires_supervisor())
          assert_true(
            services.to_json().contains("\"startOrder\":[\"gateway\"]"),
          )
          assert_eq(runner.lifecycle_steps().length(), 0)
        }
        Err(_) => abort("unexpected invalid runner plan")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime host builds dev plan for backend runners" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main>dev</main>"))
    .with_startup(@lepusa.Cmd::effect("boot"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) =>
      match RuntimeHost::new(plan).dev_plan() {
        Ok(dev) => {
          assert_eq(dev.webviews().length(), 1)
          assert_eq(dev.webviews()[0].url(), "lepusa://inline/main/index.html")
          assert_eq(
            dev.session().windows()[0].url(),
            "lepusa://inline/main/index.html",
          )
          assert_eq(dev.startup_operations().length(), 1)
          assert_true(dev.startup_operations()[0] is RuntimeRunEffect("boot"))
          let services = dev.service_plan()
          assert_eq(services.services().length(), 0)
          assert_false(services.requires_supervisor())
        }
        Err(_) => abort("unexpected invalid dev plan")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime service plan validates startup service declarations" {
  let service = @lepusa.LocalService::new(
    name="api",
    command=["moon", "run", "cmd/server"],
    readiness_url="http://127.0.0.1:4317/ready",
  )
  let plan = RuntimeServicePlan::new(startup_services=[service])
  let problems = plan.validate()
  assert_eq(problems.length(), 1)
  assert_eq(problems[0], "startup service is not declared: api")
}

///|
test "runtime service plan exposes supervisor handoff" {
  let service = @lepusa.LocalService::new(
    name="api",
    command=["moon", "run", "cmd/server"],
    readiness_url="http://127.0.0.1:4317/ready",
  )
  let plan = RuntimeServicePlan::new(services=[service], startup_services=[
    service,
  ])
  let supervisor = plan.supervisor_plan()
  assert_true(supervisor.requires_supervisor())
  assert_eq(supervisor.start_order().length(), 1)
  assert_eq(supervisor.start_order()[0], "api")
  assert_true(supervisor.startup_actions()[0] is StartLocalService(_))
  assert_true(supervisor.startup_actions()[1] is WaitLocalServiceReady(_))
  assert_true(supervisor.shutdown_actions()[0] is StopLocalService(_))
  assert_true(supervisor.to_json().contains("\"kind\":\"wait-ready\""))
}

///|
test "native runtime exposes decorated service supervisor plan" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    label="api",
    source=@lepusa.Source::localhost(
      port=4317,
      path="/",
      readiness_path="/ready",
      command=["moon", "run", "cmd/server"],
    ),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) =>
      match
        NativeRuntime::new(
          NativeBackend::new(name="test", webview_engine="SystemWebView"),
          RuntimeHost::new(plan),
        ) {
        Ok(runtime) => {
          let supervisor = runtime.service_supervisor_plan()
          assert_eq(supervisor.backend_name(), "test")
          assert_eq(supervisor.webview_engine(), "SystemWebView")
          assert_true(supervisor.requires_supervisor())
          assert_eq(supervisor.validate().length(), 0)
          assert_eq(supervisor.services().length(), 1)
          assert_eq(supervisor.start_order()[0], "api")
          assert_true(supervisor.startup_actions()[0] is StartLocalService(_))
          assert_true(
            supervisor.startup_actions()[1] is WaitLocalServiceReady(_),
          )
          assert_true(supervisor.shutdown_actions()[0] is StopLocalService(_))
          assert_true(
            runtime.bootstrap_json().contains("\"serviceSupervisor\""),
          )
          assert_true(
            supervisor.to_json().contains("\"nativeBackend\":\"test\""),
          )
          let report = runtime.service_supervisor_report()
          assert_eq(report.backend_name(), "test")
          assert_true(report.ok())
          assert_eq(report.action_count(), 3)
          assert_eq(report.failed_count(), 0)
          assert_true(
            report.action_reports()[1].status() is NativeServiceActionPrepared,
          )
          assert_true(
            report.to_json().contains("\"status\":{\"name\":\"prepared\""),
          )
        }
        Err(_) => abort("unexpected invalid native runtime")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "native service supervisor plan validates native metadata" {
  let plan = NativeServiceSupervisorPlan::new(
    backend_name="",
    webview_engine="",
    plan=@lepusa.LocalServiceSupervisorPlan::new(),
  )
  let problems = plan.validate()
  assert_eq(problems.length(), 2)
  assert_eq(problems[0], "native service supervisor backend is required")
  assert_eq(problems[1], "native service supervisor webview engine is required")
}

///|
test "native service supervisor report captures action failures" {
  let service = @lepusa.LocalService::new(
    name="api",
    command=["moon", "run", "cmd/server"],
    readiness_url="http://127.0.0.1:4317/ready",
  )
  let failed = NativeServiceActionReport::new(
    action=StartLocalService(service),
    status=NativeServiceActionFailed("spawn failed"),
  )
  let report = NativeServiceSupervisorReport::new(
    backend_name="test",
    webview_engine="SystemWebView",
    action_reports=[failed],
  )
  assert_false(report.ok())
  assert_eq(report.action_count(), 1)
  assert_eq(report.failed_count(), 1)
  assert_eq(report.action_reports()[0].service_name(), "api")
  assert_eq(report.action_reports()[0].action_kind(), "start-service")
  assert_true(report.action_reports()[0].failed())
  assert_eq(report.action_reports()[0].status().name(), "failed")
  assert_eq(report.action_reports()[0].status().message(), "spawn failed")
  assert_true(report.to_json().contains("\"failedCount\":1"))
}

///|
test "native service executor runs startup and shutdown hooks" {
  let service = @lepusa.LocalService::new(
    name="api",
    command=["moon", "run", "cmd/server"],
    readiness_url="http://127.0.0.1:4317/ready",
  )
  let plan = NativeServiceSupervisorPlan::new(
    backend_name="test",
    webview_engine="SystemWebView",
    plan=@lepusa.LocalServiceSupervisorPlan::new(services=[service], startup_services=[
      service,
    ]),
  )
  let executor = plan.executor(
    start_service=fn(_) { NativeServiceActionStarted },
    wait_until_ready=fn(service) {
      if service.name() == "api" {
        NativeServiceActionReady
      } else {
        NativeServiceActionFailed("unexpected service")
      }
    },
    stop_service=fn(_) { NativeServiceActionStopped },
  )
  let startup = executor.execute_startup(plan)
  assert_eq(startup.backend_name(), "test")
  assert_true(startup.ok())
  assert_eq(startup.action_count(), 2)
  assert_true(
    startup.action_reports()[0].status() is NativeServiceActionStarted,
  )
  assert_true(startup.action_reports()[1].status() is NativeServiceActionReady)
  let shutdown = executor.execute_shutdown(plan)
  assert_eq(shutdown.action_count(), 1)
  assert_true(
    shutdown.action_reports()[0].status() is NativeServiceActionStopped,
  )
  let all = executor.execute_all(plan)
  assert_eq(all.action_count(), 3)
  assert_true(all.to_json().contains("\"name\":\"ready\""))
}

///|
test "native backend creates service executor with backend metadata" {
  let service = @lepusa.LocalService::new(
    name="api",
    command=["moon", "run", "cmd/server"],
    readiness_url="http://127.0.0.1:4317/ready",
  )
  let plan = NativeServiceSupervisorPlan::new(
    backend_name="test",
    webview_engine="SystemWebView",
    plan=@lepusa.LocalServiceSupervisorPlan::new(services=[service], startup_services=[
      service,
    ]),
  )
  let executor = NativeBackend::new(
    name="native-test",
    webview_engine="SystemWebView",
  ).service_executor(
    start_service=fn(_) { NativeServiceActionStarted },
    wait_until_ready=fn(_) { NativeServiceActionFailed("not ready") },
    stop_service=fn(_) { NativeServiceActionSkipped("not started") },
  )
  assert_eq(executor.backend_name(), "native-test")
  assert_eq(executor.webview_engine(), "SystemWebView")
  let startup = executor.execute_startup(plan)
  assert_false(startup.ok())
  assert_eq(startup.failed_count(), 1)
  assert_true(
    startup.action_reports()[1].status() is NativeServiceActionFailed(_),
  )
  assert_true(startup.to_json().contains("\"message\":\"not ready\""))
}

///|
test "native service command packet is length-prefixed" {
  let packet = @utf8.decode(
    native_service_command_packet(["moon", "run", "cmd/main", "--flag"]),
  ) catch {
    _ => abort("unexpected invalid service command packet")
  }
  assert_eq(packet, "4\nmoon3\nrun8\ncmd/main6\n--flag")
}

///|
test "runtime host applies lifecycle actions to an existing session" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main>main</main>"))
    .on_window_close_requested(
      "main",
      @lepusa.Cmd::batch([
        @lepusa.Cmd::emit(@lepusa.Event::new("closing")),
        @lepusa.Cmd::effect("persist"),
      ]),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let host = RuntimeHost::new(plan)
      match host.snapshot() {
        Ok(session) =>
          match host.lifecycle_step(session, WindowCloseRequested("main")) {
            Ok(step) => {
              let operations = step.operations()
              assert_eq(operations.length(), 2)
              assert_true(operations[0] is RuntimeDispatchEvent(_))
              guard operations[0] is RuntimeDispatchEvent(dispatch) else {
                fail("expected frontend event dispatch")
              }
              assert_eq(dispatch.window_label(), "main")
              assert_true(operations[1] is RuntimeRunEffect("persist"))
              assert_eq(
                step.session().windows()[0].url(),
                "lepusa://inline/main/index.html",
              )
            }
            Err(_) => abort("unexpected invalid lifecycle step")
          }
        Err(_) => abort("unexpected invalid session")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime session reports invalid action application" {
  match RuntimeHost::new(test_plan()).snapshot() {
    Ok(session) =>
      match
        @lepusa.Source::html("<main>missing</main>").resolve(
          window_label="missing",
        ) {
        Ok(source) =>
          match session.apply_actions([RuntimeNavigate("missing", source)]) {
            Ok(_) => abort("unexpected valid missing navigation")
            Err(problems) =>
              assert_eq(problems[0], "navigate window not found: missing")
          }
        Err(_) => abort("unexpected invalid test source")
      }
    Err(_) => abort("unexpected invalid session")
  }
}

///|
test "runtime wire codec decodes bridge requests and encodes responses" {
  match
    decode_invoke_request_json(
      "{\"id\":\"7\",\"windowLabel\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"{\\\"x\\\":1}\"}",
    ) {
    Ok(request) => {
      assert_eq(request.id(), "7")
      assert_eq(request.window_label(), "main")
      assert_eq(request.route(), "core.invoke")
      assert_eq(request.payload(), "{\"x\":1}")
    }
    Err(_) => abort("unexpected invalid bridge request")
  }
  let json = encode_invoke_response_json(@lepusa.InvokeResponse::ok("7", "{}"))
  assert_true(json.contains("\"id\":\"7\""))
  assert_true(json.contains("\"payload\":\"{}\""))
}

///|
test "runtime host dispatches bridge json through capability checks" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
    payload,
  ) {
    Ok("{\"seen\":\{payload}}")
  })
  let host = RuntimeHost::new(test_plan(), registry~)
  let response = host.dispatch_json(
    "{\"id\":\"1\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}",
  )
  assert_true(response.contains("\"id\":\"1\""))
  assert_true(response.contains("\"payload\":\"{\\\"seen\\\":true}\""))
  let denied = host.dispatch_json(
    "{\"id\":\"2\",\"window_label\":\"other\",\"plugin\":\"core\",\"command\":\"invoke\"}",
  )
  assert_true(denied.contains("\"id\":\"2\""))
  assert_true(denied.contains("\"error\":\"permission denied: core.invoke\""))
  let malformed = host.dispatch_json("{}")
  assert_true(malformed.contains("\"error\":\"invoke id is required\""))
}

///|
async test "runtime host dispatches async bridge handlers" {
  let registry = @lepusa.CommandRegistry::new().register_async_fn(
    "core.invoke",
    handler=fn(payload) { Ok("{\"async\":\{payload}}") },
  )
  let host = RuntimeHost::new(test_plan(), registry~)
  let response = host.dispatch_json_async(
    "{\"id\":\"1\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}",
  )
  assert_true(response.contains("\"id\":\"1\""))
  assert_true(response.contains("\"payload\":\"{\\\"async\\\":true}\""))
  let sync_response = host.dispatch_json(
    "{\"id\":\"2\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}",
  )
  assert_true(
    sync_response.contains(
      "\"error\":\"command requires async dispatch: core.invoke\"",
    ),
  )
}

///|
fn async_bridge_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="main",
      title="Runtime",
      source=@lepusa.Source::html("<main>runtime</main>"),
    )
    .with_plugin(@lepusa.Plugin::new("core").command_async("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => plan
    Err(_) => abort("unexpected invalid async bridge plan")
  }
}

///|
async test "native runtime owns bridge message transport" {
  let registry = @lepusa.CommandRegistry::new().register_async_fn(
    "core.invoke",
    handler=fn(payload) { Ok("{\"async\":\{payload}}") },
  )
  let host = RuntimeHost::new(async_bridge_plan(), registry~)
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, host) {
    Ok(runtime) => {
      let message = "{\"id\":\"9\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}"
      match runtime.prepare_bridge_message(message) {
        Ok(prepared) => {
          assert_eq(prepared.window_label(), "main")
          assert_eq(prepared.response_hook(), "__lepusaInvokeResponse")
          assert_eq(prepared.message(), message)
          let dispatch = prepared.dispatch(runtime)
          assert_eq(dispatch.window_label(), "main")
          assert_eq(dispatch.response_hook(), "__lepusaInvokeResponse")
          assert_true(dispatch.response_json().contains("\"id\":\"9\""))
          assert_true(
            dispatch
            .response_json()
            .contains("\"payload\":\"{\\\"async\\\":true}\""),
          )
          assert_true(
            dispatch
            .evaluation_script()
            .contains("globalThis[\"__lepusaInvokeResponse\"]"),
          )
        }
        Err(_) => abort("unexpected bridge prepare failure")
      }
      match runtime.dispatch_bridge_message_sync(message) {
        Ok(dispatch) => {
          assert_true(dispatch.response_json().contains("\"id\":\"9\""))
          assert_true(
            dispatch
            .response_json()
            .contains("command requires async dispatch: core.invoke"),
          )
          assert_true(
            dispatch
            .evaluation_script()
            .contains("globalThis[\"__lepusaInvokeResponse\"]"),
          )
        }
        Err(_) => abort("unexpected bridge sync dispatch failure")
      }
      let sync_script = @utf8.decode(
        runtime.dispatch_bridge_script_bytes(@utf8.encode(message)),
      ) catch {
        _ => abort("unexpected invalid bridge script bytes")
      }
      assert_true(
        sync_script.contains("globalThis[\"__lepusaInvokeResponse\"]"),
      )
      assert_true(sync_script.contains("command requires async dispatch"))
      let asset_packet = @utf8.decode(
        runtime.resolve_asset_protocol_packet_bytes(
          @utf8.encode("lepusa://inline/main/index.html"),
        ),
      ) catch {
        _ => abort("unexpected invalid asset packet bytes")
      }
      assert_eq(asset_packet, "ok\nvirtual\ntext/html\n<main>runtime</main>")
      match
        runtime.dispatch_bridge_message(
          "{\"id\":\"10\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"false\"}",
        ) {
        Ok(dispatch) => {
          assert_true(dispatch.response_json().contains("\"id\":\"10\""))
          assert_true(
            dispatch
            .response_json()
            .contains("\"payload\":\"{\\\"async\\\":false}\""),
          )
        }
        Err(_) => abort("unexpected bridge dispatch failure")
      }
    }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "native bridge transport validates target window" {
  let host = RuntimeHost::new(test_plan())
  let backend = NativeBackend::new(name="test", webview_engine="SystemWebView")
  match NativeRuntime::new(backend, host) {
    Ok(runtime) => {
      match runtime.bridge_response_hook(window_label="main") {
        Ok((window_label, hook)) => {
          assert_eq(window_label, "main")
          assert_eq(hook, "__lepusaInvokeResponse")
        }
        Err(problem) => abort(problem)
      }
      match
        runtime.prepare_bridge_message(
          "{\"id\":\"11\",\"window_label\":\"missing\",\"plugin\":\"core\",\"command\":\"invoke\"}",
        ) {
        Ok(_) => abort("unexpected bridge prepare success")
        Err(problems) =>
          assert_eq(problems[0], "native bridge window not found: missing")
      }
      assert_eq(
        native_bridge_response_script("__hook", "{\"id\":\"1\"}"),
        "globalThis[\"__hook\"]({\"id\":\"1\"});",
      )
    }
    Err(_) => abort("unexpected invalid native runtime")
  }
}

///|
test "native bridge hook scripts cover webkit and webview2 transports" {
  let webkit = native_webkit_bridge_hook_script(
    "__lepusaInvoke",
    platform_name="macOS",
  )
  assert_true(webkit.contains("globalThis.webkit"))
  assert_true(webkit.contains("messageHandlers"))
  assert_true(webkit.contains("__lepusaInvokeResponse"))
  assert_true(webkit.contains("Missing Lepusa macOS native message handler"))
  assert_false(webkit.contains("chrome.webview"))
  let webview2 = native_webview2_bridge_hook_script("__lepusaInvoke")
  assert_true(webview2.contains("chrome.webview"))
  assert_true(
    webview2.contains(
      "postMessage(JSON.stringify({ hook: nativeHook, request }))",
    ),
  )
  assert_true(webview2.contains("__lepusaInvokeResponse"))
  assert_true(webview2.contains("Missing Lepusa Windows WebView2 bridge"))
  assert_false(webview2.contains("messageHandlers"))
}
