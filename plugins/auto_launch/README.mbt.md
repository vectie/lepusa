# @lepusa/plugins/auto_launch

`@lepusa/plugins/auto_launch` defines Lepusa's official launch-at-login command
contract. The portable registry validates startup metadata and tracks desired
enabled/disabled state, then delegates platform-specific login item, registry,
service, or desktop-entry integration to native backends.

```moonbit nocheck
///|
test "declare auto launch access" {
  let plugin = @auto_launch.plugin()
  assert_true(plugin.command_routes().contains("autoLaunch.status"))
  assert_true(plugin.command_routes().contains("autoLaunch.setEnabled"))

  let grant = @auto_launch.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.AutoLaunch))
}
```
