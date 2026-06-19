# @lepusa/plugins/clipboard

`@lepusa/plugins/clipboard` defines Lepusa's official clipboard command
contract. It declares platform-neutral routes; native runtimes own the actual
system clipboard implementation.

```moonbit nocheck
///|
test "declare clipboard access" {
  let plugin = @clipboard.plugin()
  assert_true(plugin.command_routes().contains("clipboard.readText"))
  assert_true(plugin.command_routes().contains("clipboard.writeText"))

  let grant = @clipboard.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Clipboard))
}
```
