///|
test "window state plugin declares persistence commands" {
  let declared = plugin()
  assert_eq(declared.name(), "windowState")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("windowState.save"))
  assert_true(declared.command_routes().contains("windowState.restore"))
  assert_true(declared.command_routes().contains("windowState.clear"))
  assert_true(declared.command_routes().contains("windowState.get"))
  assert_true(declared.command_routes().contains("windowState.set"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is WindowState)
}

///|
test "window state capabilities grant permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=WindowState))
  assert_false(grant.allows(window_label="settings", permission=WindowState))
  assert_false(grant.allows(window_label="main", permission=AutoLaunch))
}

///|
test "window state policy validates persistence rules" {
  let policy = WindowStatePolicy::new(store_name="dev.local.lepusa")
    .rule(WindowStateRule::new(window_label="main"))
    .rule(
      WindowStateRule::new(window_label="settings", remember_visibility=true),
    )
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.store_name(), "dev.local.lepusa")
  assert_eq(policy.rules().length(), 2)
  assert_true(policy.rules()[0].remember_size())
  assert_true(policy.rules()[0].remember_position())
}

///|
test "window state policy rejects invalid metadata" {
  let policy = WindowStatePolicy::new(store_name="bad/name")
    .rule(WindowStateRule::new(window_label="main"))
    .rule(WindowStateRule::new(window_label="main"))
    .rule(
      WindowStateRule::new(
        window_label="bad label",
        remember_size=false,
        remember_position=false,
      ),
    )
  let problems = policy.validate()
  assert_true(problems.contains("window state store name is invalid: bad/name"))
  assert_true(problems.contains("window state rule must be unique: main"))
  assert_true(problems.contains("window state label is invalid: bad label"))
  assert_true(
    problems.contains("window state rule must remember at least one property"),
  )
}
