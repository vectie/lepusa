///|
test "invoke requests carry resolver ids" {
  let request = @lepusa.InvokeRequest::new(
    id="cb-1",
    window_label="main",
    plugin="core",
    command="invoke",
    payload="{}",
    callback_id="cb-1",
    error_id="err-1",
  )
  assert_eq(request.callback_id(), "cb-1")
  assert_eq(request.error_id(), "err-1")
  assert_eq(request.has_resolver_ids(), true)
  assert_eq(request.validate().is_empty(), true)
  let without_resolver = @lepusa.InvokeRequest::new(
    id="legacy-shape",
    window_label="main",
    plugin="core",
    command="invoke",
  )
  assert_eq(without_resolver.has_resolver_ids(), false)
}

///|
test "frontend bridge emits invoke resolver ids" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) =>
      match
        plan.bridge_script(
          config=@lepusa.BridgeConfig::new(window_label="main"),
        ) {
        Ok(script) => {
          assert_true(
            script.source().contains("const callbackId = String(++nextId);"),
          )
          assert_true(
            script.source().contains("const errorId = String(++nextId);"),
          )
          assert_true(script.source().contains("id: callbackId"))
          assert_true(script.source().contains("callback_id: callbackId"))
          assert_true(script.source().contains("error_id: errorId"))
        }
        Err(_) => abort("unexpected invalid bridge script")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}
