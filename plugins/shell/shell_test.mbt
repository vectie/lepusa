///|
test "shell plugin declares async shell commands" {
  let declared = plugin()
  assert_eq(declared.name(), "shell")
  assert_eq(declared.command_routes().length(), 4)
  assert_true(declared.command_routes().contains("shell.execute"))
  assert_true(declared.command_routes().contains("shell.spawn"))
  assert_true(declared.command_routes().contains("shell.kill"))
  assert_true(declared.command_routes().contains("shell.stdinWrite"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Shell)
  assert_true(commands[1].permission() is Shell)
}

///|
test "shell capabilities grant shell permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Shell))
  assert_false(grant.allows(window_label="settings", permission=Shell))
  assert_false(grant.allows(window_label="main", permission=Clipboard))
}

///|
async test "shell registry records delegated process lifecycle" {
  let table = ShellProcessTable::new()
  let registry = registry(
    policy=ShellPolicy::new(allowed_commands=["moon"]),
    table~,
  )
  let grant = capability_for_window("main")
  assert_true(registry.contains("shell.execute"))
  assert_true(registry.contains("shell.spawn"))
  assert_true(registry.contains("shell.kill"))
  assert_true(registry.contains("shell.stdinWrite"))
  assert_eq(registry.async_routes().length(), 4)
  let execute_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="shell",
    command="execute",
    payload="{\"command\":\"moon\",\"args\":[\"test\"]}",
  )
  let execute = registry.dispatch_async(execute_request, capabilities=[grant])
  assert_true(
    execute.payload().unwrap_or("").contains("\"status\":\"delegated\""),
  )
  let denied_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="shell",
    command="execute",
    payload="{\"command\":\"rm\"}",
  )
  let denied = registry.dispatch_async(denied_request, capabilities=[grant])
  assert_eq(
    denied.error_message().unwrap_or(""),
    "shell command is not allowed: rm",
  )
  let spawn_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="shell",
    command="spawn",
    payload="{\"command\":\"moon\",\"args\":[\"run\",\"cmd/main\"]}",
  )
  let spawned = registry.dispatch_async(spawn_request, capabilities=[grant])
  assert_true(spawned.payload().unwrap_or("").contains("\"id\":\"shell-1\""))
  assert_eq(table.processes().length(), 1)
  let stdin_request = @lepusa.InvokeRequest::new(
    id="4",
    window_label="main",
    plugin="shell",
    command="stdinWrite",
    payload="{\"id\":\"shell-1\",\"text\":\"hello\"}",
  )
  let stdin = registry.dispatch_async(stdin_request, capabilities=[grant])
  assert_true(stdin.payload().unwrap_or("").contains("\"written\":true"))
  match table.get("shell-1") {
    Some(process) => assert_eq(process.stdin_chunks()[0], "hello")
    None => fail("expected shell process")
  }
  let kill_request = @lepusa.InvokeRequest::new(
    id="5",
    window_label="main",
    plugin="shell",
    command="kill",
    payload="\"shell-1\"",
  )
  let killed = registry.dispatch_async(kill_request, capabilities=[grant])
  assert_true(killed.payload().unwrap_or("").contains("\"killed\":true"))
  match table.get("shell-1") {
    Some(process) => assert_eq(process.status(), "killed")
    None => fail("expected shell process")
  }
}
