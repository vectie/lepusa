# @lepusa/plugins/fs

`@lepusa/plugins/fs` defines Lepusa's official filesystem plugin contract.

It is intentionally a policy and permission package first: it declares the
stable command routes and validates scoped relative paths. Native runtimes can
then implement real filesystem IO behind the same command contract without app
authors changing their manifests.

```moonbit nocheck
///|
test "declare scoped fs access" {
  let plugin = @fs.plugin()
  assert_true(plugin.command_routes().contains("fs.readText"))
  assert_true(plugin.command_routes().contains("fs.writeText"))

  let grant = @fs.read_capability_for_window("main")
  assert_true(
    grant.allows(window_label="main", permission=@lepusa.FileSystemRead),
  )
}
```

```moonbit nocheck
///|
test "resolve paths inside named scopes" {
  let policy = @fs.FsPolicy::new()
    .scope(@lepusa.FileSystemScope::new(name="assets", root="/app/assets"))
    .scope(
      @lepusa.FileSystemScope::new(name="data", root="/app/data", writable=true),
    )

  assert_eq(
    policy.resolve(scope_name="assets", path="icons/main.png").unwrap(),
    "/app/assets/icons/main.png",
  )
  assert_true(
    policy.resolve(scope_name="assets", path="../secret")
    is Err("unsafe filesystem path: ../secret"),
  )
}
```
