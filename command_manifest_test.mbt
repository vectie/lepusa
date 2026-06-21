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
      .command_sync(
        "read",
        permission=FileSystemRead,
        request=@lepusa.IpcSchema::object(
          "ReadRequest", "{ readonly path: string }",
        ),
        response=@lepusa.IpcSchema::string(),
        affinity=MainThread,
      )
      .command_async("write", permission=FileSystemWrite, affinity=WorkerThread)
      .command_stream("events", permission=Notification),
    )
    .with_capability(
      @lepusa.Capability::new("main-read")
      .window("main")
      .origin("https://app.example")
      .permission(FileSystemRead),
    )
    .with_capability(
      @lepusa.Capability::new("settings-write")
      .window("settings")
      .platform("linux")
      .permission(FileSystemWrite),
    )
    .with_capability(
      @lepusa.Capability::new("all-events").permission(Notification),
    )
  match
    app.runtime_plan(config=@lepusa.RuntimeConfig::headless(platform="linux")) {
    Ok(plan) => {
      let manifest = plan.command_manifest()
      assert_eq(manifest.entries().length(), 3)
      assert_eq(manifest.routes()[0], "core.read")
      assert_eq(manifest.routes_by_mode(Sync)[0], "core.read")
      assert_eq(manifest.routes_by_mode(Async)[0], "core.write")
      assert_eq(manifest.routes_by_mode(Stream)[0], "core.events")
      assert_eq(manifest.routes_by_affinity(MainThread)[0], "core.read")
      assert_eq(manifest.routes_by_affinity(WorkerThread)[0], "core.write")
      match manifest.entry("core.read") {
        Some(entry) => {
          assert_eq(entry.plugin(), "core")
          assert_eq(entry.command(), "read")
          assert_true(entry.mode() is Sync)
          assert_true(entry.affinity() is MainThread)
          assert_true(entry.permission() is FileSystemRead)
          assert_eq(entry.allowed_windows().length(), 1)
          assert_eq(entry.allowed_origins().length(), 1)
          assert_eq(entry.allowed_platforms().length(), 0)
          assert_eq(entry.allowed_origins()[0], "https://app.example")
          assert_true(entry.allowed_in_window("main"))
          assert_false(entry.allowed_in_window("settings"))
          assert_true(entry.allowed_for_origin("https://app.example"))
          assert_false(entry.allowed_for_origin("https://evil.example"))
          assert_eq(entry.request_schema().name(), "ReadRequest")
          assert_eq(
            entry.request_schema().typescript(),
            "{ readonly path: string }",
          )
          assert_eq(entry.response_schema().typescript(), "string")
          assert_true(entry.to_json().contains("\"mode\":\"sync\""))
          assert_true(entry.to_json().contains("\"affinity\":\"main-thread\""))
          assert_true(entry.to_json().contains("\"requestSchema\""))
          assert_true(entry.to_json().contains("\"responseSchema\""))
          assert_true(entry.to_json().contains("\"allowedOrigins\""))
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
      match manifest.entry("core.write") {
        Some(entry) => {
          assert_eq(entry.allowed_platforms().length(), 1)
          assert_eq(entry.allowed_platforms()[0], "linux")
          assert_true(entry.allowed_on_platform("linux"))
          assert_false(entry.allowed_on_platform("macos"))
        }
        None => abort("missing write command")
      }
      assert_true(plan.command_manifest().to_json().contains("\"commands\""))
      assert_true(
        plan.command_manifest().to_json().contains("\"allowedPlatforms\""),
      )
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime command manifest denies platform-specific grants off target" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("shell").command_sync("open", permission=Shell),
    )
    .with_capability(
      @lepusa.Capability::new("linux-shell")
      .window("main")
      .platform("linux")
      .permission(Shell),
    )
  match
    app.runtime_plan(config=@lepusa.RuntimeConfig::headless(platform="macos")) {
    Ok(plan) => {
      let manifest = plan.command_manifest()
      match manifest.entry("shell.open") {
        Some(entry) => {
          assert_eq(entry.allowed_windows().length(), 0)
          assert_eq(entry.allowed_platforms().length(), 0)
        }
        None => abort("missing shell command")
      }
      assert_false(
        manifest.allows("shell.open", window_label="main", platform="macos"),
      )
      assert_eq(plan.window_command_routes("main").length(), 0)
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

///|
test "permission manifest groups routes grants windows and denials" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .window(label="settings", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync("read", permission=FileSystemRead)
      .command_async("write", permission=FileSystemWrite)
      .command_sync("admin", permission=Shell),
    )
    .with_capability(
      @lepusa.Capability::new("read-main")
      .window("main")
      .origin("https://app.example")
      .permission(FileSystemRead)
      .path_scope(root="/app/data"),
    )
    .with_capability(
      @lepusa.Capability::new("write-settings")
      .window("settings")
      .permission(FileSystemWrite)
      .path_scope(root="/app/data", writable=true),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let manifest = plan.permission_manifest()
      assert_true(manifest.permission_names().contains("filesystem.read"))
      assert_true(manifest.permission_names().contains("filesystem.write"))
      assert_true(manifest.permission_names().contains("shell"))
      match manifest.permission("filesystem.read") {
        Some(permission) => {
          assert_eq(permission.commands().length(), 1)
          assert_eq(permission.grants().length(), 1)
          assert_true(permission.allowed_windows().contains("main"))
          assert_eq(permission.allowed_origins().length(), 1)
          assert_eq(permission.allowed_origins()[0], "https://app.example")
          assert_eq(permission.allowed_platforms().length(), 0)
          assert_eq(permission.commands()[0].allowed_origins().length(), 1)
          assert_true(permission.commands()[0].affinity() is AnyThread)
          assert_eq(permission.grants()[0].origins().length(), 1)
          assert_eq(permission.grants()[0].platforms().length(), 0)
          assert_eq(permission.grants()[0].operation_scopes().length(), 1)
          assert_eq(
            permission.grants()[0].operation_scopes()[0].root(),
            "/app/data",
          )
          assert_eq(permission.denied_routes().length(), 0)
          assert_true(
            permission.to_json().contains("\"name\":\"filesystem.read\""),
          )
          assert_true(permission.to_json().contains("\"allowedOrigins\""))
        }
        None => abort("missing read permission")
      }
      match manifest.permission("shell") {
        Some(permission) => {
          assert_eq(permission.commands()[0].route(), "core.admin")
          assert_eq(permission.allowed_windows().length(), 0)
          assert_true(permission.denied_routes().contains("core.admin"))
        }
        None => abort("missing shell permission")
      }
      assert_true(manifest.denied_routes().contains("core.admin"))
      assert_true(manifest.to_json().contains("\"permissions\""))
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "launch manifest exposes typed command manifest" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .window(label="settings", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync("read", permission=FileSystemRead)
      .command_stream("events", permission=Notification),
    )
    .with_capability(
      @lepusa.Capability::new("main-read")
      .window("main")
      .permission(FileSystemRead)
      .path_scope(root="/app/data"),
    )
    .with_capability(@lepusa.Capability::new("events").permission(Notification))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match plan.launch_manifest(registered_routes=["core.read"]) {
        Ok(manifest) => {
          assert_eq(manifest.command_manifest().entries().length(), 2)
          assert_true(
            manifest
            .permission_manifest()
            .permission_names()
            .contains("notification"),
          )
          match manifest.command_manifest().entry("core.events") {
            Some(entry) => {
              assert_true(entry.mode() is Stream)
              assert_eq(entry.allowed_windows().length(), 2)
            }
            None => abort("missing stream command")
          }
          let json = manifest.to_json()
          assert_true(json.contains("\"commandManifest\""))
          assert_true(json.contains("\"permissionManifest\""))
          assert_true(json.contains("\"route\":\"core.events\""))
          assert_true(json.contains("\"mode\":\"stream\""))
          assert_true(
            json.contains("\"allowedWindows\":[\"main\",\"settings\"]"),
          )
          assert_true(json.contains("\"operationScopes\""))
          assert_eq(manifest.capabilities()[0].operation_scopes().length(), 1)
          assert_eq(manifest.command_routes().length(), 2)
          assert_eq(manifest.registered_routes()[0], "core.read")
        }
        Err(_) => abort("unexpected invalid launch manifest")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}
