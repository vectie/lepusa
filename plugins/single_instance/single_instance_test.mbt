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
  assert_true(commands[0].mode() is Sync)
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

///|
test "single instance registry tracks primary launch state" {
  let state = SingleInstanceState::new()
  let policy = SingleInstancePolicy::new(
    key="dev.local.lepusa",
    primary_window="main",
  )
  let registry = registry(policy~, state~)
  let grant = capability_for_window("main")
  assert_true(registry.contains("singleInstance.status"))
  assert_true(registry.contains("singleInstance.acquire"))
  assert_true(registry.contains("singleInstance.release"))
  assert_true(registry.contains("singleInstance.focus"))
  assert_eq(registry.sync_routes().length(), 4)
  let acquire_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="singleInstance",
    command="acquire",
  )
  let primary = registry.dispatch(acquire_request, capabilities=[grant])
  assert_true(
    primary.payload().unwrap_or("").contains("\"status\":\"primary\""),
  )
  assert_true(state.acquired())
  let second_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="singleInstance",
    command="acquire",
    payload="{\"launch\":\"--open lepusa://open/item\"}",
  )
  let secondary = registry.dispatch(second_request, capabilities=[grant])
  assert_true(
    secondary.payload().unwrap_or("").contains("\"status\":\"secondary\""),
  )
  assert_eq(state.second_launches()[0], "--open lepusa://open/item")
  let focus_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="singleInstance",
    command="focus",
  )
  let focused = registry.dispatch(focus_request, capabilities=[grant])
  assert_true(
    focused.payload().unwrap_or("").contains("\"status\":\"focused\""),
  )
  assert_eq(state.focused_count(), 1)
  let release_request = @lepusa.InvokeRequest::new(
    id="4",
    window_label="main",
    plugin="singleInstance",
    command="release",
  )
  let released = registry.dispatch(release_request, capabilities=[grant])
  assert_true(
    released.payload().unwrap_or("").contains("\"status\":\"released\""),
  )
  assert_false(state.acquired())
}
