///|
test "command modes expose stable manifest names" {
  assert_eq(@lepusa.Sync.name(), "sync")
  assert_eq(@lepusa.Async.name(), "async")
  assert_eq(@lepusa.Stream.name(), "stream")
  assert_eq(@lepusa.Event.name(), "event")
}

///|
test "runtime command manifest projects modes permissions and windows" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .window(label="settings", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync("read", permission=FileSystemRead)
      .command_async("write", permission=FileSystemWrite)
      .command_stream("events", permission=Notification),
    )
    .with_capability(
      @lepusa.Capability::new("main-read")
      .window("main")
      .permission(FileSystemRead),
    )
    .with_capability(
      @lepusa.Capability::new("settings-write")
      .window("settings")
      .permission(FileSystemWrite),
    )
    .with_capability(
      @lepusa.Capability::new("all-events").permission(Notification),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let manifest = plan.command_manifest()
      assert_eq(manifest.entries().length(), 3)
      assert_eq(manifest.routes()[0], "core.read")
      assert_eq(manifest.routes_by_mode(Sync)[0], "core.read")
      assert_eq(manifest.routes_by_mode(Async)[0], "core.write")
      assert_eq(manifest.routes_by_mode(Stream)[0], "core.events")
      match manifest.entry("core.read") {
        Some(entry) => {
          assert_eq(entry.plugin(), "core")
          assert_eq(entry.command(), "read")
          assert_true(entry.mode() is Sync)
          assert_true(entry.permission() is FileSystemRead)
          assert_eq(entry.allowed_windows().length(), 1)
          assert_true(entry.allowed_in_window("main"))
          assert_false(entry.allowed_in_window("settings"))
          assert_true(entry.to_json().contains("\"mode\":\"sync\""))
        }
        None => abort("missing read command")
      }
      match manifest.entry("core.events") {
        Some(entry) => {
          assert_eq(entry.allowed_windows().length(), 2)
          assert_true(entry.allowed_in_window("main"))
          assert_true(entry.allowed_in_window("settings"))
        }
        None => abort("missing events command")
      }
      assert_eq(manifest.allowed_routes("main").length(), 2)
      assert_true(manifest.allowed_routes("main").contains("core.read"))
      assert_true(manifest.allowed_routes("main").contains("core.events"))
      assert_eq(plan.window_command_routes("settings").length(), 2)
      assert_true(plan.window_command_routes("settings").contains("core.write"))
      assert_true(plan.command_manifest().to_json().contains("\"commands\""))
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "command manifest can be constructed directly" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("dialog").command_event("opened", permission=Dialog),
    )
    .with_capability(@lepusa.Capability::new("dialog").permission(Dialog))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let manifest = @lepusa.CommandManifest::from_plugins(
        plugins=plan
          .command_manifest()
          .entries()
          .map(fn(entry) {
            @lepusa.Plugin::new(entry.plugin()).command(
              entry.command(),
              mode=entry.mode(),
              permission=entry.permission(),
            )
          }),
        capabilities=plan.capabilities(),
        windows=plan.windows(),
      )
      match manifest.entry("dialog.opened") {
        Some(entry) => {
          assert_true(entry.mode() is Event)
          assert_eq(entry.permission().name(), "dialog")
        }
        None => abort("missing direct manifest entry")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}
