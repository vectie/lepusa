# @lepusa/desktop

`@lepusa/desktop` is the app-facing kit for official desktop capabilities. It
keeps official plugin declarations, capability grants, and runtime command
handlers in one place so an app does not accidentally expose a command in the
bridge without registering its native handler.

```mbt check
///|
test "build an app with official desktop plugins" {
  let kit = DesktopKit::new().with_plugins(["log", "clipboard"])
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
                host.async_command_routes().contains("clipboard.readText"),
              )
              assert_true(host.sync_command_routes().contains("log.write"))
            }
            Err(problems) => fail(problems.join("; "))
          }
        Err(problems) => fail(problems.join("; "))
      }
    Err(problems) => fail(problems.join("; "))
  }
}
```

