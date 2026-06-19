///|
test "fs plugin declares permissioned async commands" {
  let declared = plugin()
  assert_eq(declared.name(), "fs")
  assert_eq(declared.command_routes().length(), 9)
  assert_true(declared.command_routes().contains("fs.readText"))
  assert_true(declared.command_routes().contains("fs.writeText"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is FileSystemRead)
  assert_true(commands[5].permission() is FileSystemWrite)
}

///|
test "fs capabilities split read write and scoped window grants" {
  let read = read_capability_for_window("main")
  assert_true(read.allows(window_label="main", permission=FileSystemRead))
  assert_false(read.allows(window_label="main", permission=FileSystemWrite))
  assert_false(read.allows(window_label="other", permission=FileSystemRead))
  let both = read_write_capability()
  assert_true(both.allows(window_label="any", permission=FileSystemRead))
  assert_true(both.allows(window_label="any", permission=FileSystemWrite))
}

///|
test "fs policy validates scopes and resolves safe relative paths" {
  let policy = FsPolicy::new()
    .scope(@lepusa.FileSystemScope::new(name="assets", root="/app/assets"))
    .scope(
      @lepusa.FileSystemScope::new(
        name="data",
        root="/app/data/",
        writable=true,
      ),
    )
  assert_eq(policy.validate().length(), 0)
  assert_true(policy.scopes()[1].writable())
  assert_eq(
    policy.resolve(scope_name="assets", path="icons/main.png").unwrap(),
    "/app/assets/icons/main.png",
  )
  assert_eq(
    policy.resolve(scope_name="data", path="config.json", write=true).unwrap(),
    "/app/data/config.json",
  )
}

///|
test "fs policy rejects unsafe paths and read-only writes" {
  let policy = FsPolicy::new().scope(
    @lepusa.FileSystemScope::new(name="assets", root="/app/assets"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="../secret")
    is Err("unsafe filesystem path: ../secret"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="/etc/passwd")
    is Err("filesystem path must be relative"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="a\\b")
    is Err("unsafe filesystem path: a\\b"),
  )
  assert_true(
    policy.resolve(scope_name="assets", path="config.json", write=true)
    is Err("filesystem scope is read-only: assets"),
  )
  assert_true(
    policy.resolve(scope_name="missing", path="config.json")
    is Err("unknown filesystem scope: missing"),
  )
}

///|
test "fs policy reports invalid and duplicate scopes" {
  let problems = FsPolicy::new()
    .scope(@lepusa.FileSystemScope::new(name="", root=""))
    .scope(@lepusa.FileSystemScope::new(name="bad/name", root="/tmp"))
    .scope(@lepusa.FileSystemScope::new(name="bad/name", root="/tmp2"))
    .validate()
  assert_true(problems.contains("filesystem scope name is required"))
  assert_true(problems.contains("filesystem scope root is required"))
  assert_true(
    problems.contains("filesystem scope name must not contain path separators"),
  )
  assert_true(problems.contains("filesystem scope must be unique: bad/name"))
}
