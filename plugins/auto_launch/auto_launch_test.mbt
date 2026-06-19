///|
test "auto launch plugin declares startup registration commands" {
  let declared = plugin()
  assert_eq(declared.name(), "autoLaunch")
  assert_eq(declared.command_routes().length(), 4)
  assert_true(declared.command_routes().contains("autoLaunch.status"))
  assert_true(declared.command_routes().contains("autoLaunch.enable"))
  assert_true(declared.command_routes().contains("autoLaunch.disable"))
  assert_true(declared.command_routes().contains("autoLaunch.setEnabled"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is AutoLaunch)
}

///|
test "auto launch capabilities grant permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=AutoLaunch))
  assert_false(grant.allows(window_label="settings", permission=AutoLaunch))
  assert_false(grant.allows(window_label="main", permission=Tray))
}

///|
test "auto launch policy validates startup metadata" {
  let policy = AutoLaunchPolicy::new(
    name="dev.local.lepusa",
    executable="Contents/MacOS/lepusa",
    open_hidden=true,
  ).argument("--background")
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.name(), "dev.local.lepusa")
  assert_true(policy.executable() is Some("Contents/MacOS/lepusa"))
  assert_true(policy.open_hidden())
  assert_eq(policy.arguments()[0], "--background")
}

///|
test "auto launch policy rejects invalid metadata" {
  let policy = AutoLaunchPolicy::new(name="bad/name", executable="bad\\app", arguments=[
    "",
  ])
  let problems = policy.validate()
  assert_true(problems.contains("auto launch name is invalid: bad/name"))
  assert_true(
    problems.contains("auto launch executable must use forward slashes"),
  )
  assert_true(problems.contains("auto launch argument is required"))
}
