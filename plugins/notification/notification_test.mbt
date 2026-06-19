///|
test "notification plugin declares async notification commands" {
  let declared = plugin()
  assert_eq(declared.name(), "notification")
  assert_eq(declared.command_routes().length(), 3)
  assert_true(declared.command_routes().contains("notification.show"))
  assert_true(
    declared.command_routes().contains("notification.permissionState"),
  )
  assert_true(
    declared.command_routes().contains("notification.requestPermission"),
  )
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Notification)
  assert_true(commands[1].permission() is Notification)
}

///|
test "notification capabilities grant notification permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Notification))
  assert_false(grant.allows(window_label="settings", permission=Notification))
  assert_false(grant.allows(window_label="main", permission=Clipboard))
}
