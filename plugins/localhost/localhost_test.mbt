///|
test "localhost plugin declares service lifecycle commands" {
  let declared = plugin()
  assert_eq(declared.name(), "localhost")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("localhost.status"))
  assert_true(declared.command_routes().contains("localhost.start"))
  assert_true(declared.command_routes().contains("localhost.stop"))
  assert_true(declared.command_routes().contains("localhost.restart"))
  assert_true(declared.command_routes().contains("localhost.waitUntilReady"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Localhost)
}

///|
test "localhost capabilities grant localhost permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Localhost))
  assert_false(grant.allows(window_label="settings", permission=Localhost))
  assert_false(grant.allows(window_label="main", permission=Shell))
}

///|
test "localhost policy validates service metadata" {
  let policy = LocalhostPolicy::new().service(
    @lepusa.LocalService::new(
      name="api",
      command=["moon", "run", "cmd/server"],
      readiness_url="http://127.0.0.1:4317/ready",
    ),
  )
  assert_eq(policy.validate().length(), 0)
  assert_eq(policy.service_names()[0], "api")
}

///|
test "localhost policy rejects duplicate service names" {
  let policy = LocalhostPolicy::new()
    .service(
      @lepusa.LocalService::new(
        name="api",
        command=["moon", "run", "cmd/server"],
        readiness_url="http://127.0.0.1:4317/ready",
      ),
    )
    .service(
      @lepusa.LocalService::new(
        name="api",
        command=["moon", "run", "cmd/other"],
        readiness_url="http://127.0.0.1:4318/ready",
      ),
    )
  assert_true(
    policy.validate().contains("localhost service must be unique: api"),
  )
}
