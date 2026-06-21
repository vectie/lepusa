# @lepusa/plugins/app

`@lepusa/plugins/app` defines Lepusa's official app-level desktop surface:
metadata queries, app visibility controls, theme selection, dock visibility, and
queued exit or restart requests.

```mbt check
///|
test "declare app metadata and controls" {
  let plugin = @app.plugin()
  assert_true(plugin.command_routes().contains("app.info"))
  assert_true(plugin.command_routes().contains("app.setTheme"))
  assert_true(plugin.command_routes().contains("app.restart"))

  let grant = @app.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=App))

  let state = @app.AppState::new(
    info=@app.AppInfo::new(
      name="Demo",
      version="1.0.0",
      identifier="dev.lepusa.demo",
    ),
  )
  let registry = @app.register(@lepusa.CommandRegistry::new(), state~)
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="theme",
      window_label="main",
      plugin="app",
      command="setTheme",
      payload="\"dark\"",
    ),
    capabilities=[grant],
  )
  assert_true(response.error_message() is None)
  assert_true(state.theme() is Dark)
}
```
