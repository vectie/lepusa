///|
fn runtime_audit_host(registered? : Bool = true) -> RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("ping"))
    .with_capability(
      @lepusa.Capability::new("core")
      .window("main")
      .origin("https://app.example")
      .command("core.ping"),
    )
  let registry = if registered {
    @lepusa.CommandRegistry::new().register_fn("core.ping", handler=fn(
      payload,
    ) {
      Ok(payload)
    })
  } else {
    @lepusa.CommandRegistry::new()
  }
  let manager = match
    app.manager(config=@lepusa.RuntimeConfig::headless(), registry~) {
    Ok(manager) => manager
    Err(problems) => abort(problems.join(", "))
  }
  RuntimeHost::from_manager(manager)
}

///|
test "runtime host audit reports native handler coverage" {
  let ready = runtime_audit_host()
  assert_eq(ready.audit().ok(), true)
  assert_eq(ready.audit().registered_routes()[0], "core.ping")

  let missing = runtime_audit_host(registered=false).audit()
  assert_eq(missing.ok(), false)
  assert_eq(missing.error_count(), 1)
  assert_true(missing.findings()[0].kind() is RuntimeAuditMissingHandler)
}
