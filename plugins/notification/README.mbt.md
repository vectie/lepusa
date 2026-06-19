# @lepusa/plugins/notification

`@lepusa/plugins/notification` defines Lepusa's official notification command
contract. It is a platform-neutral declaration package; native runtimes own the
actual OS notification implementation.

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
}
```
