///|
test "opener plugin declares sync opener commands" {
  let declared = plugin()
  assert_eq(declared.name(), "opener")
  assert_eq(declared.command_routes().length(), 3)
  assert_true(declared.command_routes().contains("opener.openUrl"))
  assert_true(declared.command_routes().contains("opener.openPath"))
  assert_true(declared.command_routes().contains("opener.revealPath"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Sync)
  assert_true(commands[0].permission() is Opener)
  assert_true(commands[1].permission() is Opener)
}

///|
test "opener capabilities grant opener permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Opener))
  assert_false(grant.allows(window_label="settings", permission=Opener))
  assert_false(grant.allows(window_label="main", permission=Shell))
}

///|
test "opener plugin registers native handlers and validates payloads" {
  let registry = register(@lepusa.CommandRegistry::new())
  let capabilities = [capability_for_window("main")]
  assert_true(registry.contains("opener.openUrl"))
  assert_true(registry.contains("opener.openPath"))
  assert_true(registry.contains("opener.revealPath"))
  assert_eq(registry.sync_routes().length(), 3)
  let empty = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="opener",
      command="openUrl",
      payload="",
    ),
    capabilities~,
  )
  assert_true(empty is InvokeError("1", "opener openUrl payload is required"))
  let invalid = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="2",
      window_label="main",
      plugin="opener",
      command="openPath",
      payload="{",
    ),
    capabilities~,
  )
  assert_true(invalid is InvokeError("2", _))
  let missing = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="3",
      window_label="main",
      plugin="opener",
      command="revealPath",
      payload="{\"url\":\"file:///tmp/a\"}",
    ),
    capabilities~,
  )
  assert_true(
    missing is InvokeError("3", "opener revealPath target is required"),
  )
}
