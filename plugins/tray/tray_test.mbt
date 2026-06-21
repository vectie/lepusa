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
  assert_true(commands[0].mode() is Sync)
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

///|
test "tray registry tracks delegated tray state" {
  let state = TrayState::new()
  let registry = registry(state~)
  let grant = capability_for_window("main")
  let icon_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="tray",
    command="setIcon",
    payload="{\"iconPath\":\"assets/tray.png\"}",
  )
  let icon = registry.dispatch(icon_request, capabilities=[grant])
  assert_true(icon.payload().unwrap_or("").contains("\"status\":\"delegated\""))
  assert_true(state.icon_path() is Some("assets/tray.png"))
  let tooltip_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="tray",
    command="setTooltip",
    payload="\"Lepusa\"",
  )
  let tooltip = registry.dispatch(tooltip_request, capabilities=[grant])
  assert_true(
    tooltip.payload().unwrap_or("").contains("\"tooltip\":\"Lepusa\""),
  )
  assert_true(state.tooltip() is Some("Lepusa"))
  let menu_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="tray",
    command="setMenu",
    payload="{ \"items\": [ { \"id\": \"open\", \"label\": \"Open\" }, { \"kind\": \"separator\" }, { \"kind\": \"check\", \"id\": \"launch\", \"label\": \"Launch at login\", \"checked\": true } ] }",
  )
  let menu = registry.dispatch(menu_request, capabilities=[grant])
  assert_true(menu.payload().unwrap_or("").contains("\"kind\":\"check\""))
  assert_eq(state.menu().length(), 3)
  assert_true(state.menu()[2].kind() is Check)
  assert_true(state.menu()[2].checked())
  let visible_request = @lepusa.InvokeRequest::new(
    id="4",
    window_label="main",
    plugin="tray",
    command="setVisible",
    payload="false",
  )
  let visible = registry.dispatch(visible_request, capabilities=[grant])
  assert_true(visible.payload().unwrap_or("").contains("\"visible\":false"))
  assert_false(state.visible())
  let destroy_request = @lepusa.InvokeRequest::new(
    id="5",
    window_label="main",
    plugin="tray",
    command="destroy",
  )
  let destroyed = registry.dispatch(destroy_request, capabilities=[grant])
  assert_true(destroyed.payload().unwrap_or("").contains("\"destroyed\":true"))
  assert_true(state.destroyed())
  assert_false(state.visible())
}

///|
test "tray registry rejects invalid delegated state" {
  let registry = registry()
  let grant = capability_for_window("main")
  let bad_icon_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="tray",
    command="setIcon",
    payload="{\"iconPath\":\"assets\\\\tray.png\"}",
  )
  let bad_icon = registry.dispatch(bad_icon_request, capabilities=[grant])
  assert_eq(
    bad_icon.error_message().unwrap_or(""),
    "tray icon path must use forward slashes",
  )
  let duplicate_menu_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="tray",
    command="setMenu",
    payload="[ { \"id\": \"open\", \"label\": \"Open\" }, { \"id\": \"open\", \"label\": \"Open again\" } ]",
  )
  let duplicate_menu = registry.dispatch(duplicate_menu_request, capabilities=[
    grant,
  ])
  assert_eq(
    duplicate_menu.error_message().unwrap_or(""),
    "tray menu item must be unique: open",
  )
}
