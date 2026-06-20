# @lepusa/desktop

`@lepusa/desktop` is the app-facing kit for official desktop capabilities. It
keeps official plugin declarations, capability grants, and runtime command
handlers in one place so an app does not accidentally expose a command in the
bridge without registering its native handler.

```mbt check
///|
test "build a desktop project" {
  let project = DesktopProject::new(
      @lepusa.AppMetadata::new(
        identifier="dev.lepusa.desktop",
        product_name="Lepusa Desktop",
        version="0.1.0",
      ),
      @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
    )
    .window(source=@lepusa.Source::html("<main></main>"))
    .with_sync_plugins()
  match project.runtime_host() {
    Ok(host) => {
      assert_true(host.sync_command_routes().contains("log.write"))
      assert_true(host.sync_command_routes().contains("clipboard.readText"))
    }
    Err(problems) => fail(problems.join("; "))
  }
  match project.bundle_plan(target=Linux) {
    Ok(bundle) =>
      assert_true(bundle.registered_routes().contains("clipboard.readText"))
    Err(problems) => fail(problems.join("; "))
  }
}
```

```mbt check
///|
test "build an app with official desktop plugins" {
  let kit = DesktopKit::new().with_sync_plugins()
  let base = @lepusa.new(
    @lepusa.simple_cell(@lepusa.Html::text("<main></main>")),
  ).window(source=@lepusa.Source::html("<main></main>"))
  match kit.apply(base) {
    Ok(app) =>
      match app.runtime_plan() {
        Ok(plan) =>
          match kit.runtime_host(plan) {
            Ok(host) => {
              assert_true(
                host.sync_command_routes().contains("clipboard.readText"),
              )
              assert_true(host.sync_command_routes().contains("log.write"))
              assert_eq(host.async_command_routes().length(), 0)
            }
            Err(problems) => fail(problems.join("; "))
          }
        Err(problems) => fail(problems.join("; "))
      }
    Err(problems) => fail(problems.join("; "))
  }
}
```
