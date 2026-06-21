///|
test "capability compile report accepts coherent grants" {
  let app = @lepusa.new(
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .window(label="settings", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync("read", permission=FileSystemRead)
      .command_async("write", permission=FileSystemWrite),
    )
    .with_capability(
      @lepusa.Capability::new("main-read")
      .window("main")
      .permission(FileSystemRead)
      .path_scope(root="/app/data"),
    )
    .with_capability(
      @lepusa.Capability::new("settings-write")
      .window("settings")
      .permission(FileSystemWrite)
      .path_scope(root="/app/data", writable=true),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => {
      let report = plan.capability_report()
      assert_true(report.ok())
      assert_eq(report.error_count(), 0)
      assert_eq(report.warning_count(), 0)
      assert_eq(report.plugin_contracts().length(), 1)
      assert_eq(report.command_manifest().entries().length(), 2)
      assert_true(
        report
        .permission_manifest()
        .permission_names()
        .contains("filesystem.read"),
      )
      assert_eq(report.denied_routes().length(), 0)
      assert_eq(report.unused_permissions().length(), 0)
      assert_true(report.to_json().contains("\"ok\":true"))
      assert_true(report.to_json().contains("\"pluginContracts\""))
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "capability compile report catches missing and stale grants" {
  match
    @lepusa.WindowConfig::new(
      label="main",
      source=@lepusa.Source::html("<main></main>"),
    ).resolve() {
    Ok(window) => {
      let report = @lepusa.CapabilityCompileReport::from_plugins(
        plugins=[
          @lepusa.Plugin::new("core")
          .command_sync("read", permission=FileSystemRead)
          .command_async("write", permission=FileSystemWrite)
          .command_sync("admin", permission=Shell),
        ],
        capabilities=[
          @lepusa.Capability::new("main-read")
          .window("main")
          .permission(FileSystemRead),
          @lepusa.Capability::new("stale-write")
          .window("ghost")
          .permission(FileSystemWrite),
          @lepusa.Capability::new("unused-net").permission(Network),
          @lepusa.Capability::new("empty"),
        ],
        windows=[window],
      )
      assert_false(report.ok())
      assert_true(report.error_count() >= 4)
      assert_eq(report.warning_count(), 4)
      assert_true(report.denied_routes().contains("core.write"))
      assert_true(report.denied_routes().contains("core.admin"))
      assert_true(report.unknown_windows().contains("ghost"))
      assert_true(report.unused_permissions().contains("network"))
      let codes = report.issues().map(fn(issue) { issue.code() })
      assert_true(codes.contains("unknown-window"))
      assert_true(codes.contains("permission-ungranted"))
      assert_true(codes.contains("permission-unused"))
      assert_true(codes.contains("capability-invalid"))
      assert_true(codes.contains("operation-scope-missing"))
      let json = report.to_json()
      assert_true(json.contains("\"ok\":false"))
      assert_true(json.contains("\"code\":\"unknown-window\""))
      assert_true(json.contains("\"route\":\"core.admin\""))
    }
    Err(_) => abort("unexpected invalid window")
  }
}

///|
test "capability compile report includes plugin contract errors" {
  match
    @lepusa.WindowConfig::new(
      label="main",
      source=@lepusa.Source::html("<main></main>"),
    ).resolve() {
    Ok(window) => {
      let report = @lepusa.CapabilityCompileReport::from_plugins(
        plugins=[
          @lepusa.Plugin::new("dup")
          .command_sync("read", permission=FileSystemRead)
          .command_async("read", permission=FileSystemWrite),
        ],
        capabilities=[
          @lepusa.Capability::new("main-read")
          .window("main")
          .permission(FileSystemRead),
        ],
        windows=[window],
      )
      assert_false(report.ok())
      let codes = report.issues().map(fn(issue) { issue.code() })
      assert_true(codes.contains("plugin-invalid"))
      assert_true(report.to_json().contains("plugin command must be unique"))
    }
    Err(_) => abort("unexpected invalid window")
  }
}
