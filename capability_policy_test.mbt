///|
test "capability policy explains allow and deny decisions" {
  let policy = @lepusa.CapabilityPolicy::new(capabilities=[
    @lepusa.Capability::new("main-fs").window("main").permission(FileSystemRead),
  ])
  let allowed = policy.evaluate(window_label="main", permission=FileSystemRead)
  assert_eq(allowed.allowed(), true)
  assert_eq(allowed.denied(), false)
  assert_eq(allowed.capability(), "main-fs")
  assert_eq(allowed.reason(), "")
  assert_eq(allowed.permission().name(), "filesystem.read")
  assert_true(allowed.to_json().contains("\"allowed\":true"))
  let denied = policy.evaluate(
    window_label="settings",
    permission=FileSystemRead,
  )
  assert_eq(denied.allowed(), false)
  assert_eq(denied.denied(), true)
  assert_eq(denied.capability(), "")
  assert_eq(
    denied.reason(),
    "permission denied for window settings: filesystem.read",
  )
  assert_true(denied.to_json().contains("\"allowed\":false"))
}

///|
test "capability policy can scope grants to origins" {
  let policy = @lepusa.CapabilityPolicy::new(capabilities=[
    @lepusa.Capability::new("remote-fs")
    .window("main")
    .origin("https://app.example")
    .permission(FileSystemRead),
  ])
  let allowed = policy.evaluate(
    window_label="main",
    origin="https://app.example",
    permission=FileSystemRead,
  )
  assert_true(allowed.allowed())
  assert_eq(allowed.origin(), "https://app.example")
  let denied = policy.evaluate(
    window_label="main",
    origin="https://evil.example",
    permission=FileSystemRead,
  )
  assert_true(denied.denied())
  assert_true(denied.reason().contains("origin https://evil.example"))
  let origins = policy.allowed_origins(
    window_label="main",
    permission=FileSystemRead,
  )
  assert_eq(origins.length(), 1)
  assert_eq(origins[0], "https://app.example")
}

///|
test "capability policy scopes sensitive operations deny by default" {
  let policy = @lepusa.CapabilityPolicy::new(capabilities=[
    @lepusa.Capability::new("main-files")
    .window("main")
    .permission(FileSystemRead)
    .path_scope(root="/app/data"),
    @lepusa.Capability::new("shell")
    .window("main")
    .permission(Shell)
    .shell_scope("moon"),
  ])
  let allowed = policy.evaluate_operation(
    window_label="main",
    permission=FileSystemRead,
    scope=@lepusa.OperationScope::path(root="/app/data/config.json"),
  )
  assert_true(allowed.allowed())
  assert_eq(allowed.capability(), "main-files")
  let denied_path = policy.evaluate_operation(
    window_label="main",
    permission=FileSystemRead,
    scope=@lepusa.OperationScope::path(root="/etc/passwd"),
  )
  assert_true(denied_path.denied())
  assert_true(denied_path.reason().contains("operation scope denied"))
  let denied_shell = policy.evaluate_operation(
    window_label="main",
    permission=Shell,
    scope=@lepusa.OperationScope::shell("rm"),
  )
  assert_true(denied_shell.denied())
  assert_true(policy.allows(window_label="main", permission=Shell))
  assert_false(
    policy.allows_operation(
      window_label="main",
      permission=Shell,
      scope=@lepusa.OperationScope::shell("rm"),
    ),
  )
}

///|
test "capability policy validates capability set" {
  let policy = @lepusa.CapabilityPolicy::new(capabilities=[
    @lepusa.Capability::new("dup").permission(FileSystemRead),
    @lepusa.Capability::new("dup").permission(FileSystemWrite),
    @lepusa.Capability::new("empty"),
    @lepusa.Capability::new("bad-origin").origin("").permission(Network),
  ])
  let problems = policy.validate()
  assert_true(problems.contains("capability name must be unique: dup"))
  assert_true(
    problems.contains("capability must include at least one permission"),
  )
  assert_true(problems.contains("capability origin must not be empty"))
  assert_true(
    @lepusa.Capability::new("bad-scope")
    .permission(Shell)
    .shell_scope("moon test")
    .validate()
    .contains("shell operation scope command must be a single executable"),
  )
}

///|
test "capability policy serializes grants for diagnostics" {
  let policy = @lepusa.CapabilityPolicy::new(capabilities=[
    @lepusa.Capability::new("global-shell").permission(Shell),
    @lepusa.Capability::new("main-dialog").window("main").permission(Dialog),
  ])
  assert_eq(policy.capabilities().length(), 2)
  assert_true(policy.allows(window_label="settings", permission=Shell))
  assert_false(policy.allows(window_label="settings", permission=Dialog))
  let json = policy.to_json()
  assert_true(json.contains("\"name\":\"global-shell\""))
  assert_true(json.contains("\"permissions\":[\"shell\"]"))
  assert_true(json.contains("\"windows\":[\"main\"]"))
  assert_true(json.contains("\"origins\":[]"))
  assert_true(json.contains("\"operationScopes\""))
}
