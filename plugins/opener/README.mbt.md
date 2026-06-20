# @lepusa/plugins/opener

`@lepusa/plugins/opener` defines Lepusa's official external opener command
contract. It declares platform-neutral routes for URLs and paths, validates
payloads in MoonBit, and registers native handlers backed by `open`, `xdg-open`,
or ShellExecute/explorer.

```moonbit nocheck
///|
test "declare opener access" {
  let plugin = @opener.plugin()
  assert_true(plugin.command_routes().contains("opener.openUrl"))
  assert_true(plugin.command_routes().contains("opener.revealPath"))

  let grant = @opener.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Opener))

  let registry = @opener.registry()
  assert_true(registry.contains("opener.openUrl"))
}
```
