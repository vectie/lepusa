///|
fn audit_verify_host_and_bundle() -> (@runtime.RuntimeHost, @lepusa.BundlePlan) {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main>audit</main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main>audit</main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("ping"))
  let plan = match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
  let registry = @lepusa.CommandRegistry::new().register_fn("core.ping", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  let host = @runtime.RuntimeHost::new(plan, registry~)
  let bundle = match
    @lepusa.BundleConfig::new(
      @lepusa.AppMetadata::new(
        identifier="dev.vectie.audit",
        product_name="Audit App",
        version="0.1.0",
      ),
      target=Linux,
    ).plan(plan, registered_routes=registry.routes()) {
    Ok(bundle) => bundle
    Err(problems) => abort(problems.join(", "))
  }
  (host, bundle)
}

///|
async test "verify json includes runtime audit diagnostics" {
  let result = render_cli_async(["verify", "linux", "--json"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"audit\":{"))
  assert_true(result.output.contains("\"errorCount\":0"))
  assert_true(result.output.contains("\"findings\":["))
  assert_true(result.output.contains("\"commandManifest\":{"))
  assert_true(result.output.contains("\"permissionManifest\":{"))
}

///|
async test "strict verify fails runtime audit errors beyond missing handlers" {
  let (host, bundle) = audit_verify_host_and_bundle()
  let relaxed = render_verify_project(
    Linux,
    host,
    bundle,
    strict=false,
    json=false,
  )
  assert_eq(relaxed.exit_code, 0)
  assert_true(relaxed.output.contains("[warn] audit: errors=1"))
  let strict = render_verify_project(
    Linux,
    host,
    bundle,
    strict=true,
    json=false,
  )
  assert_eq(strict.exit_code, 1)
  assert_true(strict.output.contains("[fail] strict: runtime audit errors=1"))
  assert_true(strict.output.contains("\"denied-command\"") == false)
  let strict_json = render_verify_project(
    Linux,
    host,
    bundle,
    strict=true,
    json=true,
  )
  assert_eq(strict_json.exit_code, 1)
  assert_true(strict_json.output.contains("\"audit\":{"))
  assert_true(strict_json.output.contains("\"kind\":\"denied-command\""))
  assert_true(strict_json.output.contains("\"ok\":false"))
}
