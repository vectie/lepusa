# @lepusa/plugins/window_state

`@lepusa/plugins/window_state` defines Lepusa's official window persistence
command contract. The portable sync registry keeps state in the current runtime
process for tests and lightweight runtimes. `WindowStateFileStore` provides a
durable file-backed registry for runtimes that already have captured window
geometry and visibility state.

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

  let durable = @window_state.file_registry(
    @window_state.WindowStateFileStore::new(root="/tmp/lepusa-window-state"),
  )
  assert_true(durable.contains("windowState.restore"))
}
```
