///|
test "clipboard plugin declares async clipboard commands" {
  let declared = plugin()
  assert_eq(declared.name(), "clipboard")
  assert_eq(declared.command_routes().length(), 3)
  assert_true(declared.command_routes().contains("clipboard.readText"))
  assert_true(declared.command_routes().contains("clipboard.writeText"))
  assert_true(declared.command_routes().contains("clipboard.clear"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Clipboard)
  assert_true(commands[1].permission() is Clipboard)
}

///|
test "clipboard capabilities grant clipboard permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Clipboard))
  assert_false(grant.allows(window_label="settings", permission=Clipboard))
  assert_false(grant.allows(window_label="main", permission=Dialog))
}

///|
async test "clipboard registry stores text in process" {
  let registry = registry()
  assert_true(registry.contains("clipboard.readText"))
  assert_true(registry.contains("clipboard.writeText"))
  assert_true(registry.contains("clipboard.clear"))
  assert_eq(registry.async_routes().length(), 3)
  let grant = capability_for_window("main")
  let write_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="clipboard",
    command="writeText",
    payload="\"hello\"",
  )
  let write = registry.dispatch_async(write_request, capabilities=[grant])
  assert_true(write.payload().unwrap_or("").contains("\"written\":true"))
  let read_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="clipboard",
    command="readText",
  )
  let read = registry.dispatch_async(read_request, capabilities=[grant])
  assert_true(read.payload().unwrap_or("").contains("\"text\":\"hello\""))
  let clear_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="clipboard",
    command="clear",
  )
  let clear = registry.dispatch_async(clear_request, capabilities=[grant])
  assert_true(clear.payload().unwrap_or("").contains("\"cleared\":true"))
}

///|
test "clipboard native registry exposes desktop handlers" {
  let registry = native_registry()
  assert_true(registry.contains("clipboard.readText"))
  assert_true(registry.contains("clipboard.writeText"))
  assert_true(registry.contains("clipboard.clear"))
  assert_eq(registry.async_routes().length(), 3)
}
