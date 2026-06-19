///|
test "dialog plugin declares async dialog commands" {
  let declared = plugin()
  assert_eq(declared.name(), "dialog")
  assert_eq(declared.command_routes().length(), 3)
  assert_true(declared.command_routes().contains("dialog.message"))
  assert_true(declared.command_routes().contains("dialog.confirm"))
  assert_true(declared.command_routes().contains("dialog.prompt"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Dialog)
  assert_true(commands[1].permission() is Dialog)
}

///|
test "dialog capabilities grant dialog permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Dialog))
  assert_false(grant.allows(window_label="settings", permission=Dialog))
  assert_false(grant.allows(window_label="main", permission=Clipboard))
}
