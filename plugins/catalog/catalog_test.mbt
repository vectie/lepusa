///|
test "catalog exposes official plugin declarations" {
  let names = plugin_names()
  assert_eq(names.length(), 3)
  assert_true(names.contains("fs"))
  assert_true(names.contains("log"))
  assert_true(names.contains("store"))
  assert_true(plugin("log").unwrap().command_routes().contains("log.write"))
  assert_true(plugin("store").unwrap().command_routes().contains("store.set"))
  assert_true(plugin("fs").unwrap().command_routes().contains("fs.readText"))
  assert_true(plugin("missing") is None)
}

///|
test "catalog registers pure moonbit handlers" {
  let registry = @lepusa.CommandRegistry::new()
  let registry = register(registry, "log")
  let registry = register(registry, "store")
  let registry = register(registry, "fs")
  assert_true(registry.contains("log.write"))
  assert_true(registry.contains("store.set"))
  assert_false(registry.contains("fs.readText"))
  let names = registered_plugin_names()
  assert_eq(names.length(), 2)
  assert_true(names.contains("log"))
  assert_true(names.contains("store"))
}
