# @lepusa/plugins/clipboard

`@lepusa/plugins/clipboard` defines Lepusa's official clipboard command
contract. It declares platform-neutral routes, exposes native system clipboard
handlers for desktop runtimes, and keeps an async `ClipboardStore` registry for
deterministic tests or in-process previews.

```moonbit nocheck
///|
test "declare clipboard access" {
  let plugin = @clipboard.plugin()
  assert_true(plugin.command_routes().contains("clipboard.readText"))
  assert_true(plugin.command_routes().contains("clipboard.writeText"))

  let grant = @clipboard.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Clipboard))

  let native = @clipboard.native_registry()
  assert_true(native.contains("clipboard.writeText"))

  let memory = @clipboard.registry()
  assert_true(memory.contains("clipboard.writeText"))
}
```
