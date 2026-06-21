# @lepusa/plugins/menu

`@lepusa/plugins/menu` defines Lepusa's official app and window menu surface.
It covers nested native menu declarations, accelerators, item state updates, and
menu item activation events.

```mbt check
///|
test "declare app menu controls" {
  let plugin = @menu.plugin()
  assert_true(plugin.command_routes().contains("menu.setAppMenu"))
  assert_true(plugin.command_routes().contains("menu.onItemClick"))

  let grant = @menu.capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Menu))

  let state = @menu.MenuState::new()
  let registry = @menu.register(@lepusa.CommandRegistry::new(), state~)
  let payload = "{\"items\":[{\"id\":\"file\",\"label\":\"File\",\"kind\":\"submenu\",\"items\":[{\"id\":\"new\",\"label\":\"New\",\"accelerator\":\"CmdOrCtrl+N\"}]}]}"
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="menu",
      window_label="main",
      plugin="menu",
      command="setAppMenu",
      payload~,
    ),
    capabilities=[grant],
  )
  assert_true(response.error_message() is None)
  assert_true(state.app_menu() is Some(_))
}
```
