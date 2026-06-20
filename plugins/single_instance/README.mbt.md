# @lepusa/plugins/single_instance

`@lepusa/plugins/single_instance` defines Lepusa's official single-instance
command contract. It includes portable sync handlers for primary-instance
state, second-launch metadata, release, and focus requests. Native backends own
cross-process lock acquisition, second-launch handoff, and platform-specific
window focusing.

```moonbit nocheck
///|
test "declare single instance access" {
  let plugin = @single_instance.plugin()
  assert_true(plugin.command_routes().contains("singleInstance.acquire"))
  assert_true(plugin.command_routes().contains("singleInstance.onSecondLaunch"))

  let grant = @single_instance.capability_for_window("main")
  assert_true(
    grant.allows(window_label="main", permission=@lepusa.SingleInstance),
  )

  let registry = @single_instance.registry(
    policy=@single_instance.SingleInstancePolicy::new(key="dev.local.lepusa"),
  )
  assert_true(registry.contains("singleInstance.focus"))
}
```
