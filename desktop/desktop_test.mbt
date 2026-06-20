///|
test "desktop kit installs official plugin metadata and handlers together" {
  let kit = DesktopKit::new().with_plugin("log").with_plugin("clipboard")
  assert_eq(kit.validate().length(), 0)
  assert_true(kit.plugin_names().contains("log"))
  assert_true(kit.plugin_names().contains("clipboard"))
  assert_true(kit.registered_routes().contains("log.write"))
  assert_true(kit.registered_routes().contains("clipboard.readText"))
  assert_eq(kit.capabilities().length(), 2)
  assert_true(kit.capabilities()[0].windows().contains("main"))
}

///|
test "desktop kit applies plugins and capabilities to app runtime" {
  let kit = DesktopKit::new().with_plugins(["log", "clipboard"])
  let base = @lepusa.new(
    @lepusa.simple_cell(@lepusa.Html::text("<main>desktop</main>")),
  ).window(source=@lepusa.Source::html("<main>desktop</main>"))
  match kit.apply(base) {
    Ok(app) =>
      match app.runtime_plan() {
        Ok(plan) => {
          assert_true(plan.command_routes().contains("log.write"))
          assert_true(plan.command_routes().contains("clipboard.readText"))
          assert_true(plan.window_command_routes("main").contains("log.write"))
          assert_true(
            plan.window_command_routes("main").contains("clipboard.readText"),
          )
          match kit.runtime_host(plan) {
            Ok(host) => {
              assert_true(host.sync_command_routes().contains("log.write"))
              assert_true(
                host.sync_command_routes().contains("clipboard.readText"),
              )
              let response = host.dispatch(
                @lepusa.InvokeRequest::new(
                  id="1",
                  window_label="main",
                  plugin="log",
                  command="write",
                  payload="{\"message\":\"ready\"}",
                ),
              )
              assert_true(response.error_message() is None)
            }
            Err(problems) => abort(problems.join("; "))
          }
        }
        Err(problems) => abort(problems.join("; "))
      }
    Err(problems) => abort(problems.join("; "))
  }
}

///|
test "desktop kit rejects runtime routes without registered handlers" {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main>desktop</main>")),
    )
    .window(source=@lepusa.Source::html("<main>desktop</main>"))
    .with_plugin(@lepusa.Plugin::new("custom").command_sync("run"))
    .with_capability(@lepusa.Capability::new("custom").command("custom.run"))
  match app.runtime_plan() {
    Ok(plan) =>
      match DesktopKit::new().runtime_host(plan) {
        Ok(_) => abort("unexpected valid host")
        Err(problems) => {
          assert_eq(problems.length(), 1)
          assert_eq(
            problems[0],
            "desktop handler is not registered: custom.run",
          )
        }
      }
    Err(problems) => abort(problems.join("; "))
  }
}

///|
test "desktop kit accepts custom app registries with official handlers" {
  let registry = @lepusa.CommandRegistry::new().register_fn("custom.run", handler=fn(
    _,
  ) {
    Ok("{\"ok\":true}")
  })
  let kit = DesktopKit::new().with_registry(registry).with_plugin("log")
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main>desktop</main>")),
    )
    .window(source=@lepusa.Source::html("<main>desktop</main>"))
    .with_plugin(@lepusa.Plugin::new("custom").command_sync("run"))
    .with_capability(@lepusa.Capability::new("custom").command("custom.run"))
  match kit.apply(app) {
    Ok(app) =>
      match app.runtime_plan() {
        Ok(plan) =>
          match kit.runtime_host(plan) {
            Ok(host) => {
              assert_true(host.sync_command_routes().contains("custom.run"))
              assert_true(host.sync_command_routes().contains("log.write"))
              let response = host.dispatch(
                @lepusa.InvokeRequest::new(
                  id="1",
                  window_label="main",
                  plugin="custom",
                  command="run",
                ),
              )
              assert_true(response.error_message() is None)
            }
            Err(problems) => abort(problems.join("; "))
          }
        Err(problems) => abort(problems.join("; "))
      }
    Err(problems) => abort(problems.join("; "))
  }
}

///|
test "desktop kit reports unknown official plugins before app planning" {
  let kit = DesktopKit::new().with_plugin("missing")
  let problems = kit.validate()
  assert_eq(problems.length(), 1)
  assert_eq(problems[0], "unknown official plugin: missing")
}

