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
test "capability policy validates capability set" {
  let policy = @lepusa.CapabilityPolicy::new(capabilities=[
    @lepusa.Capability::new("dup").permission(FileSystemRead),
    @lepusa.Capability::new("dup").permission(FileSystemWrite),
    @lepusa.Capability::new("empty"),
  ])
  let problems = policy.validate()
  assert_true(problems.contains("capability name must be unique: dup"))
  assert_true(
    problems.contains("capability must include at least one permission"),
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
}
