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
    .command_stream("events", permission=Notification)
  assert_eq(plugin.name(), "workspace")
  let command_names = plugin.command_names()
  assert_eq(command_names.length(), 2)
  assert_eq(command_names[0], "read_config")
  assert_eq(command_names[1], "events")
  assert_true(plugin.commands()[1].mode() is Stream)
  assert_true(plugin.commands()[1].permission() is Notification)
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
  assert_true(event.to_json().contains("\"name\":\"ready\""))
  assert_true(event.to_json().contains("\"payload\":\"{\\\"ok\\\":true}\""))
  assert_true(
    @lepusa.Cmd::emit(event, target=WindowTarget("main"))
    is Emit(WindowTarget("main"), _),
  )
}

///|
test "runtime plans lower commands to backend actions" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main")
    .with_startup(
      @lepusa.Cmd::batch([
        @lepusa.Cmd::emit(
          @lepusa.Event::new("ready", payload="{\"ok\":true}"),
          target=WindowTarget("main"),
        ),
        @lepusa.Cmd::navigate("main", @lepusa.Source::html("<main>next</main>")),
        @lepusa.Cmd::effect("boot"),
      ]),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match plan.startup_actions() {
        Ok(actions) => {
          assert_eq(actions.length(), 3)
          assert_true(actions[0] is RuntimeEmit(WindowTarget("main"), _))
          assert_true(
            actions[1]
            is RuntimeNavigate(
              "main",
              { url: "lepusa://inline/main/index.html", .. }
            ),
          )
          assert_true(actions[2] is RuntimeEffect("boot"))
          match plan.launch_manifest() {
            Ok(manifest) => {
              assert_eq(manifest.startup_actions().length(), 3)
              assert_true(manifest.to_json().contains("\"startupActions\""))
              assert_true(manifest.to_json().contains("\"kind\":\"navigate\""))
            }
            Err(_) => abort("unexpected invalid launch manifest")
          }
        }
        Err(_) => abort("unexpected invalid runtime actions")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime action lowering reports invalid commands" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(label="main")
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      match
        plan.actions(
          @lepusa.Cmd::navigate(
            "missing",
            @lepusa.Source::html("<main></main>"),
          ),
        ) {
        Ok(_) => abort("unexpected valid missing navigation window")
        Err(problems) =>
          assert_eq(problems[0], "navigate window not found: missing")
      }
      match plan.actions(@lepusa.Cmd::emit(@lepusa.Event::new(""))) {
        Ok(_) => abort("unexpected valid empty event")
        Err(problems) => assert_eq(problems[0], "event name is required")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
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
test "app windows default to rabbita root cell source" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<strong>Hello</strong>"))
  let app = @lepusa.new(root).window(title="Rabbita")
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let window = plan.windows()[0]
      assert_eq(window.url(), "lepusa://rabbita/main/index.html")
      assert_true(window.source().kind() is ResolvedRabbitaMount)
      let files = window.source().virtual_files()
      assert_eq(files.length(), 1)
      assert_true(files[0].content().contains("<main id=\"lepusa-root\">"))
      assert_true(files[0].content().contains("<strong>Hello</strong>"))
      match plan.launch_manifest() {
        Ok(manifest) => {
          assert_eq(manifest.virtual_files()[0].mime_type(), "text/html")
          assert_true(
            manifest.virtual_files()[0]
            .content()
            .contains("<strong>Hello</strong>"),
          )
        }
        Err(_) => abort("unexpected invalid launch manifest")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
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
test "runtime plans expose bridge routes per window capability" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .window(label="admin", source=@lepusa.Source::html("<aside></aside>"))
    .with_plugin(
      @lepusa.Plugin::new("core").command_sync("open").command_sync("admin"),
    )
    .with_capability(
      @lepusa.Capability::new("main-open").window("main").command("core.open"),
    )
    .with_capability(
      @lepusa.Capability::new("admin-only")
      .window("admin")
      .command("core.admin"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let main_routes = plan.window_command_routes("main")
      assert_eq(main_routes.length(), 1)
      assert_eq(main_routes[0], "core.open")
      let admin_routes = plan.window_command_routes("admin")
      assert_eq(admin_routes.length(), 1)
      assert_eq(admin_routes[0], "core.admin")
      match
        plan.bridge_script(
          config=@lepusa.BridgeConfig::new(window_label="main"),
        ) {
        Ok(script) => assert_true(script.source().contains("\"core.open\""))
        Err(_) => abort("unexpected invalid main bridge")
      }
      match plan.launch_manifest() {
        Ok(manifest) => {
          assert_eq(manifest.webviews()[0].allowed_routes()[0], "core.open")
          assert_eq(manifest.webviews()[1].allowed_routes()[0], "core.admin")
          assert_true(manifest.to_json().contains("\"allowedRoutes\""))
        }
        Err(_) => abort("unexpected invalid launch manifest")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime plans map command routes to explicit permissions" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("dialog").command_sync("show", permission=Dialog),
    )
    .with_capability(
      @lepusa.Capability::new("main-dialog").window("main").permission(Dialog),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let routes = plan.window_command_routes("main")
      assert_eq(routes.length(), 1)
      assert_eq(routes[0], "dialog.show")
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
    .with_capability(
      @lepusa.Capability::new("main-core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match plan.launch_manifest(registered_routes=["core.invoke"]) {
        Ok(manifest) => {
          assert_eq(manifest.backend(), "headless")
          assert_eq(manifest.webviews()[0].title(), "Launch")
          assert_eq(
            manifest.webviews()[0].event_dispatch_hook(),
            "__lepusaDispatchEvent",
          )
          assert_eq(manifest.webviews()[0].allowed_routes()[0], "core.invoke")
          assert_eq(manifest.protocol_mappings()[0].root(), "memory:main")
          assert_eq(manifest.virtual_files()[0].path(), "index.html")
          assert_eq(manifest.virtual_files()[0].mime_type(), "text/html")
          assert_eq(manifest.virtual_files()[0].content(), "<main></main>")
          assert_eq(manifest.registered_routes()[0], "core.invoke")
          assert_true(manifest.to_json().contains("\"virtualFiles\""))
          assert_true(manifest.to_json().contains("\"initializationScripts\""))
        }
        Err(_) => abort("unexpected invalid launch manifest")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "launch manifest resolves virtual and local assets" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="ui", source=@lepusa.Source::html("<main>ui</main>"))
    .window(label="static", source=@lepusa.Source::local_path("dist"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match plan.launch_manifest() {
        Ok(manifest) => {
          match
            manifest.resolve_asset("lepusa://inline/ui/index.html?v=1#top") {
            Ok(asset) => {
              assert_eq(asset.mime_type(), "text/html")
              assert_true(
                asset.body() is LaunchVirtualContent("<main>ui</main>"),
              )
            }
            Err(_) => abort("unexpected missing virtual asset")
          }
          match manifest.resolve_asset("lepusa://local/static/app.css") {
            Ok(asset) => {
              assert_eq(asset.mime_type(), "text/css")
              assert_true(asset.body() is LaunchLocalFile("dist/app.css"))
            }
            Err(_) => abort("unexpected missing local asset")
          }
          match manifest.resolve_asset("lepusa://local/static/../secret.txt") {
            Ok(_) => abort("unexpected unsafe local asset")
            Err(problem) =>
              assert_eq(problem, "unsafe asset path: ../secret.txt")
          }
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
    .with_capability(
      @lepusa.Capability::new("dialog").window("main").command("dialog.show"),
    )
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
    event_dispatch_hook="",
    window_label="",
  )
  let problems = config.validate()
  assert_eq(problems.length(), 4)
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
          match plan.runtime_manifest() {
            Ok(manifest) => {
              assert_eq(manifest.webviews().length(), 1)
              assert_eq(manifest.virtual_files()[0].mime_type(), "text/html")
            }
            Err(_) => abort("unexpected invalid bundle runtime manifest")
          }
          match plan.runtime_manifest_json() {
            Ok(json) => {
              assert_true(json.contains("\"webviews\""))
              assert_true(json.contains("\"virtualFiles\""))
            }
            Err(_) => abort("unexpected invalid bundle runtime manifest json")
          }
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
