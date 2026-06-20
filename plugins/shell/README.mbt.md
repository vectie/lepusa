# @lepusa/plugins/shell

`@lepusa/plugins/shell` defines Lepusa's official shell command contract.
It includes a portable async registry that validates command payloads, supports
an optional command allow-list, and tracks delegated spawned process state.
Native runtimes own actual process execution and platform-specific
restrictions.

```moonbit nocheck
///|
test "declare shell access" {
  let plugin = @shell.plugin()
  assert_true(plugin.command_routes().contains("shell.execute"))
  assert_true(plugin.command_routes().contains("shell.spawn"))

  let grant = @shell.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Shell))

  let registry = @shell.registry(
    policy=@shell.ShellPolicy::new(allowed_commands=["moon"]),
  )
  assert_true(registry.contains("shell.kill"))
}
```