///|
test "desktop project builds runtime host and bundle plan from one boundary" {
  let project = DesktopProject::new(
      @lepusa.AppMetadata::new(
        identifier="dev.lepusa.desktop",
        product_name="Lepusa Desktop",
        version="0.1.0",
      ),
      @lepusa.simple_cell(@lepusa.Html::text("<main>project</main>")),
    )
    .window(source=@lepusa.Source::html("<main>project</main>"))
    .with_official_plugins(["log", "clipboard"])
    .with_startup(@lepusa.Cmd::effect("boot"))
    .on_shutdown(@lepusa.Cmd::effect("flush"))
  match project.runtime_host() {
    Ok(host) => {
      assert_true(host.sync_command_routes().contains("log.write"))
      assert_true(host.sync_command_routes().contains("clipboard.readText"))
      match host.snapshot() {
        Ok(session) => {
          assert_true(session.registered_routes().contains("log.write"))
          assert_true(
            session.registered_routes().contains("clipboard.readText"),
          )
          assert_true(session.startup_actions()[0] is RuntimeEffect("boot"))
        }
        Err(problems) => abort(problems.join("; "))
      }
    }
    Err(problems) => abort(problems.join("; "))
  }
  match project.bundle_plan(target=Linux) {
    Ok(bundle) => {
      assert_true(bundle.registered_routes().contains("log.write"))
      assert_true(bundle.registered_routes().contains("clipboard.readText"))
      match bundle.runtime_manifest() {
        Ok(manifest) => {
          assert_true(manifest.registered_routes().contains("log.write"))
          assert_true(
            manifest.registered_routes().contains("clipboard.readText"),
          )
        }
        Err(problems) => abort(problems.join("; "))
      }
    }
    Err(problems) => abort(problems.join("; "))
  }
}

///|
test "desktop project carries custom app registries" {
  let registry = @lepusa.CommandRegistry::new().register_fn(
    "counter.dispatch",
    handler=fn(_) { Ok("{\"html\":\"<main>ok</main>\"}") },
  )
  let project = DesktopProject::new(
      @lepusa.AppMetadata::new(
        identifier="dev.lepusa.counter",
        product_name="Lepusa Counter",
        version="0.1.0",
      ),
      @lepusa.simple_cell(@lepusa.Html::text("<main>counter</main>")),
    )
    .window(source=@lepusa.Source::html("<main>counter</main>"))
    .with_plugin(@lepusa.Plugin::new("counter").command_sync("dispatch"))
    .with_capability(
      @lepusa.Capability::new("counter").command("counter.dispatch"),
    )
    .with_registry(registry)
    .with_official_plugin("log")
  match project.runtime_host() {
    Ok(host) => {
      assert_true(host.sync_command_routes().contains("counter.dispatch"))
      assert_true(host.sync_command_routes().contains("log.write"))
    }
    Err(problems) => abort(problems.join("; "))
  }
}

///|
test "desktop project reports unknown official plugins before planning" {
  let project = DesktopProject::new(
      @lepusa.AppMetadata::new(
        identifier="dev.lepusa.desktop",
        product_name="Lepusa Desktop",
        version="0.1.0",
      ),
      @lepusa.simple_cell(@lepusa.Html::text("<main>project</main>")),
    )
    .window(source=@lepusa.Source::html("<main>project</main>"))
    .with_official_plugin("missing")
  match project.runtime_host() {
    Ok(_) => abort("unexpected valid project")
    Err(problems) => {
      assert_eq(problems.length(), 1)
      assert_eq(problems[0], "unknown official plugin: missing")
    }
  }
}

///|
async test "desktop project derives localhost services for catalog handlers" {
  let project = DesktopProject::new(
      @lepusa.AppMetadata::new(
        identifier="dev.lepusa.gateway",
        product_name="Lepusa Gateway",
        version="0.1.0",
      ),
      @lepusa.simple_cell(@lepusa.Html::text("<main>gateway</main>")),
    )
    .window(
      label="gateway",
      source=@lepusa.Source::localhost(port=4317, readiness_path="/ready", command=[
        "moon", "run", "cmd/server",
      ]),
    )
    .with_official_plugin("serviceDiscovery", window_label="gateway")
  match project.runtime_host() {
    Ok(host) => {
      let response = host.dispatch_async(
        @lepusa.InvokeRequest::new(
          id="1",
          window_label="gateway",
          plugin="serviceDiscovery",
          command="resolve",
          payload="{\"name\":\"gateway\"}",
        ),
      )
      assert_true(response.error_message() is None)
      assert_true(response.payload().unwrap_or("").contains("4317"))
    }
    Err(problems) => abort(problems.join("; "))
  }
}

///|
async test "desktop kit passes policies into catalog registries" {
  let scope = @lepusa.FileSystemScope::new(
    name="data",
    root="/tmp/lepusa-desktop-kit",
    writable=true,
  )
  let kit = DesktopKit::new().with_plugin("fs").with_filesystem_scope(scope)
  match
    kit.apply(
      @lepusa.new(@lepusa.simple_cell(@lepusa.Html::text("<main></main>"))).window(
        source=@lepusa.Source::html("<main></main>"),
      ),
    ) {
    Ok(app) =>
      match app.runtime_plan() {
        Ok(plan) =>
          match kit.runtime_host(plan) {
            Ok(host) => {
              let response = host.dispatch_async(
                @lepusa.InvokeRequest::new(
                  id="1",
                  window_label="main",
                  plugin="fs",
                  command="exists",
                  payload="{\"scope\":\"data\",\"path\":\"note.txt\"}",
                ),
              )
              assert_true(response.error_message() is None)
            }
            Err(problems) => abort(problems.join("; "))
          }
        Err(problems) => abort(problems.join("; "))
      }
    Err(problems) => abort(problems.join("; "))
  }
}
