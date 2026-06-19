///|
test "tray plugin declares status icon commands" {
  let declared = plugin()
  assert_eq(declared.name(), "tray")
  assert_eq(declared.command_routes().length(), 7)
  assert_true(declared.command_routes().contains("tray.setIcon"))
  assert_true(declared.command_routes().contains("tray.setTooltip"))
  assert_true(declared.command_routes().contains("tray.setMenu"))
  assert_true(declared.command_routes().contains("tray.showMenu"))
  assert_true(declared.command_routes().contains("tray.setVisible"))
  assert_true(declared.command_routes().contains("tray.destroy"))
  assert_true(declared.command_routes().contains("tray.onMenuItemClick"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[6].mode() is Event)
  assert_true(commands[0].permission() is Tray)
}

///|
test "tray capabilities grant permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Tray))
  assert_false(grant.allows(window_label="settings", permission=Tray))
  assert_false(grant.allows(window_label="main", permission=SingleInstance))
}

///|
test "tray policy validates menu metadata" {
  let policy = TrayPolicy::new(icon_path="assets/tray.png", tooltip="Lepusa")
    .item(TrayMenuItem::action(id="open", label="Open"))
    .item(TrayMenuItem::separator())
    .item(TrayMenuItem::check(id="launch_at_login", label="Launch at login"))
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.menu().length(), 3)
  assert_true(policy.menu()[2].kind() is Check)
}

///|
test "tray policy rejects invalid menu metadata" {
  let policy = TrayPolicy::new(icon_path="assets\\tray.png", tooltip="")
    .item(TrayMenuItem::action(id="", label="Open"))
    .item(TrayMenuItem::action(id="open/item", label="Open"))
    .item(TrayMenuItem::action(id="open", label="Open"))
    .item(TrayMenuItem::action(id="open", label="Again"))
  let problems = policy.validate()
  assert_true(problems.contains("tray icon path must use forward slashes"))
  assert_true(problems.contains("tray tooltip is required"))
  assert_true(problems.contains("tray menu item id is required"))
  assert_true(problems.contains("tray menu item id is invalid: open/item"))
  assert_true(problems.contains("tray menu item must be unique: open"))
}
