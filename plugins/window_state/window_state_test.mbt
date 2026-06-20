///|
test "window state plugin declares persistence commands" {
  let declared = plugin()
  assert_eq(declared.name(), "windowState")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("windowState.save"))
  assert_true(declared.command_routes().contains("windowState.restore"))
  assert_true(declared.command_routes().contains("windowState.clear"))
  assert_true(declared.command_routes().contains("windowState.get"))
  assert_true(declared.command_routes().contains("windowState.set"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is WindowState)
}

///|
test "window state capabilities grant permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=WindowState))
  assert_false(grant.allows(window_label="settings", permission=WindowState))
  assert_false(grant.allows(window_label="main", permission=AutoLaunch))
}

///|
test "window state policy validates persistence rules" {
  let policy = WindowStatePolicy::new(store_name="dev.local.lepusa")
    .rule(WindowStateRule::new(window_label="main"))
    .rule(
      WindowStateRule::new(window_label="settings", remember_visibility=true),
    )
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.store_name(), "dev.local.lepusa")
  assert_eq(policy.rules().length(), 2)
  assert_true(policy.rules()[0].remember_size())
  assert_true(policy.rules()[0].remember_position())
}

///|
test "window state policy rejects invalid metadata" {
  let policy = WindowStatePolicy::new(store_name="bad/name")
    .rule(WindowStateRule::new(window_label="main"))
    .rule(WindowStateRule::new(window_label="main"))
    .rule(
      WindowStateRule::new(
        window_label="bad label",
        remember_size=false,
        remember_position=false,
      ),
    )
  let problems = policy.validate()
  assert_true(problems.contains("window state store name is invalid: bad/name"))
  assert_true(problems.contains("window state rule must be unique: main"))
  assert_true(problems.contains("window state label is invalid: bad label"))
  assert_true(
    problems.contains("window state rule must remember at least one property"),
  )
}

///|
async test "window state plugin registers portable state handlers" {
  let store = WindowStateStore::new()
  let registry = register(@lepusa.CommandRegistry::new(), store~)
  assert_true(registry.contains("windowState.save"))
  assert_true(registry.contains("windowState.restore"))
  assert_true(registry.contains("windowState.clear"))
  assert_true(registry.contains("windowState.get"))
  assert_true(registry.contains("windowState.set"))
  let capability = capability_for_window("main")
  let set = registry.dispatch_async(
    @lepusa.InvokeRequest::new(
      id="set",
      window_label="main",
      plugin="windowState",
      command="set",
      payload="{\"window\":\"main\",\"width\":900,\"height\":640}",
    ),
    capabilities=[capability],
  )
  assert_true(set is InvokeOk("set", _))
  assert_true(set.payload().unwrap_or("").contains("\"status\":\"set\""))
  let get = registry.dispatch_async(
    @lepusa.InvokeRequest::new(
      id="get",
      window_label="main",
      plugin="windowState",
      command="get",
      payload="{\"window\":\"main\"}",
    ),
    capabilities=[capability],
  )
  assert_true(get is InvokeOk("get", _))
  assert_true(get.payload().unwrap_or("").contains("\"found\":true"))
  assert_true(get.payload().unwrap_or("").contains("\\\"width\\\":900"))
  let clear = registry.dispatch_async(
    @lepusa.InvokeRequest::new(
      id="clear",
      window_label="main",
      plugin="windowState",
      command="clear",
      payload="{\"window\":\"main\"}",
    ),
    capabilities=[capability],
  )
  assert_true(clear is InvokeOk("clear", _))
  assert_true(clear.payload().unwrap_or("").contains("\"cleared\":1"))
}
