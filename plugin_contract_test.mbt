///|
test "plugin contract reports declared command surface" {
  let plugin = @lepusa.Plugin::new("demo")
    .command_sync(
      "read",
      permission=FileSystemRead,
      request=@lepusa.IpcSchema::string(),
      response=@lepusa.IpcSchema::json(),
    )
    .command_async(
      "write",
      permission=FileSystemWrite,
      request=@lepusa.IpcSchema::object("WriteRequest", "{ path: string }"),
      response=@lepusa.IpcSchema::boolean(),
    )
    .command_event("changed")
    .with_lifecycle(PluginReady("demo"), @lepusa.Cmd::effect("demo.ready"))
  let contract = plugin.contract()
  assert_true(contract.ok())
  assert_eq(contract.name(), "demo")
  assert_eq(contract.command_count(), 3)
  assert_eq(contract.sync_count(), 1)
  assert_eq(contract.async_count(), 1)
  assert_eq(contract.event_count(), 1)
  assert_eq(contract.stream_count(), 0)
  assert_eq(contract.lifecycle_count(), 1)
  assert_true(contract.command_routes().contains("demo.read"))
  assert_true(contract.command_routes().contains("demo.write"))
  assert_true(contract.permissions().contains("filesystem.read"))
  assert_true(contract.permissions().contains("filesystem.write"))
  assert_true(contract.permissions().contains("custom:demo.changed"))
  let commands = contract.commands()
  assert_eq(commands[0].route(), "demo.read")
  assert_true(commands[0].mode() is Sync)
  assert_true(commands[0].permission() is FileSystemRead)
  assert_eq(commands[0].request_schema().typescript(), "string")
  assert_false(contract.lifecycle_hooks()[0].command_empty())
  let json = contract.to_json()
  assert_true(json.contains("\"name\":\"demo\""))
  assert_true(json.contains("\"route\":\"demo.read\""))
  assert_true(json.contains("\"mode\":\"async\""))
  assert_true(json.contains("\"plugin-ready\""))
}

///|
test "plugin contract carries validation problems" {
  let contract = @lepusa.Plugin::new("dup")
    .command_sync("read")
    .command_async("read")
    .contract()
  assert_false(contract.ok())
  assert_eq(contract.problems().length(), 1)
  assert_true(
    contract.problems()[0].contains("plugin command must be unique: read"),
  )
  assert_true(contract.to_json().contains("\"ok\":false"))
}
