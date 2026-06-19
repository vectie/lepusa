///|
fn test_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="main",
      title="Runtime",
      width=900,
      height=640,
      source=@lepusa.Source::html("<main>runtime</main>"),
    )
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "runtime host snapshots windows protocols and bridge" {
  let host = RuntimeHost::new(test_plan())
  match host.snapshot() {
    Ok(session) => {
      assert_true(session.backend() is Headless)
      assert_eq(session.asset_protocol(), "lepusa")
      assert_eq(session.command_routes()[0], "core.invoke")
      assert_eq(session.registered_routes().length(), 0)
      assert_true(session.bridge_source().contains("__lepusaInvoke"))
      let windows = session.windows()
      assert_eq(windows.length(), 1)
      assert_eq(windows[0].title(), "Runtime")
      assert_eq(windows[0].width(), 900)
      assert_eq(windows[0].height(), 640)
      assert_eq(windows[0].url(), "lepusa://inline/main/index.html")
      let mappings = session.protocol_mappings()
      assert_eq(mappings.length(), 1)
      assert_eq(mappings[0].window_label(), "main")
      assert_eq(mappings[0].scheme(), "lepusa")
      let files = session.virtual_files()
      assert_eq(files.length(), 1)
      assert_eq(files[0].path(), "index.html")
      assert_eq(files[0].content(), "<main>runtime</main>")
    }
    Err(_) => abort("unexpected invalid runtime session")
  }
}

///|
test "runtime host dispatches through plan capabilities" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
    payload,
  ) {
    Ok("ok:\{payload}")
  })
  let host = RuntimeHost::new(test_plan(), registry~)
  let allowed = host.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="core",
      command="invoke",
      payload="payload",
    ),
  )
  assert_true(allowed is InvokeOk("1", "ok:payload"))
  let denied = host.dispatch(
    @lepusa.InvokeRequest::new(
      id="2",
      window_label="other",
      plugin="core",
      command="invoke",
    ),
  )
  assert_true(denied is InvokeError("2", "permission denied: core.invoke"))
}
