# @lepusa/plugins/process

`@lepusa/plugins/process` defines Lepusa's official process command contract.
It declares platform-neutral routes for process metadata, environment access,
and controlled process termination; native runtimes own the actual OS behavior.

```moonbit nocheck
///|
test "declare process access" {
  let plugin = @process.plugin()
  assert_true(plugin.command_routes().contains("process.info"))
  assert_true(plugin.command_routes().contains("process.env"))

  let grant = @process.info_capability().window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.ProcessInfo))
}
```
