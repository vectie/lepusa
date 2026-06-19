///|
test "deep link plugin declares URL lifecycle commands" {
  let declared = plugin()
  assert_eq(declared.name(), "deepLink")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("deepLink.getInitialUrls"))
  assert_true(declared.command_routes().contains("deepLink.onOpenUrl"))
  assert_true(declared.command_routes().contains("deepLink.register"))
  assert_true(declared.command_routes().contains("deepLink.unregister"))
  assert_true(declared.command_routes().contains("deepLink.openUrl"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[1].mode() is Event)
  assert_true(commands[0].permission() is DeepLink)
}

///|
test "deep link capabilities grant deep link permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=DeepLink))
  assert_false(grant.allows(window_label="settings", permission=DeepLink))
  assert_false(grant.allows(window_label="main", permission=Opener))
}

///|
test "deep link policy validates scheme metadata" {
  let policy = DeepLinkPolicy::new().scheme(
    DeepLinkScheme::new(scheme="lepusa", hosts=["open", "callback"]),
  )
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.scheme_names()[0], "lepusa")
}

///|
test "deep link policy rejects invalid and duplicate schemes" {
  let policy = DeepLinkPolicy::new()
    .scheme(DeepLinkScheme::new(scheme="lepusa"))
    .scheme(DeepLinkScheme::new(scheme="lepusa"))
    .scheme(DeepLinkScheme::new(scheme="bad/scheme", hosts=["bad host", ""]))
  let problems = policy.validate()
  assert_true(problems.contains("deep link scheme must be unique: lepusa"))
  assert_true(problems.contains("deep link scheme is invalid: bad/scheme"))
  assert_true(problems.contains("deep link host is invalid: bad host"))
  assert_true(problems.contains("deep link host is required"))
}
