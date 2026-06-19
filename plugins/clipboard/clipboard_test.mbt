///|
test "clipboard plugin declares async clipboard commands" {
  let declared = plugin()
  assert_eq(declared.name(), "clipboard")
  assert_eq(declared.command_routes().length(), 3)
  assert_true(declared.command_routes().contains("clipboard.readText"))
  assert_true(declared.command_routes().contains("clipboard.writeText"))
  assert_true(declared.command_routes().contains("clipboard.clear"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Clipboard)
  assert_true(commands[1].permission() is Clipboard)
}

///|
test "clipboard capabilities grant clipboard permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Clipboard))
  assert_false(grant.allows(window_label="settings", permission=Clipboard))
  assert_false(grant.allows(window_label="main", permission=Dialog))
}
