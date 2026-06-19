///|
test "service discovery plugin declares resolution commands" {
  let declared = plugin()
  assert_eq(declared.name(), "serviceDiscovery")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("serviceDiscovery.list"))
  assert_true(declared.command_routes().contains("serviceDiscovery.resolve"))
  assert_true(declared.command_routes().contains("serviceDiscovery.status"))
  assert_true(declared.command_routes().contains("serviceDiscovery.watch"))
  assert_true(
    declared.command_routes().contains("serviceDiscovery.onServiceChanged"),
  )
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[4].mode() is Event)
  assert_true(commands[0].permission() is ServiceDiscovery)
}

///|
test "service discovery capabilities grant permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=ServiceDiscovery))
  assert_false(
    grant.allows(window_label="settings", permission=ServiceDiscovery),
  )
  assert_false(grant.allows(window_label="main", permission=Updater))
}

///|
test "service discovery policy validates service metadata" {
  let policy = ServiceDiscoveryPolicy::new()
    .service(
      ServiceEndpoint::new(
        name="api",
        url="http://127.0.0.1:8080",
        health_path="/health",
      ),
    )
    .service(
      ServiceEndpoint::new(name="events", url="wss://events.example.dev"),
    )
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.services().length(), 2)
  assert_true(policy.service_names().contains("api"))
  assert_true(policy.services()[0].health_path() is Some("/health"))
}

///|
test "service discovery policy rejects invalid metadata" {
  let policy = ServiceDiscoveryPolicy::new()
    .service(ServiceEndpoint::new(name="api", url="ftp://example.dev"))
    .service(ServiceEndpoint::new(name="api", url="https://example.dev"))
    .service(
      ServiceEndpoint::new(name="bad name", url="", health_path="health"),
    )
  let problems = policy.validate()
  assert_true(
    problems.contains("service discovery url must use http, https, ws, or wss"),
  )
  assert_true(problems.contains("service discovery name must be unique: api"))
  assert_true(problems.contains("service discovery name is invalid: bad name"))
  assert_true(problems.contains("service discovery url is required"))
  assert_true(
    problems.contains("service discovery health path must start with /"),
  )
}
