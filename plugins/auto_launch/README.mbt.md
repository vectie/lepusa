# @lepusa/plugins/auto_launch

`@lepusa/plugins/auto_launch` defines Lepusa's official launch-at-login command
contract. Native backends own the platform-specific login item, registry,
service, or desktop-entry integration.

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
