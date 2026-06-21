///|
test "app plugin declares metadata and control commands" {
  let declared = plugin()
  assert_eq(declared.name(), "app")
  assert_true(declared.command_routes().contains("app.info"))
  assert_true(declared.command_routes().contains("app.name"))
  assert_true(declared.command_routes().contains("app.version"))
  assert_true(declared.command_routes().contains("app.identifier"))
  assert_true(declared.command_routes().contains("app.show"))
  assert_true(declared.command_routes().contains("app.hide"))
  assert_true(declared.command_routes().contains("app.setTheme"))
  assert_true(declared.command_routes().contains("app.setDockVisibility"))
  assert_true(declared.command_routes().contains("app.exit"))
  assert_true(declared.command_routes().contains("app.restart"))
  assert_true(declared.command_routes().contains("app.onThemeChanged"))
  for command in declared.commands() {
    assert_true(command.permission() is App)
  }
}

///|
test "app capability grants app permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=App))
  assert_false(grant.allows(window_label="settings", permission=App))
  assert_false(grant.allows(window_label="main", permission=Window))
}

///|
test "app info can be derived from metadata" {
  let info = AppInfo::from_metadata(
    @lepusa.AppMetadata::new(
      identifier="dev.lepusa.demo",
      product_name="Demo App",
      version="1.2.3",
    ),
  )
  assert_eq(info.name(), "Demo App")
  assert_eq(info.version(), "1.2.3")
  assert_eq(info.identifier(), "dev.lepusa.demo")
  assert_eq(info.validate().length(), 0)
  assert_eq(
    AppInfo::new(name="", version="", identifier="").validate().length(),
    3,
  )
}

///|
test "app registry reports metadata and queues controls" {
  let state = AppState::new(
    info=AppInfo::new(
      name="Desk",
      version="2.0.0",
      identifier="dev.lepusa.desk",
    ),
  )
  let registry = register(@lepusa.CommandRegistry::new(), state~)
  let grant = capability_for_window("main")
  let info = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="info",
      window_label="main",
      plugin="app",
      command="info",
    ),
    capabilities=[grant],
  )
  assert_true(info is InvokeOk("info", _))
  assert_true(info.payload().unwrap_or("").contains("\"name\":\"Desk\""))
  assert_true(info.payload().unwrap_or("").contains("\"theme\":\"system\""))
  let theme = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="theme",
      window_label="main",
      plugin="app",
      command="setTheme",
      payload="{\"theme\":\"dark\"}",
    ),
    capabilities=[grant],
  )
  assert_true(theme is InvokeOk("theme", _))
  assert_true(state.theme() is Dark)
  assert_true(state.last().unwrap().action() is SetTheme)
  let hidden = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="hide",
      window_label="main",
      plugin="app",
      command="hide",
    ),
    capabilities=[grant],
  )
  assert_true(hidden is InvokeOk("hide", _))
  assert_false(state.visible())
  let dock = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="dock",
      window_label="main",
      plugin="app",
      command="setDockVisibility",
      payload="false",
    ),
    capabilities=[grant],
  )
  assert_true(dock is InvokeOk("dock", _))
  assert_false(state.dock_visible())
  let restart = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="restart",
      window_label="main",
      plugin="app",
      command="restart",
    ),
    capabilities=[grant],
  )
  assert_true(restart is InvokeOk("restart", _))
  assert_true(state.restart_requested())
  assert_eq(state.operations().length(), 4)
}

///|
test "app registry validates control payloads" {
  let registry = registry()
  let grant = capability_for_window("main")
  let theme = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="bad-theme",
      window_label="main",
      plugin="app",
      command="setTheme",
      payload="\"blue\"",
    ),
    capabilities=[grant],
  )
  assert_true(theme is InvokeError("bad-theme", _))
  assert_true(
    theme.error_message().unwrap_or("").contains("app theme is invalid"),
  )
  let visibility = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="bad-visibility",
      window_label="main",
      plugin="app",
      command="setDockVisibility",
      payload="42",
    ),
    capabilities=[grant],
  )
  assert_true(visibility is InvokeError("bad-visibility", _))
  assert_true(
    visibility
    .error_message()
    .unwrap_or("")
    .contains("app visibility payload must be a boolean or object"),
  )
}
