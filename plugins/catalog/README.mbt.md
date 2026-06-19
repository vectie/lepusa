# @lepusa/plugins/catalog

`@lepusa/plugins/catalog` is the central lookup package for official Lepusa
plugins. It keeps project parsers and runtime tooling from importing every
individual plugin package as the official ecosystem grows.

```moonbit nocheck
///|
test "lookup official plugins" {
  let clipboard = @catalog.plugin("clipboard").unwrap()
  assert_true(clipboard.command_routes().contains("clipboard.readText"))

  let dialog = @catalog.plugin("dialog").unwrap()
  assert_true(dialog.command_routes().contains("dialog.message"))

  let notification = @catalog.plugin("notification").unwrap()
  assert_true(notification.command_routes().contains("notification.show"))

  let opener = @catalog.plugin("opener").unwrap()
  assert_true(opener.command_routes().contains("opener.openUrl"))

  let shell = @catalog.plugin("shell").unwrap()
  assert_true(shell.command_routes().contains("shell.execute"))

  let fs = @catalog.plugin("fs").unwrap()
  assert_true(fs.command_routes().contains("fs.readText"))

  let registry = @catalog.register(@lepusa.CommandRegistry::new(), "log")
  assert_true(registry.contains("log.write"))
}
```
