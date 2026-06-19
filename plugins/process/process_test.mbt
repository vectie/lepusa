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
  assert_true(commands[2].mode() is Async)
  assert_true(commands[2].permission() is ProcessEnvironment)
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
