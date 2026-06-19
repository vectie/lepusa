///|
test "help text names available commands" {
  let result = render_cli([])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("lepusa doctor"))
  assert_true(result.output.contains("lepusa bridge"))
  assert_true(result.output.contains("lepusa manifest"))
  assert_true(result.output.contains("lepusa init"))
  assert_true(result.output.contains("lepusa build"))
  assert_true(result.output.contains("lepusa bundle"))
  assert_true(result.output.contains("lepusa bundle-plan"))
  assert_true(result.output.contains("lepusa bundle-write"))
}

///|
test "doctor renders framework boundary checks" {
  let result = render_cli(["doctor"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("[ok] public-api"))
  assert_true(result.output.contains("backend=headless"))
  assert_true(result.output.contains("[ok] manifest: webviews=1 routes=2"))
}

///|
test "runtime plan prints command routes" {
  let result = render_cli(["plan"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("windows: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("routes: core.invoke,core.events"))
}

///|
test "manifest prints native runner json" {
  let result = render_cli(["manifest"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"backend\":\"headless\""))
  assert_true(
    result.output.contains("\"url\":\"lepusa://rabbita/main/index.html\""),
  )
  assert_true(result.output.contains("\"webviews\""))
  assert_true(result.output.contains("\"protocolMappings\""))
  assert_true(result.output.contains("\"virtualFiles\""))
  assert_true(result.output.contains("\"startupActions\""))
  assert_true(result.output.contains("\"mimeType\":\"text/html\""))
  assert_true(
    result.output.contains("\"eventDispatchHook\":\"__lepusaDispatchEvent\""),
  )
  assert_true(
    result.output.contains(
      "\"commandRoutes\":[\"core.invoke\",\"core.events\"]",
    ),
  )
  assert_true(result.output.contains("\"initializationScripts\""))
  assert_true(result.output.contains("__lepusaInvoke"))
}

///|
test "bundle plan supports target selection" {
  let result = render_cli(["bundle-plan", "windows"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: windows"))
  assert_true(result.output.contains("bundle: lepusa-example.exe"))
  assert_true(result.output.contains("files: 2"))
}

///|
async test "init writes standalone project skeleton" {
  let root = "/tmp/lepusa-init-\{@async.now().to_int()}"
  let result = render_cli_async(["init", root])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa init"))
  assert_true(result.output.contains("files: 4"))
  assert_true(@fs.exists(root + "/moon.mod"))
  assert_true(@fs.exists(root + "/moon.pkg"))
  assert_true(@fs.exists(root + "/main.mbt"))
  assert_true(@fs.exists(root + "/README.mbt.md"))
  let module_file = @fs.read_file(root + "/moon.mod").text()
  assert_true(module_file.contains("vectie/lepusa"))
  assert_true(module_file.contains("\"preferred-target\": \"native\""))
  let main_file = @fs.read_file(root + "/main.mbt").text()
  assert_true(main_file.contains("@lepusa.new(root)"))
  assert_true(main_file.contains("RuntimeConfig::system_webview"))
}

///|
async test "bundle write materializes planned files" {
  let root = "/tmp/lepusa-bundle-write-\{@async.now().to_int()}"
  let result = render_cli_async(["bundle-write", "linux", root])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("files: 2"))
  let bundle_root = root + "/lepusa-example"
  let desktop_path = bundle_root + "/lepusa-example.desktop"
  let runtime_path = bundle_root + "/lepusa/runtime.json"
  assert_true(@fs.exists(desktop_path))
  assert_true(@fs.exists(runtime_path))
  assert_true(
    @fs.read_file(desktop_path).text().contains("Name=Lepusa Example"),
  )
  let runtime_manifest = @fs.read_file(runtime_path).text()
  assert_true(runtime_manifest.contains("\"target\":\"linux\""))
  assert_true(runtime_manifest.contains("\"initializationScripts\""))
  assert_true(runtime_manifest.contains("__lepusaInvoke"))
}

///|
async test "build and bundle aliases materialize planned files" {
  let build_root = "/tmp/lepusa-build-\{@async.now().to_int()}"
  let build = render_cli_async(["build", "macos", build_root])
  assert_eq(build.exit_code, 0)
  assert_true(build.output.contains("target: macos"))
  assert_true(
    @fs.exists(build_root + "/lepusa-example.app/Contents/Info.plist"),
  )
  let bundle_root = "/tmp/lepusa-bundle-alias-\{@async.now().to_int()}"
  let bundle = render_cli_async(["bundle", "windows", bundle_root])
  assert_eq(bundle.exit_code, 0)
  assert_true(bundle.output.contains("target: windows"))
  assert_true(@fs.exists(bundle_root + "/lepusa-example/app.manifest.xml"))
}

///|
test "bridge prints generated javascript" {
  let result = render_cli(["bridge"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("globalThis"))
  assert_true(result.output.contains("core.invoke"))
  assert_true(result.output.contains("__lepusaInvoke"))
}

///|
test "unknown commands fail with help" {
  let result = render_cli(["wat"])
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("unknown command: wat"))
}
