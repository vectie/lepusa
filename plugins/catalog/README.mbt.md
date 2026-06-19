# @lepusa/plugins/catalog

`@lepusa/plugins/catalog` is the central lookup package for official Lepusa
plugins. It keeps project parsers and runtime tooling from importing every
individual plugin package as the official ecosystem grows.

```moonbit nocheck
///|
test "lookup official plugins" {
  let dialog = @catalog.plugin("dialog").unwrap()
  assert_true(dialog.command_routes().contains("dialog.message"))

  let fs = @catalog.plugin("fs").unwrap()
  assert_true(fs.command_routes().contains("fs.readText"))

  let registry = @catalog.register(@lepusa.CommandRegistry::new(), "log")
  assert_true(registry.contains("log.write"))
}
```
