///|
test "app scaffold imports official plugin catalog" {
  let moon_pkg = project_moon_pkg()
  assert_true(moon_pkg.contains("\"vectie/lepusa/plugins/catalog\""))
  assert_true(moon_pkg.contains("\"vectie/lepusa/ui\""))
  assert_true(moon_pkg.contains("\"vectie/lepusa\","))
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
  assert_true(main.contains("@catalog.register"))
  assert_true(main.contains("@ui.main_"))
  assert_true(main.contains("@ui.UiProgram::new"))
  assert_true(main.contains("route=\"counter.dispatch\""))
  assert_true(main.contains("program.register"))
  assert_true(main.contains(".with_plugin(program.plugin())"))
  assert_true(
    main.contains(".with_capability(program.capability_for_window())"),
  )
  assert_true(main.contains("dispatch(Increment)"))
  assert_true(main.contains("@ui.text_listener(\"ready\", \"#status\")"))
  assert_true(main.contains("Cmd::emit(@lepusa.Event::new(\"ready\""))
  assert_true(main.contains("ignore([Increment, Reset])"))
  assert_true(main.contains("@catalog.plugin(\"log\").unwrap()"))
  assert_true(main.contains("@catalog.plugin(\"store\").unwrap()"))
  assert_true(main.contains("handlers=\\{registry.routes().length()}"))
}

///|
test "app scaffold config only advertises catalog registered routes" {
  let config = project_lepusa_json()
  assert_true(config.contains("\"log.write\""))
  assert_true(config.contains("\"store.set\""))
  assert_false(config.contains("core.invoke"))
  assert_false(config.contains("core.events"))
}

///|
test "app scaffold readme documents catalog usage" {
  let readme = project_readme()
  assert_true(readme.contains("@lepusa/plugins/catalog"))
  assert_true(readme.contains("@lepusa/ui"))
  assert_true(readme.contains("UiProgram"))
  assert_true(readme.contains("moon run src --target native"))
  assert_true(readme.contains("MoonBit-native handlers"))
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
