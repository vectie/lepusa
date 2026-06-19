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
  assert_true(dispatch("load") is @lepusa.Effect("load"))
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
test "plugins expose command metadata without owning app domain behavior" {
  let plugin = @lepusa.Plugin::new("workspace")
    .command_sync("read_config")
    .command_stream("events")
  assert_eq(plugin.name(), "workspace")
  let command_names = plugin.command_names()
  assert_eq(command_names.length(), 2)
  assert_eq(command_names[0], "read_config")
  assert_eq(command_names[1], "events")
  assert_true(plugin.commands()[1].mode() is @lepusa.Stream)
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
    .permission(@lepusa.FileSystemRead)
  assert_eq(
    capability.allows(window_label="main", permission=@lepusa.FileSystemRead),
    true,
  )
  assert_eq(
    capability.allows(
      window_label="settings",
      permission=@lepusa.FileSystemRead,
    ),
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
  assert_true(
    @lepusa.InvokeResponse::ok("1", "{}") is @lepusa.InvokeOk("1", "{}"),
  )
}

///|
test "events can become runtime commands" {
  let event = @lepusa.Event::new("ready", payload="{\"ok\":true}")
  assert_eq(event.name(), "ready")
  assert_eq(event.validate().is_empty(), true)
  assert_true(
    @lepusa.Cmd::emit(event, target=@lepusa.WindowTarget("main"))
    is @lepusa.Emit(@lepusa.WindowTarget("main"), _),
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
    .with_capability(
      @lepusa.Capability::new("core").permission(@lepusa.Notification),
    )
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
