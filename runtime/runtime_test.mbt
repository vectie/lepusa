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
          assert_true(
            operations[0] is RuntimeSendEvent(WindowTarget("main"), _),
          )
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
        }
        Err(_) => abort("unexpected invalid dev plan")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
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
              assert_true(operations[0] is RuntimeSendEvent(AppTarget, _))
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
