///|
fn registered_bridge_host() -> RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core").command_sync("read").command_sync("write"),
    )
    .with_capability(
      @lepusa.Capability::new("core")
      .window("main")
      .command("core.read")
      .command("core.write"),
    )
  let plan = match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
  let registry = @lepusa.CommandRegistry::new().register_fn("core.read", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  RuntimeHost::new(plan, registry~)
}

///|
test "runtime host launch manifest and session bridge use registered routes" {
  let host = registered_bridge_host()
  match host.launch_manifest() {
    Ok(manifest) => {
      assert_eq(manifest.command_routes().length(), 1)
      assert_eq(manifest.command_routes()[0], "core.read")
      assert_eq(manifest.webviews()[0].allowed_routes()[0], "core.read")
      assert_false(
        manifest.webviews()[0].initialization_scripts()[0].contains(
          "\"core.write\"",
        ),
      )
    }
    Err(problems) => abort(problems.join(", "))
  }
  match host.webviews() {
    Ok(webviews) => {
      assert_eq(webviews[0].allowed_routes().length(), 1)
      assert_eq(webviews[0].allowed_routes()[0], "core.read")
    }
    Err(problems) => abort(problems.join(", "))
  }
  match host.snapshot() {
    Ok(session) => {
      assert_true(session.bridge_source().contains("\"core.read\""))
      assert_false(session.bridge_source().contains("\"core.write\""))
    }
    Err(problems) => abort(problems.join(", "))
  }
}
