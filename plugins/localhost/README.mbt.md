# @lepusa/plugins/localhost

`@lepusa/plugins/localhost` defines Lepusa's official local service command
contract. It declares platform-neutral routes for service status, lifecycle,
and readiness checks; native runtimes own process supervision and HTTP probing.

```moonbit nocheck
///|
test "declare localhost access" {
  let plugin = @localhost.plugin()
  assert_true(plugin.command_routes().contains("localhost.status"))
  assert_true(plugin.command_routes().contains("localhost.waitUntilReady"))

  let grant = @localhost.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Localhost))
}
```
