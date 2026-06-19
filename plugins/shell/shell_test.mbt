///|
test "shell plugin declares async shell commands" {
  let declared = plugin()
  assert_eq(declared.name(), "shell")
  assert_eq(declared.command_routes().length(), 4)
  assert_true(declared.command_routes().contains("shell.execute"))
  assert_true(declared.command_routes().contains("shell.spawn"))
  assert_true(declared.command_routes().contains("shell.kill"))
  assert_true(declared.command_routes().contains("shell.stdinWrite"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Shell)
  assert_true(commands[1].permission() is Shell)
}

///|
test "shell capabilities grant shell permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Shell))
  assert_false(grant.allows(window_label="settings", permission=Shell))
  assert_false(grant.allows(window_label="main", permission=Clipboard))
}
