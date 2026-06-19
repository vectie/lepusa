# @lepusa/plugins/deep_link

`@lepusa/plugins/deep_link` defines Lepusa's official deep-link command
contract. Native backends own URL scheme registration, launch URL capture, and
platform-specific dispatch.

```moonbit nocheck
///|
test "declare deep link access" {
  let plugin = @deep_link.plugin()
  assert_true(plugin.command_routes().contains("deepLink.getInitialUrls"))
  assert_true(plugin.command_routes().contains("deepLink.onOpenUrl"))

  let grant = @deep_link.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.DeepLink))
}
```
