# @lepusa/plugins/shell

`@lepusa/plugins/shell` defines Lepusa's official shell command contract.
It is intentionally a declaration package: native runtimes own process
execution, lifecycle management, and platform-specific restrictions.

```moonbit nocheck
///|
test "declare shell access" {
  let plugin = @shell.plugin()
  assert_true(plugin.command_routes().contains("shell.execute"))
  assert_true(plugin.command_routes().contains("shell.spawn"))

  let grant = @shell.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Shell))
}
```
