///|
test "operation scopes match path shell and url requests" {
  let read_scope = @lepusa.OperationScope::path(root="/app/data")
  let write_scope = @lepusa.OperationScope::path(
    root="/app/data",
    writable=true,
  )
  assert_true(
    read_scope.allows(@lepusa.OperationScope::path(root="/app/data/file.txt")),
  )
  assert_false(
    read_scope.allows(
      @lepusa.OperationScope::path(root="/app/data/file.txt", writable=true),
    ),
  )
  assert_true(
    write_scope.allows(
      @lepusa.OperationScope::path(root="/app/data/file.txt", writable=true),
    ),
  )
  assert_false(
    write_scope.allows(@lepusa.OperationScope::path(root="/app/other.txt")),
  )
  assert_true(
    @lepusa.OperationScope::shell("moon").allows(
      @lepusa.OperationScope::shell("moon"),
    ),
  )
  assert_false(
    @lepusa.OperationScope::shell("moon").allows(
      @lepusa.OperationScope::shell("rm"),
    ),
  )
  assert_true(
    @lepusa.OperationScope::url("https://api.example").allows(
      @lepusa.OperationScope::url("https://api.example"),
    ),
  )
}

///|
test "operation scopes validate deny-by-default resources" {
  let problems : Array[String] = []
  for
    scope in [
      @lepusa.OperationScope::path(root=""),
      @lepusa.OperationScope::shell("moon test"),
      @lepusa.OperationScope::url("file:///tmp/a.txt"),
      @lepusa.OperationScope::url("https://api.example/v1"),
    ] {
    problems.append(scope.validate())
  }
  assert_true(problems.contains("path operation scope value is required"))
  assert_true(
    problems.contains(
      "shell operation scope command must be a single executable",
    ),
  )
  assert_true(
    problems.contains(
      "url operation scope origin must be http(s): file:///tmp/a.txt",
    ),
  )
  assert_true(
    problems.contains(
      "url operation scope origin must be http(s): https://api.example/v1",
    ),
  )
  assert_true(
    @lepusa.OperationScope::path(root="/tmp", writable=true)
    .to_json()
    .contains("\"writable\":true"),
  )
}
