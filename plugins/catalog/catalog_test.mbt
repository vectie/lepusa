///|
test "catalog exposes official plugin declarations" {
  let names = plugin_names()
  assert_eq(names.length(), 18)
  assert_true(names.contains("autoLaunch"))
  assert_true(names.contains("clipboard"))
  assert_true(names.contains("deepLink"))
  assert_true(names.contains("dialog"))
  assert_true(names.contains("fileDialog"))
  assert_true(names.contains("fs"))
  assert_true(names.contains("localhost"))
  assert_true(names.contains("log"))
  assert_true(names.contains("notification"))
  assert_true(names.contains("opener"))
  assert_true(names.contains("process"))
  assert_true(names.contains("serviceDiscovery"))
  assert_true(names.contains("shell"))
  assert_true(names.contains("singleInstance"))
  assert_true(names.contains("store"))
  assert_true(names.contains("tray"))
  assert_true(names.contains("updater"))
  assert_true(names.contains("windowState"))
  assert_true(
    plugin("autoLaunch").unwrap().command_routes().contains("autoLaunch.status"),
  )
  assert_true(
    plugin("clipboard").unwrap().command_routes().contains("clipboard.readText"),
  )
  assert_true(
    plugin("deepLink")
    .unwrap()
    .command_routes()
    .contains("deepLink.getInitialUrls"),
  )
  assert_true(
    plugin("dialog").unwrap().command_routes().contains("dialog.message"),
  )
  assert_true(
    plugin("fileDialog")
    .unwrap()
    .command_routes()
    .contains("fileDialog.openFile"),
  )
  assert_true(
    plugin("localhost").unwrap().command_routes().contains("localhost.status"),
  )
  assert_true(plugin("log").unwrap().command_routes().contains("log.write"))
  assert_true(
    plugin("notification")
    .unwrap()
    .command_routes()
    .contains("notification.show"),
  )
  assert_true(
    plugin("opener").unwrap().command_routes().contains("opener.openUrl"),
  )
  assert_true(
    plugin("process").unwrap().command_routes().contains("process.info"),
  )
  assert_true(
    plugin("serviceDiscovery")
    .unwrap()
    .command_routes()
    .contains("serviceDiscovery.list"),
  )
  assert_true(
    plugin("shell").unwrap().command_routes().contains("shell.execute"),
  )
  assert_true(
    plugin("singleInstance")
    .unwrap()
    .command_routes()
    .contains("singleInstance.acquire"),
  )
  assert_true(plugin("store").unwrap().command_routes().contains("store.set"))
  assert_true(plugin("tray").unwrap().command_routes().contains("tray.setMenu"))
  assert_true(
    plugin("updater").unwrap().command_routes().contains("updater.check"),
  )
  assert_true(
    plugin("windowState").unwrap().command_routes().contains("windowState.save"),
  )
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
  assert_true(registry.contains("fs.readText"))
  let names = registered_plugin_names()
  assert_eq(names.length(), 3)
  assert_true(names.contains("fs"))
  assert_true(names.contains("log"))
  assert_true(names.contains("store"))
}
