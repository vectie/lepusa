# @lepusa/plugins/tray

`@lepusa/plugins/tray` defines Lepusa's official system tray command contract.
The portable registry validates and tracks icon, tooltip, menu, visibility, and
destroy state, then delegates status icon creation, platform menu rendering, and
click dispatch to native backends.

```moonbit nocheck
///|
test "declare tray access" {
  let plugin = @tray.plugin()
  assert_true(plugin.command_routes().contains("tray.setMenu"))
  assert_true(plugin.command_routes().contains("tray.onMenuItemClick"))

  let grant = @tray.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Tray))
}
```
