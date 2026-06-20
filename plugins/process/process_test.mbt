///|
test "process plugin declares explicit process commands" {
  let declared = plugin()
  assert_eq(declared.name(), "process")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("process.info"))
  assert_true(declared.command_routes().contains("process.cwd"))
  assert_true(declared.command_routes().contains("process.env"))
  assert_true(declared.command_routes().contains("process.setEnv"))
  assert_true(declared.command_routes().contains("process.exit"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Sync)
  assert_true(commands[0].permission() is ProcessInfo)
  assert_true(commands[2].mode() is Sync)
  assert_true(commands[2].permission() is ProcessEnvironment)
  assert_true(commands[4].mode() is Async)
  assert_true(commands[4].permission() is ProcessControl)
}

///|
test "process capabilities split info environment and control" {
  let info = info_capability().window("main")
  assert_true(info.allows(window_label="main", permission=ProcessInfo))
  assert_false(info.allows(window_label="main", permission=ProcessEnvironment))
  let environment = environment_capability().window("main")
  assert_true(
    environment.allows(window_label="main", permission=ProcessEnvironment),
  )
  assert_false(
    environment.allows(window_label="main", permission=ProcessControl),
  )
  let all = capability_for_window("main")
  assert_true(all.allows(window_label="main", permission=ProcessInfo))
  assert_true(all.allows(window_label="main", permission=ProcessEnvironment))
  assert_true(all.allows(window_label="main", permission=ProcessControl))
  assert_false(all.allows(window_label="settings", permission=ProcessInfo))
}

///|
test "process plugin registers portable process handlers" {
  let registry = register(@lepusa.CommandRegistry::new())
  assert_true(registry.contains("process.info"))
  assert_true(registry.contains("process.cwd"))
  assert_true(registry.contains("process.env"))
  assert_true(registry.contains("process.setEnv"))
  assert_false(registry.contains("process.exit"))
  let capability = capability_for_window("main")
  let info = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="info",
      window_label="main",
      plugin="process",
      command="info",
    ),
    capabilities=[capability],
  )
  assert_true(info is InvokeOk("info", _))
  assert_true(info.payload().unwrap_or("").contains("\"cwd\""))
  let cwd = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="cwd",
      window_label="main",
      plugin="process",
      command="cwd",
    ),
    capabilities=[capability],
  )
  assert_true(cwd is InvokeOk("cwd", _))
  let key = "LEPUSA_PROCESS_TEST"
  let set = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="set",
      window_label="main",
      plugin="process",
      command="setEnv",
      payload="{\"key\":\"\{key}\",\"value\":\"ready\"}",
    ),
    capabilities=[capability],
  )
  assert_true(set is InvokeOk("set", _))
  let env = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="env",
      window_label="main",
      plugin="process",
      command="env",
      payload="{\"key\":\"\{key}\"}",
    ),
    capabilities=[capability],
  )
  assert_true(env is InvokeOk("env", _))
  assert_true(env.payload().unwrap_or("").contains("\"value\":\"ready\""))
}
