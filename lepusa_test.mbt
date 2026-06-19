///|
test "cell_with_dispatch keeps rabbita style authoring surface" {
  let (dispatch, cell) = @lepusa.cell_with_dispatch(
    model=1,
    update=fn(message : String, model : Int) {
      (model + 1, @lepusa.Cmd::effect(message))
    },
    view=fn(_dispatch, model) { @lepusa.Html::text("model \{model}") },
  )
  assert_eq(cell.id(), "lepusa-root")
  assert_eq(cell.html().content(), "model 1")
  assert_true(dispatch("load") is Effect("load"))
}

///|
test "window config validates source and dimensions" {
  let missing_source = @lepusa.WindowConfig::new()
  let problems = missing_source.validate()
  assert_eq(problems.length(), 1)
  assert_eq(problems[0], "window source is required")
  let ready = @lepusa.WindowConfig::new(
    label="main",
    title="Desktop",
    width=1200,
    height=800,
    source=@lepusa.Source::local_path("dist"),
  )
  assert_eq(ready.validate().is_empty(), true)
}

///|
test "sources resolve into backend load targets" {
  match
    @lepusa.Source::local_path("dist").resolve(
      window_label="Main Window",
      asset_protocol="lepusa",
    ) {
    Ok(resolved) => {
      assert_true(resolved.kind() is ResolvedLocalPath)
      assert_eq(resolved.url(), "lepusa://local/main-window/index.html")
      let mappings = resolved.protocol_mappings()
      assert_eq(mappings.length(), 1)
      assert_eq(mappings[0].root(), "dist")
      assert_eq(resolved.virtual_files().length(), 0)
    }
    Err(problem) => abort(problem)
  }
  match
    @lepusa.Source::url("http://127.0.0.1:3000").resolve(window_label="main") {
    Ok(resolved) => {
      assert_true(resolved.kind() is ResolvedRemoteUrl)
      assert_eq(resolved.url(), "http://127.0.0.1:3000")
      assert_eq(resolved.protocol_mappings().length(), 0)
      assert_eq(resolved.virtual_files().length(), 0)
    }
    Err(problem) => abort(problem)
  }
}

///|
test "windows resolve source and preserve frame config" {
  let window = @lepusa.WindowConfig::new(
    label="main",
    title="Resolved",
    width=800,
    height=600,
    source=@lepusa.Source::html("<main></main>"),
  )
  match window.resolve(asset_protocol="lepusa") {
    Ok(resolved) => {
      assert_eq(resolved.label(), "main")
      assert_eq(resolved.url(), "lepusa://inline/main/index.html")
      assert_true(resolved.source().kind() is ResolvedInlineHtml)
      let files = resolved.source().virtual_files()
      assert_eq(files.length(), 1)
      assert_eq(files[0].path(), "index.html")
      assert_eq(files[0].content(), "<main></main>")
    }
    Err(_) => abort("unexpected invalid window")
  }
}

///|
test "plugins expose command metadata without owning app domain behavior" {
  let plugin = @lepusa.Plugin::new("workspace")
    .command_sync("read_config")
    .command_stream("events")
  assert_eq(plugin.name(), "workspace")
  let command_names = plugin.command_names()
  assert_eq(command_names.length(), 2)
  assert_eq(command_names[0], "read_config")
  assert_eq(command_names[1], "events")
  assert_true(plugin.commands()[1].mode() is Stream)
}

///|
test "plugin validation rejects empty and duplicate commands" {
  let plugin = @lepusa.Plugin::new("core")
    .command_sync("invoke")
    .command_async("invoke")
  let problems = plugin.validate()
  assert_eq(problems.length(), 1)
  assert_eq(problems[0], "plugin command must be unique: invoke")
}

///|
test "capabilities scope permissions by window" {
  let capability = @lepusa.Capability::new("main-files")
    .window("main")
    .permission(FileSystemRead)
  assert_eq(
    capability.allows(window_label="main", permission=FileSystemRead),
    true,
  )
  assert_eq(
    capability.allows(window_label="settings", permission=FileSystemRead),
    false,
  )
}

