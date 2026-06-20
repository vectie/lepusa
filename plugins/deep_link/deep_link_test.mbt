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
  assert_true(commands[0].mode() is Sync)
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

///|
test "deep link registry records URL handoff state" {
  let state = DeepLinkState::new(initial_urls=["lepusa://open/start"])
  let registry = registry(
    policy=DeepLinkPolicy::new().scheme(
      DeepLinkScheme::new(scheme="lepusa", hosts=["open"]),
    ),
    state~,
  )
  let grant = capability_for_window("main")
  assert_true(registry.contains("deepLink.getInitialUrls"))
  assert_true(registry.contains("deepLink.register"))
  assert_true(registry.contains("deepLink.unregister"))
  assert_true(registry.contains("deepLink.openUrl"))
  assert_eq(registry.sync_routes().length(), 4)
  let initial_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="deepLink",
    command="getInitialUrls",
  )
  let initial = registry.dispatch(initial_request, capabilities=[grant])
  assert_true(initial.payload().unwrap_or("").contains("lepusa://open/start"))
  let register_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="deepLink",
    command="register",
    payload="\"lepusa\"",
  )
  let registered = registry.dispatch(register_request, capabilities=[grant])
  assert_true(
    registered.payload().unwrap_or("").contains("\"registered\":true"),
  )
  assert_true(state.registered_schemes().contains("lepusa"))
  let open_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="deepLink",
    command="openUrl",
    payload="{\"url\":\"lepusa://open/item\"}",
  )
  let opened = registry.dispatch(open_request, capabilities=[grant])
  assert_true(
    opened.payload().unwrap_or("").contains("\"status\":\"delegated\""),
  )
  assert_eq(state.opened_urls()[0], "lepusa://open/item")
  let denied_request = @lepusa.InvokeRequest::new(
    id="4",
    window_label="main",
    plugin="deepLink",
    command="openUrl",
    payload="{\"url\":\"lepusa://blocked/item\"}",
  )
  let denied = registry.dispatch(denied_request, capabilities=[grant])
  assert_true(
    denied
    is InvokeError("4", "deep link url is not allowed: lepusa://blocked/item"),
  )
}
