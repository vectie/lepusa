///|
test "runtime host can be created from app manager boundary" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("ping"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.ping"),
    )
  let registry = @lepusa.CommandRegistry::new().register_fn("core.ping", handler=fn(
    payload,
  ) {
    Ok("pong:\{payload}")
  })
  let manager = match
    app.manager(config=@lepusa.RuntimeConfig::headless(), registry~) {
    Ok(manager) => manager
    Err(_) => abort("unexpected invalid manager")
  }
  let host = RuntimeHost::from_manager(manager)
  assert_eq(host.plan().window_count(), 1)
  assert_eq(host.registry().routes()[0], "core.ping")
  let profile = host.security_profile()
  assert_true(profile.ok())
  assert_true(profile.check_handlers())
  assert_eq(profile.exposed_routes().length(), 1)
  assert_eq(profile.exposed_routes()[0], "core.ping")
  let response = host.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="core",
      command="ping",
      payload="host",
    ),
  )
  assert_true(response is InvokeOk("1", "pong:host"))
  match host.snapshot() {
    Ok(session) => {
      assert_true(session.backend() is Headless)
      assert_eq(session.registered_routes()[0], "core.ping")
    }
    Err(_) => abort("unexpected invalid session")
  }
}
