# @lepusa/plugins/deep_link

`@lepusa/plugins/deep_link` defines Lepusa's official deep-link command
contract. It includes portable async handlers for initial URL state, delegated
scheme registration, and URL open validation. Native backends own OS URL scheme
registration, launch URL capture, and platform-specific dispatch.

```moonbit nocheck
///|
test "declare deep link access" {
  let plugin = @deep_link.plugin()
  assert_true(plugin.command_routes().contains("deepLink.getInitialUrls"))
  assert_true(plugin.command_routes().contains("deepLink.onOpenUrl"))

  let grant = @deep_link.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.DeepLink))

  let registry = @deep_link.registry(
    policy=@deep_link.DeepLinkPolicy::new().scheme(
      @deep_link.DeepLinkScheme::new(scheme="lepusa"),
    ),
  )
  assert_true(registry.contains("deepLink.openUrl"))
}
```
