///|
fn security_profile_test_app(
  grant_write? : Bool = true,
  origin? : String = "https://app.example",
) -> @lepusa.App {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .window(label="settings", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("fs")
      .command_sync("read", permission=FileSystemRead)
      .command_async("write", permission=FileSystemWrite),
    )
    .with_capability(
      @lepusa.Capability::new("main-read")
      .window("main")
      .origin(origin)
      .permission(FileSystemRead)
      .path_scope(root="/app/data"),
    )
  if grant_write {
    app.with_capability(
      @lepusa.Capability::new("settings-write")
      .window("settings")
      .origin(origin)
      .permission(FileSystemWrite)
      .path_scope(root="/app/data", writable=true),
    )
  } else {
    app
  }
}

///|
fn security_profile_test_plan(
  grant_write? : Bool = true,
  origin? : String = "https://app.example",
) -> @lepusa.RuntimePlan {
  match
    security_profile_test_app(grant_write~, origin~).runtime_plan(
      config=@lepusa.RuntimeConfig::headless(),
    ) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
fn security_profile_request(
  route : String,
  window_label? : String = "main",
  origin? : String = "https://app.example",
) -> @lepusa.InvokeRequest {
  let mut plugin = ""
  let mut command = ""
  let mut after_dot = false
  for char in route {
    if !after_dot && char == '.' {
      after_dot = true
    } else if after_dot {
      command = command + char.to_string()
    } else {
      plugin = plugin + char.to_string()
    }
  }
  @lepusa.InvokeRequest::new(id="1", window_label~, plugin~, command~, origin~)
}

///|
test "security profile compiles route exposure and diagnostics" {
  let profile = security_profile_test_plan().security_profile(
    registered_routes=["fs.read", "fs.write"],
    check_handlers=true,
  )
  assert_true(profile.ok())
  assert_eq(profile.error_count(), 0)
  assert_eq(profile.warning_count(), 0)
  assert_eq(profile.info_count(), 0)
  let registered = profile.registered_routes()
  assert_eq(registered.length(), 2)
  assert_eq(registered[0], "fs.read")
  assert_eq(registered[1], "fs.write")
  let exposed = profile.exposed_routes()
  assert_eq(exposed.length(), 2)
  assert_eq(exposed[0], "fs.read")
  assert_eq(exposed[1], "fs.write")
  assert_eq(profile.denied_routes().length(), 0)
  assert_eq(profile.unused_permissions().length(), 0)
  assert_true(profile.check_handlers())
  assert_true(profile.to_json().contains("\"checkHandlers\":true"))
  assert_true(profile.to_json().contains("\"capabilityReport\""))
  assert_true(profile.to_json().contains("\"runtimeAudit\""))
}

///|
test "security profile keeps build-time and live handler checks distinct" {
  let plan = security_profile_test_plan()
  let declared = plan.security_profile()
  assert_true(declared.ok())
  let declared_routes = declared.exposed_routes()
  assert_eq(declared_routes.length(), 2)
  assert_eq(declared_routes[0], "fs.read")
  assert_eq(declared_routes[1], "fs.write")
  assert_false(declared.check_handlers())

  let live = plan.security_profile(
    registered_routes=["fs.read"],
    check_handlers=true,
  )
  assert_false(live.ok())
  assert_eq(live.error_count(), 1)
  assert_eq(live.exposed_routes().length(), 1)
  assert_eq(live.exposed_routes()[0], "fs.read")
  assert_true(live.problems()[0].contains("no native handler"))
  let authorization = live.authorize_invoke(
    security_profile_request("fs.write", window_label="settings"),
  )
  assert_true(authorization.kind() is RuntimeInvokeUnregisteredCommand)
  assert_eq(authorization.registered(), false)
}

///|
test "security profile authorizes invoke requests by route window and origin" {
  let profile = security_profile_test_plan().security_profile(
    registered_routes=["fs.read", "fs.write"],
    check_handlers=true,
  )
  let allowed = profile.authorize_invoke(security_profile_request("fs.read"))
  assert_true(allowed.kind() is RuntimeInvokeAuthorized)
  assert_eq(allowed.capability(), "main-read")
  assert_eq(allowed.permission().unwrap().name(), "filesystem.read")

  let denied_window = profile.authorize_invoke(
    security_profile_request("fs.read", window_label="settings"),
  )
  assert_true(denied_window.kind() is RuntimeInvokePermissionDenied)
  assert_true(denied_window.reason().contains("permission denied for window"))

  let denied_origin = profile.authorize_invoke(
    security_profile_request("fs.read", origin="https://evil.example"),
  )
  assert_true(denied_origin.kind() is RuntimeInvokePermissionDenied)
  assert_true(denied_origin.reason().contains("https://evil.example"))

  let unknown = profile.authorize_invoke(security_profile_request("fs.delete"))
  assert_true(unknown.kind() is RuntimeInvokeUnknownCommand)
}

///|
test "security profile authorizes operation scopes through command permissions" {
  let profile = security_profile_test_plan().security_profile(
    registered_routes=["fs.read", "fs.write"],
    check_handlers=true,
  )
  let read_inside = profile.authorize_operation(
    security_profile_request("fs.read"),
    @lepusa.OperationScope::path(root="/app/data/config.json"),
  )
  assert_true(read_inside.kind() is RuntimeInvokeAuthorized)

  let read_write = profile.authorize_operation(
    security_profile_request("fs.read"),
    @lepusa.OperationScope::path(root="/app/data/config.json", writable=true),
  )
  assert_true(read_write.kind() is RuntimeInvokePermissionDenied)
  assert_true(read_write.reason().contains("operation scope denied"))

  let write_inside = profile.authorize_operation(
    security_profile_request("fs.write", window_label="settings"),
    @lepusa.OperationScope::path(root="/app/data/config.json", writable=true),
  )
  assert_true(write_inside.kind() is RuntimeInvokeAuthorized)

  let write_outside = profile.authorize_operation(
    security_profile_request("fs.write", window_label="settings"),
    @lepusa.OperationScope::path(root="/app/cache/config.json", writable=true),
  )
  assert_true(write_outside.kind() is RuntimeInvokePermissionDenied)
}

///|
test "app manager exposes live security profile from its registry" {
  let registry = @lepusa.CommandRegistry::new().register_fn("fs.read", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  let manager = match
    security_profile_test_app().manager(
      config=@lepusa.RuntimeConfig::headless(),
      registry~,
    ) {
    Ok(manager) => manager
    Err(problems) => abort(problems.join(", "))
  }
  let profile = manager.security_profile()
  assert_false(profile.ok())
  assert_true(profile.check_handlers())
  assert_eq(profile.registered_routes().length(), 1)
  assert_eq(profile.registered_routes()[0], "fs.read")
  assert_eq(profile.exposed_routes().length(), 1)
  assert_eq(profile.exposed_routes()[0], "fs.read")
  assert_true(profile.problems()[0].contains("fs.write"))
}