///|
test "ipc requests expose stable command routes" {
  let request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="workspace",
    command="read",
  )
  assert_eq(request.route(), "workspace.read")
  assert_eq(request.validate().is_empty(), true)
  assert_true(@lepusa.InvokeResponse::ok("1", "{}") is InvokeOk("1", "{}"))
}

///|
test "command registry dispatches allowed invokes" {
  let registry = @lepusa.CommandRegistry::new().register_fn(
    "dialog.show",
    permission=Dialog,
    handler=fn(payload) { Ok("shown:\{payload}") },
  )
  let request = @lepusa.InvokeRequest::new(
    id="42",
    window_label="main",
    plugin="dialog",
    command="show",
    payload="hello",
  )
  let response = registry.dispatch(request, capabilities=[
    @lepusa.Capability::new("main-dialog").window("main").permission(Dialog),
  ])
  assert_true(response is InvokeOk("42", "shown:hello"))
}

///|
test "command registry denies missing capability" {
  let registry = @lepusa.CommandRegistry::new().register_fn(
    "shell.open",
    permission=Shell,
    handler=fn(payload) { Ok(payload) },
  )
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="7",
      window_label="main",
      plugin="shell",
      command="open",
      payload="x",
    ),
  )
  assert_true(response is InvokeError("7", "permission denied: shell.open"))
}

///|
test "command registry reports unknown routes and handler errors" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.fail", handler=fn(
    _payload,
  ) {
    Err("failed")
  })
  let missing = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="missing",
      window_label="main",
      plugin="core",
      command="missing",
    ),
    capabilities=[@lepusa.Capability::new("core").command("core.missing")],
  )
  assert_true(
    missing is InvokeError("missing", "unknown command: core.missing"),
  )
  let failed = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="fail",
      window_label="main",
      plugin="core",
      command="fail",
    ),
    capabilities=[@lepusa.Capability::new("core").command("core.fail")],
  )
  assert_true(failed is InvokeError("fail", "failed"))
}

///|
test "events can become runtime commands" {
  let event = @lepusa.Event::new("ready", payload="{\"ok\":true}")
  assert_eq(event.name(), "ready")
  assert_eq(event.validate().is_empty(), true)
  assert_true(
    @lepusa.Cmd::emit(event, target=WindowTarget("main"))
    is Emit(WindowTarget("main"), _),
  )
}

///|
test "app builds a launch plan as the native runtime boundary" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      title="Lepusa",
      width=900,
      height=640,
      source=@lepusa.Source::html("<main></main>"),
    )
    .with_plugin(@lepusa.Plugin::new("core").command_async("invoke"))
    .with_capability(@lepusa.Capability::new("core").permission(Notification))
    .with_startup(@lepusa.Cmd::effect("boot"))
  match app.launch_plan() {
    Ok(plan) => {
      assert_eq(plan.window_count(), 1)
      assert_eq(plan.plugin_count(), 1)
      assert_eq(plan.capability_count(), 1)
    }
    Err(_) => abort("unexpected invalid app")
  }
}

