# @lepusa/plugins/window_state

`@lepusa/plugins/window_state` defines Lepusa's official window persistence
command contract. The portable registry keeps state in the current runtime
process for tests and lightweight runtimes. Native backends own platform window
state capture, restoration, and durable persistence storage.

```moonbit nocheck
///|
test "declare window state access" {
  let plugin = @window_state.plugin()
  assert_true(plugin.command_routes().contains("windowState.save"))
  assert_true(plugin.command_routes().contains("windowState.restore"))

  let grant = @window_state.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.WindowState))

  let registry = @window_state.registry()
  assert_true(registry.contains("windowState.set"))
  assert_true(registry.contains("windowState.get"))
}
```
