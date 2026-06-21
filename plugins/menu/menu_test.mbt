///|
test "menu plugin declares sync menu commands" {
  let declared = plugin()
  assert_eq(declared.name(), "menu")
  assert_true(declared.command_routes().contains("menu.setAppMenu"))
  assert_true(declared.command_routes().contains("menu.setWindowMenu"))
  assert_true(declared.command_routes().contains("menu.clearAppMenu"))
  assert_true(declared.command_routes().contains("menu.clearWindowMenu"))
  assert_true(declared.command_routes().contains("menu.setItemEnabled"))
  assert_true(declared.command_routes().contains("menu.setItemChecked"))
  assert_true(declared.command_routes().contains("menu.activateItem"))
  assert_true(declared.command_routes().contains("menu.onItemClick"))
  for command in declared.commands() {
    assert_true(command.permission() is Menu)
  }
}

///|
test "menu capability grants menu permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Menu))
  assert_false(grant.allows(window_label="settings", permission=Menu))
  assert_false(grant.allows(window_label="main", permission=Tray))
}

///|
test "menu model validates nested items and accelerators" {
  let menu = MenuBar::new(items=[
    MenuItem::submenu(id="file", label="File", items=[
      MenuItem::action(id="new", label="New", accelerator="CmdOrCtrl+N"),
      MenuItem::check(id="autosave", label="Autosave", checked=true),
    ]),
  ])
  assert_eq(menu.validate().length(), 0)
  let invalid = MenuBar::new(items=[
    MenuItem::action(id="bad id", label="", accelerator="Cmd\nN"),
    MenuItem::action(id="bad id", label="Again"),
  ])
  let problems = invalid.validate()
  assert_true(problems.contains("menu item id is invalid: bad id"))
  assert_true(problems.contains("menu item label is required"))
  assert_true(problems.contains("menu item accelerator is invalid: Cmd\nN"))
  assert_true(problems.contains("menu item must be unique: bad id"))
}

///|
test "menu registry sets app menu and updates nested items" {
  let state = MenuState::new()
  let registry = register(@lepusa.CommandRegistry::new(), state~)
  let grant = capability_for_window("main")
  let app_menu_payload = "{\"items\":[{\"id\":\"file\",\"label\":\"File\",\"kind\":\"submenu\",\"items\":[{\"id\":\"new\",\"label\":\"New\",\"accelerator\":\"CmdOrCtrl+N\"},{\"id\":\"autosave\",\"label\":\"Autosave\",\"kind\":\"check\",\"checked\":false}]}]}"
  let set = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="set",
      window_label="main",
      plugin="menu",
      command="setAppMenu",
      payload=app_menu_payload,
    ),
    capabilities=[grant],
  )
  match set {
    InvokeOk("set", _) => ()
    InvokeError(_, failure) => abort(failure.message())
    _ => abort("unexpected set response")
  }
  assert_true(state.app_menu() is Some(_))
  let enabled = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="disable",
      window_label="main",
      plugin="menu",
      command="setItemEnabled",
      payload="{\"id\":\"new\",\"enabled\":false}",
    ),
    capabilities=[grant],
  )
  assert_true(enabled is InvokeOk("disable", _))
  let checked = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="check",
      window_label="main",
      plugin="menu",
      command="setItemChecked",
      payload="{\"id\":\"autosave\",\"checked\":true}",
    ),
    capabilities=[grant],
  )
  assert_true(checked is InvokeOk("check", _))
  let activate = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="activate",
      window_label="main",
      plugin="menu",
      command="activateItem",
      payload="\"new\"",
    ),
    capabilities=[grant],
  )
  assert_true(activate is InvokeOk("activate", _))
  assert_eq(state.last_activated().unwrap_or(""), "new")
  assert_eq(state.operations().length(), 4)
}

///|
test "menu registry sets and clears window menus" {
  let state = MenuState::new()
  let registry = register(@lepusa.CommandRegistry::new(), state~)
  let grant = capability_for_window("main")
  let window_menu_payload = "{\"windowLabel\":\"main\",\"items\":[{\"id\":\"view\",\"label\":\"View\"}]}"
  let set = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="set-window",
      window_label="main",
      plugin="menu",
      command="setWindowMenu",
      payload=window_menu_payload,
    ),
    capabilities=[grant],
  )
  match set {
    InvokeOk("set-window", _) => ()
    InvokeError(_, failure) => abort(failure.message())
    _ => abort("unexpected set window response")
  }
  assert_true(state.window_menu("main") is Some(_))
  let clear = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="clear-window",
      window_label="main",
      plugin="menu",
      command="clearWindowMenu",
      payload="\"main\"",
    ),
    capabilities=[grant],
  )
  assert_true(clear is InvokeOk("clear-window", _))
  assert_true(state.window_menu("main") is None)
}

///|
test "menu registry validates payloads and missing items" {
  let registry = registry()
  let grant = capability_for_window("main")
  let invalid = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="invalid",
      window_label="main",
      plugin="menu",
      command="setAppMenu",
      payload="{\"items\":[{\"id\":\"bad id\",\"label\":\"Bad\"}]}",
    ),
    capabilities=[grant],
  )
  assert_eq(invalid.id(), "invalid")
  assert_true(
    invalid.error_message().unwrap_or("").contains("menu item id is invalid"),
  )
  let missing = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="missing",
      window_label="main",
      plugin="menu",
      command="activateItem",
      payload="\"missing\"",
    ),
    capabilities=[grant],
  )
  assert_eq(missing.id(), "missing")
  assert_true(
    missing.error_message().unwrap_or("").contains("menu item not found"),
  )
}
