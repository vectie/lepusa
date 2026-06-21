///|
test "plugin lifecycle hooks are projected into launch and runtime plans" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let plugin = @lepusa.Plugin::new("log")
    .command_sync("write")
    .on_setup(@lepusa.Cmd::effect("log.setup"))
    .on_ready(@lepusa.Cmd::emit(@lepusa.Event::new("log-ready")))
    .on_will_exit(@lepusa.Cmd::effect("log.flush"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(plugin)
    .with_capability(@lepusa.Capability::new("log").command("log.write"))
  match app.launch_plan() {
    Ok(launch) => {
      assert_eq(launch.lifecycle_hooks().length(), 3)
      assert_true(launch.lifecycle_hooks()[0].event() is PluginSetup("log"))
      assert_true(launch.lifecycle_hooks()[1].event() is PluginReady("log"))
      assert_true(launch.lifecycle_hooks()[2].event() is PluginWillExit("log"))
    }
    Err(problems) => abort(problems.join(", "))
  }
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(runtime) => {
      match runtime.lifecycle_actions(PluginSetup("log")) {
        Ok(actions) => assert_true(actions[0] is RuntimeEffect("log.setup"))
        Err(problems) => abort(problems.join(", "))
      }
      match runtime.lifecycle_actions(PluginReady("log")) {
        Ok(actions) => assert_true(actions[0] is RuntimeEmit(AppTarget, _))
        Err(problems) => abort(problems.join(", "))
      }
      match runtime.lifecycle_actions(PluginWillExit("log")) {
        Ok(actions) => assert_true(actions[0] is RuntimeEffect("log.flush"))
        Err(problems) => abort(problems.join(", "))
      }
      let json = runtime.lifecycle_hooks().unwrap()[0].event().to_json()
      assert_true(json.contains("\"kind\":\"plugin-setup\""))
      assert_true(json.contains("\"plugin\":\"log\""))
    }
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "plugin lifecycle validation rejects wrong plugin ownership" {
  let plugin = @lepusa.Plugin::new("log").with_lifecycle(
    PluginReady("other"),
    @lepusa.Cmd::effect("bad"),
  )
  let problems = plugin.validate()
  assert_eq(
    problems[0],
    "plugin lifecycle hook belongs to another plugin: other",
  )
}

///|
test "app lifecycle validation rejects missing plugin targets" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(source=@lepusa.Source::html("<main></main>"))
    .with_lifecycle(PluginSetup("missing"), @lepusa.Cmd::effect("missing"))
  let problems = app.validate()
  assert_true(problems.contains("lifecycle plugin not found: missing"))
}
