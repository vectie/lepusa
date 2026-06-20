///|
test "updater plugin declares update lifecycle commands" {
  let declared = plugin()
  assert_eq(declared.name(), "updater")
  assert_eq(declared.command_routes().length(), 6)
  assert_true(declared.command_routes().contains("updater.check"))
  assert_true(declared.command_routes().contains("updater.download"))
  assert_true(declared.command_routes().contains("updater.install"))
  assert_true(declared.command_routes().contains("updater.downloadAndInstall"))
  assert_true(declared.command_routes().contains("updater.restart"))
  assert_true(declared.command_routes().contains("updater.onUpdateAvailable"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[5].mode() is Event)
  assert_true(commands[0].permission() is Updater)
}

///|
test "updater capabilities grant permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Updater))
  assert_false(grant.allows(window_label="settings", permission=Updater))
  assert_false(grant.allows(window_label="main", permission=WindowState))
}

///|
test "updater policy validates feed metadata" {
  let policy = UpdaterPolicy::new(
    feed_url="https://updates.example.com/lepusa.json",
    channel="stable",
    public_key="ed25519:abc",
  )
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.feed_url(), "https://updates.example.com/lepusa.json")
  assert_eq(policy.channel(), "stable")
  assert_true(policy.public_key() is Some("ed25519:abc"))
  assert_false(policy.allow_prerelease())
}

///|
test "updater policy rejects invalid metadata" {
  let policy = UpdaterPolicy::new(
    feed_url="http://updates.example.com/lepusa.json",
    channel="bad channel",
    public_key="",
  )
  let problems = policy.validate()
  assert_true(problems.contains("updater feed url must use https"))
  assert_true(problems.contains("updater channel is invalid: bad channel"))
  assert_true(problems.contains("updater public key is required"))
}

///|
async test "updater registry tracks delegated lifecycle state" {
  let policy = UpdaterPolicy::new(
    feed_url="https://updates.example.com/lepusa.json",
    channel="stable",
    public_key="ed25519:abc",
  )
  let state = UpdaterState::new()
  let registry = registry(policy~, state~)
  let grant = capability_for_window("main")
  assert_true(registry.contains("updater.check"))
  assert_true(registry.contains("updater.download"))
  assert_true(registry.contains("updater.install"))
  assert_true(registry.contains("updater.downloadAndInstall"))
  assert_true(registry.contains("updater.restart"))
  assert_eq(registry.async_routes().length(), 5)
  let check_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="updater",
    command="check",
    payload="{\"updateAvailable\":true,\"version\":\"1.2.3\"}",
  )
  let checked = registry.dispatch_async(check_request, capabilities=[grant])
  assert_true(
    checked.payload().unwrap_or("").contains("\"status\":\"delegated\""),
  )
  assert_true(state.update_available())
  assert_true(state.version() is Some("1.2.3"))
  assert_eq(state.last_action(), "check")
  let download_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="updater",
    command="download",
  )
  let downloaded = registry.dispatch_async(download_request, capabilities=[
    grant,
  ])
  assert_true(
    downloaded.payload().unwrap_or("").contains("\"downloaded\":true"),
  )
  assert_true(state.downloaded())
  let install_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="updater",
    command="install",
  )
  let installed = registry.dispatch_async(install_request, capabilities=[grant])
  assert_true(installed.payload().unwrap_or("").contains("\"installed\":true"))
  assert_true(state.installed())
  let restart_request = @lepusa.InvokeRequest::new(
    id="4",
    window_label="main",
    plugin="updater",
    command="restart",
  )
  let restarted = registry.dispatch_async(restart_request, capabilities=[grant])
  assert_true(
    restarted.payload().unwrap_or("").contains("\"restartRequested\":true"),
  )
  assert_true(state.restart_requested())
}

///|
async test "updater registry supports combined delegated download and install" {
  let policy = UpdaterPolicy::new(
    feed_url="https://updates.example.com/lepusa.json",
    channel="beta",
    allow_prerelease=true,
  )
  let state = UpdaterState::new()
  let registry = registry(policy~, state~)
  let grant = capability_for_window("main")
  let request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="updater",
    command="downloadAndInstall",
    payload="\"2.0.0-beta.1\"",
  )
  let response = registry.dispatch_async(request, capabilities=[grant])
  assert_true(
    response.payload().unwrap_or("").contains("\"version\":\"2.0.0-beta.1\""),
  )
  assert_true(response.payload().unwrap_or("").contains("\"downloaded\":true"))
  assert_true(response.payload().unwrap_or("").contains("\"installed\":true"))
  assert_true(state.update_available())
  assert_true(state.downloaded())
  assert_true(state.installed())
}

///|
async test "updater registry validates policy and payloads" {
  let bad_policy = UpdaterPolicy::new(
    feed_url="http://updates.example.com/app.json",
  )
  let bad_registry = registry(policy=bad_policy)
  let grant = capability_for_window("main")
  let check_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="updater",
    command="check",
  )
  let checked = bad_registry.dispatch_async(check_request, capabilities=[grant])
  assert_true(checked is InvokeError("1", "updater feed url must use https"))
  let valid = registry(
    policy=UpdaterPolicy::new(feed_url="https://updates.example.com/app.json"),
  )
  let download_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="updater",
    command="download",
    payload="\"bad/version\"",
  )
  let downloaded = valid.dispatch_async(download_request, capabilities=[grant])
  assert_true(
    downloaded
    is InvokeError("2", "updater download version is invalid: bad/version"),
  )
}
