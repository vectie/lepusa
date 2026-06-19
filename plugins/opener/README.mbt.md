# @lepusa/plugins/opener

`@lepusa/plugins/opener` defines Lepusa's official external opener command
contract. It declares platform-neutral routes for URLs and paths; native
runtimes own the actual platform open/reveal implementation.

```moonbit nocheck
///|
test "declare opener access" {
  let plugin = @opener.plugin()
  assert_true(plugin.command_routes().contains("opener.openUrl"))
  assert_true(plugin.command_routes().contains("opener.revealPath"))

  let grant = @opener.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Opener))
}
```
