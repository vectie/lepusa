///|
test "single instance plugin declares lifecycle commands" {
  let declared = plugin()
  assert_eq(declared.name(), "singleInstance")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("singleInstance.status"))
  assert_true(declared.command_routes().contains("singleInstance.acquire"))
  assert_true(declared.command_routes().contains("singleInstance.release"))
  assert_true(declared.command_routes().contains("singleInstance.focus"))
  assert_true(
    declared.command_routes().contains("singleInstance.onSecondLaunch"),
  )
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[4].mode() is Event)
  assert_true(commands[0].permission() is SingleInstance)
}

///|
test "single instance capabilities grant permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=SingleInstance))
  assert_false(grant.allows(window_label="settings", permission=SingleInstance))
  assert_false(grant.allows(window_label="main", permission=DeepLink))
}

///|
test "single instance policy validates launch handoff settings" {
  let policy = SingleInstancePolicy::new(
    key="dev.local.lepusa",
    primary_window="main",
  )
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.key(), "dev.local.lepusa")
  assert_true(policy.primary_window() is Some("main"))
  assert_true(policy.forward_args())
  assert_true(policy.forward_urls())
}

///|
test "single instance policy rejects invalid identifiers" {
  let policy = SingleInstancePolicy::new(key="bad/key", primary_window="")
  let problems = policy.validate()
  assert_true(problems.contains("single instance key is invalid: bad/key"))
  assert_true(problems.contains("single instance primary window is required"))
}
