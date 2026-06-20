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

///|
async test "notification registry tracks permission and delivered titles" {
  let center = NotificationCenter::new()
  let registry = registry(center~)
  assert_true(registry.contains("notification.show"))
  assert_true(registry.contains("notification.permissionState"))
  assert_true(registry.contains("notification.requestPermission"))
  assert_eq(registry.async_routes().length(), 3)
  let grant = capability_for_window("main")
  let initial_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="notification",
    command="permissionState",
  )
  let initial = registry.dispatch_async(initial_request, capabilities=[grant])
  assert_true(
    initial.payload().unwrap_or("").contains("\"permission\":\"default\""),
  )
  let granted_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="notification",
    command="requestPermission",
  )
  let granted = registry.dispatch_async(granted_request, capabilities=[grant])
  assert_true(
    granted.payload().unwrap_or("").contains("\"permission\":\"granted\""),
  )
  let shown_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="notification",
    command="show",
    payload="{\"title\":\"Build done\",\"body\":\"All checks passed\"}",
  )
  let shown = registry.dispatch_async(shown_request, capabilities=[grant])
  assert_true(shown.payload().unwrap_or("").contains("\"shown\":true"))
  assert_eq(center.delivered()[0], "Build done")
}
