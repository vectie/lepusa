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
          assert_true(
            script
            .source()
            .contains("emit: (name, payload = null) => emitNative"),
          )
          assert_true(script.source().contains("emitTo: (target, name"))
          assert_true(script.source().contains("\"__lepusa\", \"event.emit\""))
          assert_true(
            script
            .source()
            .contains(
              "payload: payload == null ? \"\" : JSON.stringify(payload)",
            ),
          )
          assert_true(script.source().contains("class LepusaInvokeError"))
          assert_true(script.source().contains("const createInvokeError"))
          assert_true(script.source().contains("response.errorCode"))
          assert_true(script.source().contains("const withInvokeControls"))
          assert_true(
            script.source().contains("invokeControlError(\"timeout\""),
          )
          assert_true(
            script.source().contains("invokeControlError(\"cancelled\""),
          )
          assert_true(
            script.source().contains("signal.addEventListener(\"abort\""),
          )
          assert_true(
            script
            .source()
            .contains("throw createInvokeError(response, route);"),
          )
          assert_true(script.source().contains("isInvokeError: (error) =>"))
        }
        Err(_) => abort("unexpected invalid bridge script")
      }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}
