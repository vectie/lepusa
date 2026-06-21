# @lepusa/plugins/file_dialog

`@lepusa/plugins/file_dialog` defines Lepusa's official file dialog command
contract. It declares platform-neutral open/save routes and scoped default
directories. Its portable registry validates picker payloads against named
filesystem scopes and returns delegated picker contracts. Native registries
open host file pickers through macOS `osascript`, Linux `zenity`, or Windows
PowerShell/WinForms while MoonBit keeps validation and scope resolution.

```moonbit nocheck
///|
test "declare file dialog access" {
  let plugin = @file_dialog.plugin()
  assert_true(plugin.command_routes().contains("fileDialog.openFile"))
  assert_true(plugin.command_routes().contains("fileDialog.saveFile"))

  let grant = @file_dialog.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.FileDialog))

  let registry = @file_dialog.registry()
  assert_true(registry.contains("fileDialog.openDirectory"))
}
```
