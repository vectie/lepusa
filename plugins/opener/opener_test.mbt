///|
test "opener plugin declares async opener commands" {
  let declared = plugin()
  assert_eq(declared.name(), "opener")
  assert_eq(declared.command_routes().length(), 3)
  assert_true(declared.command_routes().contains("opener.openUrl"))
  assert_true(declared.command_routes().contains("opener.openPath"))
  assert_true(declared.command_routes().contains("opener.revealPath"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
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
