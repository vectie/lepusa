///|
test "desktop kit installs official plugin metadata and handlers together" {
  let kit = DesktopKit::new().with_plugin("log").with_plugin("clipboard")
  assert_eq(kit.validate().length(), 0)
  assert_true(kit.plugin_names().contains("log"))
  assert_true(kit.plugin_names().contains("clipboard"))
  assert_true(kit.registered_routes().contains("log.write"))
  assert_true(kit.registered_routes().contains("clipboard.readText"))
  assert_eq(kit.capabilities().length(), 2)
  assert_true(kit.capabilities()[0].windows().contains("main"))
}

///|
test "desktop kit applies plugins and capabilities to app runtime" {
  let kit = DesktopKit::new().with_plugins(["log", "clipboard"])
  let base = @lepusa.new(
    @lepusa.simple_cell(@lepusa.Html::text("<main>desktop</main>")),
  ).window(source=@lepusa.Source::html("<main>desktop</main>"))
  match kit.apply(base) {
    Ok(app) =>
      match app.runtime_plan() {
        Ok(plan) => {
          assert_true(plan.command_routes().contains("log.write"))
          assert_true(plan.command_routes().contains("clipboard.readText"))
          assert_true(plan.window_command_routes("main").contains("log.write"))
          assert_true(
            plan.window_command_routes("main").contains("clipboard.readText"),
          )
          match kit.runtime_host(plan) {
            Ok(host) => {
              assert_true(host.sync_command_routes().contains("log.write"))
              assert_true(
                host.async_command_routes().contains("clipboard.readText"),
              )
              let response = host.dispatch(
                @lepusa.InvokeRequest::new(
                  id="1",
                  window_label="main",
                  plugin="log",
                  command="write",
                  payload="{\"message\":\"ready\"}",
                ),
              )
              assert_true(response.error_message() is None)
            }
            Err(problems) => abort(problems.join("; "))
          }
        }
        Err(problems) => abort(problems.join("; "))
      }
    Err(problems) => abort(problems.join("; "))
  }
}

///|
test "desktop kit reports unknown official plugins before app planning" {
  let kit = DesktopKit::new().with_plugin("missing")
  let problems = kit.validate()
  assert_eq(problems.length(), 1)
  assert_eq(problems[0], "unknown official plugin: missing")
}

///|
async test "desktop kit passes policies into catalog registries" {
  let scope = @lepusa.FileSystemScope::new(
    name="data",
    root="/tmp/lepusa-desktop-kit",
    writable=true,
  )
  let kit = DesktopKit::new().with_plugin("fs").with_filesystem_scope(scope)
  match
    kit.apply(
      @lepusa.new(@lepusa.simple_cell(@lepusa.Html::text("<main></main>"))).window(
        source=@lepusa.Source::html("<main></main>"),
      ),
    ) {
    Ok(app) =>
      match app.runtime_plan() {
        Ok(plan) =>
          match kit.runtime_host(plan) {
            Ok(host) => {
              let response = host.dispatch_async(
                @lepusa.InvokeRequest::new(
                  id="1",
                  window_label="main",
                  plugin="fs",
                  command="exists",
                  payload="{\"scope\":\"data\",\"path\":\"note.txt\"}",
                ),
              )
              assert_true(response.error_message() is None)
            }
            Err(problems) => abort(problems.join("; "))
          }
        Err(problems) => abort(problems.join("; "))
      }
    Err(problems) => abort(problems.join("; "))
  }
}
