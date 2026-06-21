///|
test "window plugin declares sync window commands" {
  let declared = plugin()
  assert_eq(declared.name(), "window")
  assert_true(declared.command_routes().contains("window.close"))
  assert_true(declared.command_routes().contains("window.focus"))
  assert_true(declared.command_routes().contains("window.hide"))
  assert_true(declared.command_routes().contains("window.maximize"))
  assert_true(declared.command_routes().contains("window.minimize"))
  assert_true(declared.command_routes().contains("window.setFullscreen"))
  assert_true(declared.command_routes().contains("window.setPosition"))
  assert_true(declared.command_routes().contains("window.setSize"))
  assert_true(declared.command_routes().contains("window.setTitle"))
  assert_true(declared.command_routes().contains("window.show"))
  assert_true(declared.command_routes().contains("window.unmaximize"))
  assert_true(declared.command_routes().contains("window.onCloseRequested"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Sync)
  assert_true(commands[0].permission() is Window)
  assert_true(commands[11].mode() is Event)
}

///|
test "window capabilities grant window permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Window))
  assert_false(grant.allows(window_label="settings", permission=Window))
  assert_false(grant.allows(window_label="main", permission=WindowState))
}

///|
test "window control policy validates allowed window labels" {
  let policy = WindowControlPolicy::new(allowed_windows=["main", "settings"])
  assert_eq(policy.validate().length(), 0)
  assert_true(policy.allows("main"))
  assert_false(policy.allows("other"))
  let bad = WindowControlPolicy::new(allowed_windows=[
    "", "main/child", "main", "main",
  ])
  let problems = bad.validate()
  assert_true(
    problems.contains("window control allowed window label is required"),
  )
  assert_true(
    problems.contains(
      "window control allowed window label is invalid: main/child",
    ),
  )
  assert_true(
    problems.contains("window control allowed window must be unique: main"),
  )
}

///|
test "window registry records control operations" {
  let state = WindowControlState::new()
  let registry = registry(
    policy=WindowControlPolicy::new(allowed_windows=["main"]),
    state~,
  )
  assert_true(registry.contains("window.setTitle"))
  assert_true(registry.contains("window.close"))
  assert_eq(registry.sync_routes().length(), 11)
  let grant = capability_for_window("main")
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="window",
      command="setTitle",
      payload="{\"windowLabel\":\"main\",\"title\":\"Dashboard\"}",
    ),
    capabilities=[grant],
  )
  assert_true(response is InvokeOk("1", _))
  assert_true(
    response.payload().unwrap_or("").contains("\"status\":\"queued\""),
  )
  assert_true(
    response.payload().unwrap_or("").contains("\"action\":\"setTitle\""),
  )
  assert_eq(state.operations().length(), 1)
  let operation = state.last().unwrap()
  assert_eq(operation.window_label(), "main")
  assert_true(operation.action() is SetTitle)
  assert_true(operation.payload().contains("\"Dashboard\""))
  let denied = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="2",
      window_label="main",
      plugin="window",
      command="focus",
      payload="{\"windowLabel\":\"settings\"}",
    ),
    capabilities=[grant],
  )
  assert_eq(
    denied.error_message().unwrap_or(""),
    "window control is not allowed for window: settings",
  )
}

///|
test "window registry validates payload shape" {
  let registry = registry()
  let grant = capability()
  let invalid = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="window",
      command="show",
      payload="[]",
    ),
    capabilities=[grant],
  )
  assert_eq(
    invalid.error_message().unwrap_or(""),
    "window control payload must be a string or object",
  )
  let unsafe_label = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="2",
      window_label="main",
      plugin="window",
      command="show",
      payload="\"../main\"",
    ),
    capabilities=[grant],
  )
  assert_eq(
    unsafe_label.error_message().unwrap_or(""),
    "window control windowLabel is invalid: ../main",
  )
}
