# @lepusa/plugins/window_state

`@lepusa/plugins/window_state` defines Lepusa's official window persistence
command contract. Native backends own platform window state capture,
restoration, and persistence storage.

```moonbit nocheck
///|
test "declare window state access" {
  let plugin = @window_state.plugin()
  assert_true(plugin.command_routes().contains("windowState.save"))
  assert_true(plugin.command_routes().contains("windowState.restore"))

  let grant = @window_state.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.WindowState))
}
```
