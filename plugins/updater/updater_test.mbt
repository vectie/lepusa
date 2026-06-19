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
