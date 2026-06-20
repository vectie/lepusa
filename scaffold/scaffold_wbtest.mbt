///|
test "app scaffold imports official plugin catalog" {
  let moon_pkg = project_moon_pkg()
  assert_true(moon_pkg.contains("\"vectie/lepusa/plugins/catalog\""))
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
test "app scaffold wires official plugin handlers" {
  let main = project_main_mbt()
  assert_true(main.contains("@catalog.register"))
  assert_true(main.contains("@catalog.plugin(\"log\").unwrap()"))
  assert_true(main.contains("@catalog.plugin(\"store\").unwrap()"))
  assert_true(main.contains("handlers=\\{registry.routes().length()}"))
}

///|
test "app scaffold readme documents catalog usage" {
  let readme = project_readme()
  assert_true(readme.contains("@lepusa/plugins/catalog"))
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
