# @lepusa/plugins/updater

`@lepusa/plugins/updater` defines Lepusa's official self-update command
contract. Native backends own feed retrieval, package download, signature
verification, installation, and restart behavior.

```moonbit nocheck
///|
test "declare updater access" {
  let plugin = @updater.plugin()
  assert_true(plugin.command_routes().contains("updater.check"))
  assert_true(plugin.command_routes().contains("updater.downloadAndInstall"))

  let grant = @updater.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.Updater))
}
```
