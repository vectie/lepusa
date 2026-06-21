///|
fn authorization_test_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core").command_sync("read").command_sync("write"),
    )
    .with_capability(
      @lepusa.Capability::new("main")
      .window("main")
      .origin("https://app.example")
      .command("core.read")
      .command("core.write"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
fn platform_authorization_plan(platform : String) -> @lepusa.RuntimePlan {
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
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless(platform~)) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
fn authorization_request(
  route : String,
  window_label? : String = "main",
  origin? : String = "https://app.example",
) -> @lepusa.InvokeRequest {
  let mut plugin = ""
  let mut command = ""
  let mut found_separator = false
  for char in route {
    if !found_separator && char == '.' {
      found_separator = true
    } else if found_separator {
      command = command + char.to_string()
    } else {
      plugin = plugin + char.to_string()
    }
  }
  @lepusa.InvokeRequest::new(id="1", window_label~, plugin~, command~, origin~)
}

///|
test "runtime invoke authorization explains route decisions" {
  let plan = authorization_test_plan()
  let allowed = plan.authorize_invoke(
    authorization_request("core.read"),
    registered_routes=["core.read"],
    check_registered=true,
  )
  assert_true(allowed.kind() is RuntimeInvokeAuthorized)
  assert_eq(allowed.allowed(), true)
  assert_eq(allowed.permission().unwrap().name(), "custom:core.read")
  assert_eq(allowed.registered(), true)
  assert_eq(allowed.capability(), "main")
  assert_true(allowed.to_json().contains("\"kind\":\"authorized\""))

  let unregistered = plan.authorize_invoke(
    authorization_request("core.write"),
    registered_routes=["core.read"],
    check_registered=true,
  )
  assert_true(unregistered.kind() is RuntimeInvokeUnregisteredCommand)
  assert_eq(unregistered.allowed(), false)
  assert_eq(unregistered.registered(), false)
  assert_true(unregistered.reason().contains("no registered native handler"))

  let denied_window = plan.authorize_invoke(
    authorization_request("core.read", window_label="settings"),
    registered_routes=["core.read"],
    check_registered=true,
  )
  assert_true(denied_window.kind() is RuntimeInvokePermissionDenied)
  assert_true(denied_window.reason().contains("permission denied for window"))

  let denied_origin = plan.authorize_invoke(
    authorization_request("core.read", origin="https://evil.example"),
    registered_routes=["core.read"],
    check_registered=true,
  )
  assert_true(denied_origin.kind() is RuntimeInvokePermissionDenied)
  assert_true(denied_origin.reason().contains("https://evil.example"))

  let unknown = plan.authorize_invoke(
    authorization_request("core.missing"),
    registered_routes=["core.read"],
    check_registered=true,
  )
  assert_true(unknown.kind() is RuntimeInvokeUnknownCommand)
  assert_true(unknown.to_response("1").error_kind() is Some(UnknownCommand))
}

///|
test "runtime invoke authorization enforces platform-scoped capabilities" {
  let linux = platform_authorization_plan("linux")
  assert_eq(linux.platform(), "linux")
  let allowed = linux.authorize_invoke(
    authorization_request("shell.open", origin=""),
    registered_routes=["shell.open"],
    check_registered=true,
  )
  if !(allowed.kind() is RuntimeInvokeAuthorized) {
    abort(allowed.to_json())
  }
  assert_eq(allowed.capability(), "linux-shell")

  let macos = platform_authorization_plan("macos")
  assert_eq(macos.platform(), "macos")
  let denied = macos.authorize_invoke(
    authorization_request("shell.open", origin=""),
    registered_routes=["shell.open"],
    check_registered=true,
  )
  assert_true(denied.kind() is RuntimeInvokePermissionDenied)
  assert_true(denied.reason().contains("platform macos"))
}
