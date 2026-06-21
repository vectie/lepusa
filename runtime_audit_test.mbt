///|
fn audit_test_app(grant? : Bool = true, origin? : String = "") -> @lepusa.App {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let mut capability = @lepusa.Capability::new("core")
    .window("main")
    .command("core.ping")
  if origin != "" {
    capability = capability.origin(origin)
  }
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("ping"))
  if grant {
    app.with_capability(capability)
  } else {
    app
  }
}

///|
fn audit_test_plan(
  grant? : Bool = true,
  origin? : String = "",
) -> @lepusa.RuntimePlan {
  match
    audit_test_app(grant~, origin~).runtime_plan(
      config=@lepusa.RuntimeConfig::headless(),
    ) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "runtime audit reports denied commands and open origin diagnostics" {
  let denied = audit_test_plan(grant=false).audit()
  assert_eq(denied.ok(), false)
  assert_eq(denied.error_count(), 1)
  assert_true(denied.findings()[0].kind() is RuntimeAuditDeniedCommand)
  assert_eq(denied.findings()[0].route(), "core.ping")
  assert_eq(denied.problems()[0], denied.findings()[0].message())
  assert_true(denied.to_json().contains("\"kind\":\"denied-command\""))

  let open = audit_test_plan().audit()
  assert_eq(open.ok(), true)
  assert_eq(open.info_count(), 1)
  assert_true(open.findings()[0].kind() is RuntimeAuditOpenOrigin)

  let scoped = audit_test_plan(origin="https://app.example").audit()
  assert_eq(scoped.ok(), true)
  assert_eq(scoped.findings().length(), 0)
}

///|
test "runtime audit compares command manifest with registered handlers" {
  let plan = audit_test_plan(origin="https://app.example")
  let missing = plan.audit_with_registered_routes([])
  assert_eq(missing.ok(), false)
  assert_true(missing.findings()[0].kind() is RuntimeAuditMissingHandler)
  assert_true(missing.to_json().contains("\"registeredRoutes\":[]"))

  let extra = plan.audit_with_registered_routes(["core.ping", "core.extra"])
  assert_eq(extra.ok(), true)
  assert_eq(extra.warning_count(), 1)
  assert_true(extra.findings()[0].kind() is RuntimeAuditUndeclaredHandler)
  assert_true(extra.registered_routes().contains("core.extra"))
  assert_true(extra.registered_routes().contains("core.ping"))
}

///|
test "app manager audit uses its command registry" {
  let registry = @lepusa.CommandRegistry::new().register_fn("core.ping", handler=fn(
    payload,
  ) {
    Ok(payload)
  })
  let manager = match
    audit_test_app(origin="https://app.example").manager(
      config=@lepusa.RuntimeConfig::headless(),
      registry~,
    ) {
    Ok(manager) => manager
    Err(problems) => abort(problems.join(", "))
  }
  let audit = manager.audit()
  assert_eq(audit.ok(), true)
  assert_eq(audit.findings().length(), 0)
  assert_eq(audit.command_manifest().routes()[0], "core.ping")
  assert_eq(audit.permission_manifest().denied_routes().length(), 0)
}
