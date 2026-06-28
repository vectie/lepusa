///|
test "app scaffold imports desktop project API" {
  let moon_pkg = project_moon_pkg()
  assert_true(moon_pkg.contains("\"vectie/lepusa/desktop\""))
  assert_true(moon_pkg.contains("\"vectie/lepusa/ui\""))
  assert_true(moon_pkg.contains("\"vectie/lepusa\","))
  assert_false(moon_pkg.contains("\"vectie/lepusa/plugins/catalog\""))
}

///|
test "app scaffold keeps code inside src package" {
  let files = app_skeleton_files().map(fn(file) { file.path() })
  assert_true(files.contains("src/moon.pkg"))
  assert_true(files.contains("src/main.mbt"))
  assert_true(!files.contains("moon.pkg"))
  assert_true(!files.contains("main.mbt"))
}

///|
test "app scaffold can include local workspace manifest" {
  let files = app_skeleton_files(lepusa_root="/workspace/lepusa")
  let paths = files.map(fn(file) { file.path() })
  assert_true(paths.contains("moon.work"))
  let workspace = files
    .filter(fn(file) { file.path() == "moon.work" })
    .get(0)
    .unwrap()
    .content()
  assert_true(workspace.contains("\".\""))
  assert_true(workspace.contains("\"/workspace/lepusa\""))
}

///|
test "app scaffold wires official plugin handlers" {
  let main = project_main_mbt()
  assert_true(main.contains("@desktop.DesktopProject::new"))
  assert_true(main.contains("@ui.main_"))
  assert_true(main.contains("@ui.UiProgram::new"))
  assert_true(main.contains("route=\"counter.dispatch\""))
  assert_true(main.contains(".with_registry(program.registry())"))
  assert_true(main.contains(".with_plugin(program.plugin())"))
  assert_true(
    main.contains(".with_capability(program.capability_for_window())"),
  )
  assert_true(main.contains(".with_sync_plugins()"))
  assert_true(main.contains("emit(Increment)"))
  assert_true(main.contains("@ui.text_listener(\"ready\", \"#status\")"))
  assert_true(main.contains("Cmd::emit(@lepusa.Event::new(\"ready\""))
  assert_true(main.contains("ignore([Increment, Reset])"))
  assert_false(main.contains("@catalog.plugin"))
  assert_true(
    main.contains("handlers=\\{project.kit().registered_routes().length()}"),
  )
}

///|
test "app scaffold config only advertises official desktop routes" {
  let config = project_lepusa_json()
  assert_true(config.contains("\"log.write\""))
  assert_true(config.contains("\"store.set\""))
  assert_false(config.contains("core.invoke"))
  assert_false(config.contains("core.events"))
}

///|
test "app scaffold readme documents desktop project usage" {
  let readme = project_readme()
  assert_true(readme.contains("@lepusa/desktop.DesktopProject"))
  assert_true(readme.contains("@lepusa/ui"))
  assert_true(readme.contains("UiProgram"))
  assert_true(readme.contains("moon run src --target native"))
  assert_true(readme.contains("runtime hosts"))
}

///|
test "plugin scaffold keeps implementation inside src package" {
  let files = plugin_skeleton_files("demo").map(fn(file) { file.path() })
  assert_true(files.contains("src/moon.pkg"))
  assert_true(files.contains("src/plugin.mbt"))
  assert_true(!files.contains("moon.pkg"))
  assert_true(!files.contains("plugin.mbt"))
}

///|
test "plugin scaffold can include local workspace manifest" {
  let files = plugin_skeleton_files("demo", lepusa_root="/workspace/lepusa")
  let paths = files.map(fn(file) { file.path() })
  assert_true(paths.contains("moon.work"))
  let workspace = files
    .filter(fn(file) { file.path() == "moon.work" })
    .get(0)
    .unwrap()
    .content()
  assert_true(workspace.contains("\".\""))
  assert_true(workspace.contains("\"/workspace/lepusa\""))
}
