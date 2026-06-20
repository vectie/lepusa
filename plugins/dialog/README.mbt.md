# @lepusa/plugins/dialog

`@lepusa/plugins/dialog` defines Lepusa's official user dialog command
contract. It includes portable async handlers that validate payloads and return
deterministic message, confirm, and prompt responses. Native runtimes own the
actual OS dialog implementation.

```moonbit nocheck
///|
test "declare dialog access" {
  let plugin = @dialog.plugin()
  assert_true(plugin.command_routes().contains("dialog.message"))
  assert_true(plugin.command_routes().contains("dialog.confirm"))

  let grant = @dialog.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Dialog))

  let registry = @dialog.registry()
  assert_true(registry.contains("dialog.prompt"))
}
```
