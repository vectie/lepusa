# @lepusa/plugins/clipboard

`@lepusa/plugins/clipboard` defines Lepusa's official clipboard command
contract. It declares platform-neutral routes and includes an async
`ClipboardStore` registry for runtime-owned text clipboard behavior. Native
runtimes can replace that registry with system clipboard integration.

```moonbit nocheck
///|
test "declare clipboard access" {
  let plugin = @clipboard.plugin()
  assert_true(plugin.command_routes().contains("clipboard.readText"))
  assert_true(plugin.command_routes().contains("clipboard.writeText"))

  let grant = @clipboard.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Clipboard))

  let registry = @clipboard.registry()
  assert_true(registry.contains("clipboard.writeText"))
}
```
