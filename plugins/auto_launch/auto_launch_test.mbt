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
  assert_true(commands[0].mode() is Sync)
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

///|
test "auto launch registry tracks delegated enablement state" {
  let policy = AutoLaunchPolicy::new(
    name="dev.local.lepusa",
    executable="Contents/MacOS/lepusa",
    arguments=["--background"],
    open_hidden=true,
  )
  let state = AutoLaunchState::new()
  let registry = registry(policy~, state~)
  let grant = capability_for_window("main")
  assert_true(registry.contains("autoLaunch.status"))
  assert_true(registry.contains("autoLaunch.enable"))
  assert_true(registry.contains("autoLaunch.disable"))
  assert_true(registry.contains("autoLaunch.setEnabled"))
  assert_eq(registry.sync_routes().length(), 4)
  let status_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="autoLaunch",
    command="status",
  )
  let status = registry.dispatch(status_request, capabilities=[grant])
  assert_true(status.payload().unwrap_or("").contains("\"status\":\"ready\""))
  assert_false(state.enabled())
  let enable_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="autoLaunch",
    command="enable",
  )
  let enabled = registry.dispatch(enable_request, capabilities=[grant])
  assert_true(
    enabled.payload().unwrap_or("").contains("\"status\":\"delegated\""),
  )
  assert_true(enabled.payload().unwrap_or("").contains("\"enabled\":true"))
  assert_true(state.enabled())
  assert_eq(state.last_action(), "enable")
  let set_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="autoLaunch",
    command="setEnabled",
    payload="{\"enabled\":false}",
  )
  let set = registry.dispatch(set_request, capabilities=[grant])
  assert_true(set.payload().unwrap_or("").contains("\"enabled\":false"))
  assert_false(state.enabled())
  assert_eq(state.last_action(), "setEnabled")
  let disable_request = @lepusa.InvokeRequest::new(
    id="4",
    window_label="main",
    plugin="autoLaunch",
    command="disable",
  )
  let disabled = registry.dispatch(disable_request, capabilities=[grant])
  assert_true(disabled.payload().unwrap_or("").contains("\"enabled\":false"))
  assert_eq(state.last_action(), "disable")
}

///|
test "auto launch registry validates policy and payloads" {
  let bad_policy = AutoLaunchPolicy::new(name="bad/name")
  let bad_registry = registry(policy=bad_policy)
  let grant = capability_for_window("main")
  let status_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="autoLaunch",
    command="status",
  )
  let status = bad_registry.dispatch(status_request, capabilities=[grant])
  assert_true(
    status is InvokeError("1", "auto launch name is invalid: bad/name"),
  )
  let valid = registry(policy=AutoLaunchPolicy::new(name="dev.local.lepusa"))
  let set_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="autoLaunch",
    command="setEnabled",
    payload="{\"enabled\":\"yes\"}",
  )
  let set = valid.dispatch(set_request, capabilities=[grant])
  assert_true(
    set is InvokeError("2", "auto launch setEnabled enabled is required"),
  )
}

///|
test "auto launch native registry reports status without mutating host" {
  let policy = AutoLaunchPolicy::new(name="dev.local.lepusa")
  let registry = native_registry(policy~)
  let grant = capability_for_window("main")
  assert_true(registry.contains("autoLaunch.status"))
  assert_true(registry.contains("autoLaunch.enable"))
  assert_true(registry.contains("autoLaunch.disable"))
  assert_true(registry.contains("autoLaunch.setEnabled"))
  let status = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="native-status",
      window_label="main",
      plugin="autoLaunch",
      command="status",
    ),
    capabilities=[grant],
  )
  assert_true(status.payload().unwrap_or("").contains("\"enabled\":"))
  assert_true(status.payload().unwrap_or("").contains("\"native\":true"))
}

///|
test "auto launch native enable requires executable" {
  let registry = native_registry(
    policy=AutoLaunchPolicy::new(name="dev.local.lepusa"),
  )
  let enabled = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="native-enable",
      window_label="main",
      plugin="autoLaunch",
      command="enable",
    ),
    capabilities=[capability_for_window("main")],
  )
  assert_true(
    enabled
    is InvokeError("native-enable", "native auto launch executable is required"),
  )
}
