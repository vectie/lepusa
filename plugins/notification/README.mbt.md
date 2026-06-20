# @lepusa/plugins/notification

`@lepusa/plugins/notification` defines Lepusa's official notification command
contract. It includes async permission/show handlers backed by an in-process
`NotificationCenter`. Native runtimes can replace that registry with OS
notification integration.

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
}
```
