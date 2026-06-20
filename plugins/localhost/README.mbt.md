# @lepusa/plugins/localhost

`@lepusa/plugins/localhost` defines Lepusa's official local service command
contract. It declares platform-neutral routes for service status, lifecycle,
and readiness checks. Its portable registry reports configured service
metadata and delegated lifecycle actions; native runtimes own process
supervision and HTTP probing.

```moonbit nocheck
///|
test "declare localhost access" {
  let plugin = @localhost.plugin()
  assert_true(plugin.command_routes().contains("localhost.status"))
  assert_true(plugin.command_routes().contains("localhost.waitUntilReady"))

  let grant = @localhost.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Localhost))

  let service = @lepusa.LocalService::new(
    "api",
    command=["moon", "run", "cmd/main"],
    readiness_url="http://127.0.0.1:8080/health",
  )
  let registry = @localhost.registry(
    policy=@localhost.LocalhostPolicy::new(services=[service]),
  )
  assert_true(registry.contains("localhost.status"))
}
```
