# @lepusa/plugins/file_dialog

`@lepusa/plugins/file_dialog` defines Lepusa's official file dialog command
contract. It declares platform-neutral open/save routes and scoped default
directories; native runtimes own the actual OS picker implementation.

```moonbit nocheck
///|
test "declare file dialog access" {
  let plugin = @file_dialog.plugin()
  assert_true(plugin.command_routes().contains("fileDialog.openFile"))
  assert_true(plugin.command_routes().contains("fileDialog.saveFile"))

  let grant = @file_dialog.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=@lepusa.FileDialog))
}
```
