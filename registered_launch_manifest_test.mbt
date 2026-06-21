///|
fn registered_launch_test_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync("read")
      .command_sync("write")
      .command_event("changed"),
    )
    .with_capability(
      @lepusa.Capability::new("core")
      .window("main")
      .command("core.read")
      .command("core.write")
      .command("core.changed"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "registered launch manifest prunes bridge and command manifest" {
  let plan = registered_launch_test_plan()
  match
    plan.launch_manifest(
      registered_routes=["core.read"],
      restrict_registered=true,
    ) {
    Ok(manifest) => {
      assert_eq(manifest.command_routes().length(), 1)
      assert_eq(manifest.command_routes()[0], "core.read")
      assert_eq(manifest.declared_routes().length(), 3)
      assert_true(manifest.declared_routes().contains("core.write"))
      assert_eq(manifest.command_manifest().entries().length(), 1)
      assert_true(manifest.command_manifest().entry("core.read") is Some(_))
      assert_true(manifest.command_manifest().entry("core.write") is None)
      assert_true(manifest.command_manifest().entry("core.changed") is None)
      assert_eq(manifest.permission_manifest().denied_routes().length(), 0)
      assert_eq(manifest.webviews()[0].allowed_routes().length(), 1)
      assert_eq(manifest.webviews()[0].allowed_routes()[0], "core.read")
      let script = manifest.webviews()[0].initialization_scripts()[0]
      assert_true(script.contains("\"core.read\""))
      assert_false(script.contains("\"core.write\""))
      assert_false(script.contains("\"core.changed\""))
      assert_true(manifest.to_json().contains("\"declaredRoutes\""))
    }
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "plan launch manifest keeps full diagnostic command manifest by default" {
  let plan = registered_launch_test_plan()
  match plan.launch_manifest(registered_routes=["core.read"]) {
    Ok(manifest) => {
      assert_eq(manifest.command_manifest().entries().length(), 3)
      assert_eq(manifest.command_routes().length(), 3)
      assert_true(manifest.command_manifest().entry("core.write") is Some(_))
      assert_true(manifest.command_manifest().entry("core.changed") is Some(_))
      assert_false(
        manifest.webviews()[0].initialization_scripts()[0].contains(
          "\"core.changed\"",
        ),
      )
    }
    Err(problems) => abort(problems.join(", "))
  }
}
