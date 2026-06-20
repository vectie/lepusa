# @lepusa/plugins/notification

`@lepusa/plugins/notification` defines Lepusa's official notification command
contract. It includes sync permission/show handlers backed by an in-process
`NotificationCenter`, plus an auto registry that uses native macOS/Linux
delivery when the host exposes it.

```moonbit nocheck
///|
test "declare notification access" {
  let plugin = @notification.plugin()
  assert_true(plugin.command_routes().contains("notification.show"))
  assert_true(
    plugin.command_routes().contains("notification.requestPermission"),
  )

  let grant = @notification.capability_for_window("main")
  assert_true(
    grant.allows(window_label="main", permission=@lepusa.Notification),
  )

  let registry = @notification.registry()
  assert_true(registry.contains("notification.permissionState"))

  let runtime_registry = @notification.auto_registry()
  assert_true(runtime_registry.contains("notification.show"))
}
```