///|
test "runtime plans collect plugin command routes" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("dialog")
      .command_sync("show")
      .command_async("confirm"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      assert_true(plan.backend() is Headless)
      let routes = plan.command_routes()
      assert_eq(routes.length(), 2)
      assert_eq(routes[0], "dialog.show")
      assert_eq(routes[1], "dialog.confirm")
      assert_eq(plan.windows()[0].url(), "lepusa://inline/main/index.html")
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime plans expose portable launch manifest" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="Launch", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match plan.launch_manifest(registered_routes=["core.invoke"]) {
        Ok(manifest) => {
          assert_eq(manifest.backend(), "headless")
          assert_eq(manifest.webviews()[0].title(), "Launch")
          assert_eq(manifest.protocol_mappings()[0].root(), "memory:main")
          assert_eq(manifest.registered_routes()[0], "core.invoke")
          assert_true(manifest.to_json().contains("\"initializationScripts\""))
        }
        Err(_) => abort("unexpected invalid launch manifest")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime plans generate frontend bridge script" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("dialog").command_sync("show"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match
        plan.bridge_script(
          config=@lepusa.BridgeConfig::new(
            global_name="lepusa",
            native_hook="__lepusaInvoke",
            window_label="main",
          ),
        ) {
        Ok(script) => {
          let routes = script.routes()
          assert_eq(routes.length(), 1)
          assert_eq(routes[0], "dialog.show")
          assert_true(script.source().contains("globalThis"))
          assert_true(script.source().contains("\"dialog.show\""))
          assert_true(script.source().contains("__lepusaInvoke"))
        }
        Err(_) => abort("unexpected invalid bridge script")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "bridge config validates required names" {
  let config = @lepusa.BridgeConfig::new(
    global_name="",
    native_hook="",
    window_label="",
  )
  let problems = config.validate()
  assert_eq(problems.length(), 3)
  assert_eq(problems[0], "bridge global name is required")
}

///|
test "bundle plans derive executable and package names from metadata" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    source=@lepusa.Source::html("<main></main>"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(runtime) => {
      let bundle = @lepusa.BundleConfig::new(
        @lepusa.AppMetadata::new(
          identifier="dev.vectie.lepusa.example",
          product_name="Lepusa Example",
          version="0.1.0",
        ),
        target=MacOS,
      )
      match bundle.plan(runtime) {
        Ok(plan) => {
          assert_eq(plan.executable_name(), "lepusa-example")
          assert_eq(plan.bundle_name(), "lepusa-example.app")
          match plan.files() {
            Ok(files) => {
              assert_eq(files.length(), 3)
              assert_eq(
                files[0].path(),
                "lepusa-example.app/Contents/Info.plist",
              )
              assert_true(files[0].content().contains("CFBundleIdentifier"))
              assert_eq(
                files[2].path(),
                "lepusa-example.app/Contents/Resources/lepusa/runtime.json",
              )
              assert_true(files[2].content().contains("\"webviews\""))
              assert_true(files[2].content().contains("windowLabel"))
              assert_true(files[2].content().contains("__lepusaInvoke"))
            }
            Err(_) => abort("unexpected invalid bundle files")
          }
        }
        Err(_) => abort("unexpected invalid bundle plan")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "bundle files include platform metadata" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    source=@lepusa.Source::html("<main></main>"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(runtime) => {
      let metadata = @lepusa.AppMetadata::new(
        identifier="dev.vectie.files",
        product_name="Files App",
        version="0.3.0",
      )
      match @lepusa.BundleConfig::new(metadata, target=Linux).plan(runtime) {
        Ok(plan) =>
          match plan.files() {
            Ok(files) => {
              assert_eq(files[0].path(), "files-app/files-app.desktop")
              assert_true(files[0].content().contains("Name=Files App"))
              assert_true(files[1].content().contains("\"target\":\"linux\""))
            }
            Err(_) => abort("unexpected invalid linux bundle files")
          }
        Err(_) => abort("unexpected invalid linux bundle plan")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "project manifests validate reusable app configuration" {
  let manifest = @lepusa.ProjectManifest::new(
    @lepusa.AppMetadata::new(
      identifier="",
      product_name="Example",
      version="0.1.0",
    ),
  )
  let problems = manifest.validate()
  assert_eq(problems.length(), 2)
  assert_eq(problems[0], "app identifier is required")
  assert_eq(problems[1], "at least one window is required")
}

///|
test "project manifests build runtime and bundle plans" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let manifest = @lepusa.ProjectManifest::new(
      @lepusa.AppMetadata::new(
        identifier="dev.vectie.manifest",
        product_name="Manifest App",
        version="0.2.0",
      ),
      runtime=@lepusa.RuntimeConfig::headless(),
    )
    .with_window(
      @lepusa.WindowConfig::new(source=@lepusa.Source::html("<main></main>")),
    )
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(@lepusa.Capability::new("core").permission(Notification))
  match manifest.runtime_plan(root) {
    Ok(runtime) => {
      assert_eq(runtime.window_count(), 1)
      assert_eq(runtime.command_routes()[0], "core.invoke")
    }
    Err(_) => abort("unexpected invalid manifest runtime plan")
  }
  match manifest.bundle_plan(root, target=Linux) {
    Ok(bundle) => {
      assert_eq(bundle.identifier(), "dev.vectie.manifest")
      assert_eq(bundle.bundle_name(), "manifest-app")
    }
    Err(_) => abort("unexpected invalid manifest bundle plan")
  }
}
