///|
test "help text names available commands" {
  let result = render_cli([])
  assert_eq(result.exit_code, 0)
  assert_true(
    result.output.contains("lepusa doctor [macos|windows|linux] [--json]"),
  )
  assert_true(result.output.contains("lepusa bridge"))
  assert_true(result.output.contains("lepusa dev"))
  assert_true(result.output.contains("lepusa dev [--json]"))
  assert_true(result.output.contains("lepusa bridge-task"))
  assert_true(result.output.contains("lepusa bridge-complete"))
  assert_true(result.output.contains("lepusa bridge-loop"))
  assert_true(result.output.contains("lepusa bridge-drain"))
  assert_true(result.output.contains("lepusa invoke"))
  assert_true(result.output.contains("lepusa asset"))
  assert_true(result.output.contains("lepusa lifecycle"))
  assert_true(result.output.contains("lepusa manifest"))
  assert_true(result.output.contains("lepusa native-plan"))
  assert_true(result.output.contains("lepusa launch-session"))
  assert_true(
    result.output.contains(
      "lepusa run [macos|windows|linux] [--launch] [--json]",
    ),
  )
  assert_true(
    result.output.contains(
      "lepusa verify [macos|windows|linux] [--strict] [--json]",
    ),
  )
  assert_true(result.output.contains("lepusa init"))
  assert_true(result.output.contains("lepusa build"))
  assert_true(result.output.contains("lepusa bundle"))
  assert_true(result.output.contains("lepusa plugin new"))
  assert_true(
    result.output.contains("lepusa bundle-plan [macos|windows|linux] [--json]"),
  )
  assert_true(result.output.contains("lepusa bundle-inspect"))
  assert_true(result.output.contains("lepusa bundle-release-plan"))
  assert_true(
    result.output.contains(
      "lepusa bundle-write [macos|windows|linux] [out-dir] [--json]",
    ),
  )
  assert_true(result.output.contains("--project <lepusa.json>"))
  assert_true(result.output.contains("--workspace <lepusa-root>"))
}

///|
async test "doctor renders framework boundary checks" {
  let result = render_cli_async(["doctor"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("[ok] public-api"))
  assert_true(result.output.contains("backend=headless"))
  assert_true(result.output.contains("[ok] manifest: webviews=1 routes=2"))
  assert_true(result.output.contains("[ok] handlers: registered=2 missing=0"))
  assert_true(result.output.contains("[ok] bundle: target=macos"))
  assert_true(result.output.contains("[ok] native-launch: target=macos"))
  assert_true(result.output.contains("can-launch=true"))
  assert_true(result.output.contains("[ok] signing: prerequisites=3"))
  assert_true(result.output.contains("Developer ID Application certificate"))
  assert_true(result.output.contains("platform: macos"))
  assert_true(result.output.contains("engine=WKWebView"))
  assert_true(result.output.contains("platform: windows"))
  assert_true(result.output.contains("platform: linux"))
  let json_result = render_cli_async(["doctor", "--json"])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"macos\""))
  assert_true(json_result.output.contains("\"publicApi\":true"))
  assert_true(json_result.output.contains("\"runtime\":{"))
  assert_true(json_result.output.contains("\"manifest\":{"))
  assert_true(json_result.output.contains("\"handlers\":{"))
  assert_true(json_result.output.contains("\"nativeLaunch\":{"))
  assert_true(json_result.output.contains("\"signing\":{"))
  assert_true(json_result.output.contains("\"platforms\":["))
  assert_true(json_result.output.contains("\"platform\":\"windows\""))
  assert_true(json_result.output.contains("\"preflight\":{"))
  assert_true(json_result.output.contains("\"problemKind\":"))
}

///|
async test "doctor supports target-specific signing diagnostics" {
  let result = render_cli_async(["doctor", "linux"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("[ok] bundle: target=linux"))
  assert_true(result.output.contains("[ok] native-launch: target=linux"))
  assert_true(result.output.contains("[ok] signing: prerequisites=2"))
  assert_false(result.output.contains("package-signing-key"))
  assert_true(result.output.contains("package signing key"))
  let windows = render_cli_async(["doctor", "windows"])
  assert_eq(windows.exit_code, 0)
  assert_true(windows.output.contains("[warn] native-launch: target=windows"))
  assert_true(windows.output.contains("can-launch=false"))
  assert_true(windows.output.contains("Windows WebView2"))
  let unknown = render_cli_async(["doctor", "ios"])
  assert_eq(unknown.exit_code, 1)
  assert_true(unknown.output.contains("unknown bundle target: ios"))
}

///|
async test "runtime plan prints command routes" {
  let result = render_cli_async(["plan"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("windows: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("routes: core.invoke,core.events"))
}

///|
async test "manifest prints native runner json" {
  let result = render_cli_async(["manifest"])
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
async test "native plan prints backend bootstrap json" {
  let result = render_cli_async(["native-plan", "macos"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"nativeBackend\":\"macos\""))
  assert_true(result.output.contains("\"webviewEngine\":\"WKWebView\""))
  assert_true(result.output.contains("\"webviewSpecs\""))
  assert_true(result.output.contains("\"startupOperations\""))
  assert_true(result.output.contains("\"lifecycleOperations\""))
  assert_true(result.output.contains("\"bridgeScheduler\""))
  assert_true(result.output.contains("\"mode\":\"sync-only\""))
  assert_true(result.output.contains("\"nativeHook\":\"__lepusaInvoke\""))
}

///|
async test "launch session prints source native handoff json" {
  let result = render_cli_async(["launch-session", "linux"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"target\":\"linux\""))
  assert_true(result.output.contains("\"platformName\":\"Linux\""))
  assert_true(result.output.contains("\"session\":{"))
  assert_true(result.output.contains("\"webviews\""))
  assert_true(result.output.contains("\"execution\""))
  assert_true(result.output.contains("\"bridgeScheduler\""))
  assert_true(result.output.contains("\"launchCapability\":{"))
  assert_true(result.output.contains("\"backendPreflight\":{"))
  assert_true(result.output.contains("\"dependencyName\":\"webkitgtk\""))
  assert_true(result.output.contains("\"targetCanLaunch\":true"))
  assert_true(result.output.contains("\"targetLaunchBlocker\":null"))
  assert_true(result.output.contains("\"requestedBridgeMode\":\"sync-only\""))
  assert_true(result.output.contains("\"effectiveBridgeMode\":\"sync-only\""))
  assert_true(result.output.contains("\"bridgeModeGranted\":true"))
  assert_true(result.output.contains("\"asyncBridgeExecutor\""))
  assert_true(result.output.contains("\"bridgeLoop\""))
  assert_true(result.output.contains("\"serviceSupervisor\""))
  assert_true(result.output.contains("\"mode\":\"sync-only\""))
  assert_true(result.output.contains("\"loadUrl\""))
  assert_true(result.output.contains("__lepusaInvoke"))
  let async_bridge = render_cli_async([
    "launch-session", "linux", "--async-bridge",
  ])
  assert_eq(async_bridge.exit_code, 0)
  assert_true(async_bridge.output.contains("\"mode\":\"sync-only\""))
  assert_true(async_bridge.output.contains("\"available\":false"))
  assert_true(
    async_bridge.output.contains("\"requestedBridgeMode\":\"async-capable\""),
  )
  assert_true(
    async_bridge.output.contains("\"effectiveBridgeMode\":\"sync-only\""),
  )
  assert_true(async_bridge.output.contains("\"bridgeModeGranted\":false"))
  assert_true(
    async_bridge.output.contains(
      "\"callback\":\"NativeRuntime::bridge_async_dispatch_callback\"",
    ),
  )
  assert_true(
    async_bridge.output.contains(
      "\"receiveMessage\":\"bridge_loop_adapter().receive_message\"",
    ),
  )
  assert_true(
    async_bridge.output.contains(
      "\"receiveWindowMessage\":\"bridge_loop_adapter().receive_window_message\"",
    ),
  )
  assert_true(
    async_bridge.output.contains(
      "\"drainWindow\":\"bridge_loop_adapter().drain_window\"",
    ),
  )
  assert_true(
    async_bridge.output.contains(
      "\"drainWindowScripts\":\"bridge_loop_adapter().callbacks(window).drain_window_scripts\"",
    ),
  )
  assert_true(
    async_bridge.output.contains(
      "\"deliveryType\":\"NativeBridgeLoopDelivery|BundledBridgeLoopDelivery\"",
    ),
  )
  let windows = render_cli_async(["launch-session", "windows"])
  assert_eq(windows.exit_code, 0)
  assert_true(windows.output.contains("\"target\":\"windows\""))
  assert_true(windows.output.contains("\"backendPreflight\":{"))
  assert_true(windows.output.contains("\"dependencyName\":\"webview2-loader\""))
  assert_true(windows.output.contains("\"problemKind\":"))
  assert_true(windows.output.contains("\"dependencyProblem\":"))
  assert_true(windows.output.contains("\"webviewCreationProblem\":"))
  assert_true(windows.output.contains("\"asyncBridgeDrainProblem\":"))
  assert_true(windows.output.contains("\"targetCanLaunch\":false"))
  assert_true(
    windows.output.contains("\"targetLaunchBlocker\":\"Windows WebView2"),
  )
}

///|
async test "run prints native runner smoke summary" {
  let result = render_cli_async(["run", "linux"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa run"))
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("backend: linux"))
  assert_true(result.output.contains("engine: WebKitGTK"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("target-can-launch: true"))
  assert_true(result.output.contains("bridge: lepusa://runtime/bridge.js"))
  assert_true(result.output.contains("startup-operations: 0"))
  assert_true(result.output.contains("lifecycle-steps: 0"))
  let json_result = render_cli_async(["run", "linux", "--json"])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"linux\""))
  assert_true(json_result.output.contains("\"backend\":\"linux\""))
  assert_true(json_result.output.contains("\"engine\":\"WebKitGTK\""))
  assert_true(json_result.output.contains("\"status\":{\"name\":\"prepared\""))
  assert_true(json_result.output.contains("\"webviews\":1"))
  assert_true(
    json_result.output.contains(
      "\"firstWindowUrl\":\"lepusa://rabbita/main/index.html\"",
    ),
  )
  assert_true(
    json_result.output.contains("\"bridgeUrl\":\"lepusa://runtime/bridge.js\""),
  )
  assert_true(json_result.output.contains("\"targetCanLaunch\":true"))
}

///|
async test "run launch rejects unwired native targets" {
  let result = render_cli_async(["run", "linux", "--launch"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa launch"))
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("backend: linux"))
  assert_true(result.output.contains("engine: WebKitGTK"))
  assert_true(result.output.contains("status: unsupported"))
  assert_true(result.output.contains("status-message: Linux WebKitGTK"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("target-can-launch: true"))
  assert_true(result.output.contains("startup-operations: 0"))
  let json_result = render_cli_async(["run", "linux", "--launch", "--json"])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"linux\""))
  assert_true(
    json_result.output.contains("\"status\":{\"name\":\"unsupported\""),
  )
  assert_true(json_result.output.contains("Linux WebKitGTK"))
  assert_true(json_result.output.contains("\"targetCanLaunch\":true"))
}

///|
async test "bundle plan supports target selection" {
  let result = render_cli_async(["bundle-plan", "windows"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: windows"))
  assert_true(result.output.contains("bundle: lepusa-example.cmd"))
  assert_true(
    result.output.contains(
      "runtime-executable: lepusa-example/lepusa-runtime.exe",
    ),
  )
  assert_true(result.output.contains("resources: 0"))
  assert_true(result.output.contains("runtime-dependencies: 2"))
  assert_true(result.output.contains("signing-prerequisites: 3"))
  assert_true(result.output.contains("files: 4"))
  let json_result = render_cli_async(["bundle-plan", "windows", "--json"])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"windows\""))
  assert_true(
    json_result.output.contains("\"identifier\":\"dev.vectie.lepusa.example\""),
  )
  assert_true(json_result.output.contains("\"bundle\":\"lepusa-example.cmd\""))
  assert_true(
    json_result.output.contains(
      "\"runtimeExecutable\":\"lepusa-example/lepusa-runtime.exe\"",
    ),
  )
  assert_true(json_result.output.contains("\"localServices\":0"))
  assert_true(json_result.output.contains("\"filesystemScopes\":0"))
  assert_true(json_result.output.contains("\"resources\":[]"))
  assert_true(json_result.output.contains("\"runtimeDependencies\":["))
  assert_true(json_result.output.contains("Microsoft Edge WebView2 Runtime"))
  assert_true(json_result.output.contains("WebView2Loader.dll"))
  assert_true(
    json_result.output.contains(
      "\"path\":\"lepusa-example/WebView2Loader.dll\"",
    ),
  )
  assert_true(
    json_result.output.contains(
      "\"sourcePath\":\"_build/native/debug/build/cmd/runtime/WebView2Loader.dll\"",
    ),
  )
  assert_true(json_result.output.contains("\"signingPrerequisites\":["))
  assert_true(json_result.output.contains("\"kind\":\"runtime-dependency\""))
  assert_true(json_result.output.contains("\"signingSteps\":[]"))
  assert_true(json_result.output.contains("\"files\":["))
  assert_true(
    json_result.output.contains(
      "\"path\":\"lepusa-example/lepusa-example.cmd\"",
    ),
  )
  assert_true(json_result.output.contains("\"executable\":false"))
}

///|
async test "asset command resolves sample runtime assets" {
  let result = render_cli_async(["asset", "lepusa://rabbita/main/index.html"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"ok\":true"))
  assert_true(result.output.contains("\"kind\":\"virtual\""))
  assert_true(result.output.contains("\"mimeType\":\"text/html\""))
  assert_true(result.output.contains("<main></main>"))
  let missing = render_cli_async(["asset", "lepusa://rabbita/main/missing.js"])
  assert_eq(missing.exit_code, 0)
  assert_true(missing.output.contains("\"ok\":false"))
  assert_true(
    missing.output.contains(
      "\"error\":\"virtual asset not found: main/missing.js\"",
    ),
  )
}

///|
async test "init writes standalone project skeleton" {
  let root = "/tmp/lepusa-init-\{@async.now().to_int()}"
  let result = render_cli_async(["init", root])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa init"))
  assert_true(result.output.contains("files: 5"))
  assert_true(@fs.exists(root + "/moon.mod"))
  assert_true(@fs.exists(root + "/lepusa.json"))
  assert_true(@fs.exists(root + "/src/moon.pkg"))
  assert_true(@fs.exists(root + "/src/main.mbt"))
  assert_true(@fs.exists(root + "/README.mbt.md"))
  let module_file = @fs.read_file(root + "/moon.mod").text()
  assert_true(module_file.contains("vectie/lepusa@0.1.0"))
  assert_true(module_file.contains("\"preferred-target\": \"native\""))
  let config_file = @fs.read_file(root + "/lepusa.json").text()
  assert_true(config_file.contains("\"productName\": \"Lepusa App\""))
  assert_true(config_file.contains("\"name\": \"log\""))
  assert_true(config_file.contains("\"name\": \"store\""))
  assert_true(config_file.contains("Count: 0"))
  assert_false(config_file.contains("core.invoke"))
  assert_false(config_file.contains("core.events"))
  assert_true(config_file.contains("\"log.write\""))
  assert_true(config_file.contains("\"store.set\""))
  assert_true(config_file.contains("\"startup\": { \"effect\": \"boot\" }"))
  assert_true(config_file.contains("\"event\": \"app-will-exit\""))
  let main_file = @fs.read_file(root + "/src/main.mbt").text()
  assert_true(main_file.contains("enum Msg"))
  assert_true(main_file.contains("@ui.UiProgram::new"))
  assert_true(main_file.contains("route=\"counter.dispatch\""))
  assert_true(main_file.contains("@desktop.DesktopProject::new"))
  assert_true(main_file.contains(".with_registry(program.registry())"))
  assert_true(main_file.contains(".with_plugin(program.plugin())"))
  assert_true(
    main_file.contains(".with_capability(program.capability_for_window())"),
  )
  assert_true(main_file.contains(".with_sync_plugins()"))
  assert_true(main_file.contains("@ui.main_"))
  assert_true(main_file.contains("dispatch(Increment)"))
  assert_true(main_file.contains("@ui.text_listener(\"ready\", \"#status\")"))
  assert_true(main_file.contains("Cmd::emit(@lepusa.Event::new(\"ready\""))
  assert_true(main_file.contains("project.runtime_host()"))
  assert_false(main_file.contains("@lepusa.new(program.cell())"))
}

///|
async test "init can write local workspace scaffold" {
  let root = "/tmp/lepusa-init-workspace-\{@async.now().to_int()}"
  let result = render_cli_async([
    "init", root, "--workspace", "/Users/kq/Workspace/lepusa",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("workspace: /Users/kq/Workspace/lepusa"))
  assert_true(result.output.contains("files: 6"))
  assert_true(@fs.exists(root + "/moon.work"))
  let workspace_file = @fs.read_file(root + "/moon.work").text()
  assert_true(workspace_file.contains("\".\""))
  assert_true(workspace_file.contains("\"/Users/kq/Workspace/lepusa\""))
}

///|
async test "init workspace option requires path" {
  let result = render_cli_async([
    "init", "/tmp/lepusa-init-missing-workspace", "--workspace",
  ])
  assert_eq(result.exit_code, 1)
  assert_true(
    result.output.contains("--workspace requires a Lepusa checkout path"),
  )
}

///|
async test "init workspace option rejects another flag as path" {
  let result = render_cli_async([
    "init", "/tmp/lepusa-init-bad-workspace", "--workspace", "--project",
  ])
  assert_eq(result.exit_code, 1)
  assert_true(
    result.output.contains("--workspace requires a Lepusa checkout path"),
  )
}

///|
async test "generated project config resolves runtime assets" {
  let root = "/tmp/lepusa-project-asset-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async([
    "asset",
    "lepusa://rabbita/main/index.html",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"ok\":true"))
  assert_true(result.output.contains("\"kind\":\"virtual\""))
  assert_true(result.output.contains("Count: 0"))
}

///|
async test "generated project config renders lifecycle steps" {
  let root = "/tmp/lepusa-project-lifecycle-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let project = root + "/lepusa.json"
  let startup = render_cli_async([
    "lifecycle", "app-started", "--project", project,
  ])
  assert_eq(startup.exit_code, 0)
  assert_true(startup.output.contains("\"kind\":\"app-started\""))
  assert_true(startup.output.contains("\"kind\":\"run-effect\""))
  assert_true(startup.output.contains("\"name\":\"boot\""))
  let shutdown = render_cli_async([
    "lifecycle", "app-will-exit", "--project", project,
  ])
  assert_eq(shutdown.exit_code, 0)
  assert_true(shutdown.output.contains("\"kind\":\"app-will-exit\""))
  assert_true(shutdown.output.contains("\"name\":\"shutdown\""))
  assert_true(shutdown.output.contains("\"session\""))
}

///|
async test "lifecycle command validates event arguments" {
  let missing = render_cli_async(["lifecycle"])
  assert_eq(missing.exit_code, 1)
  assert_true(missing.output.contains("lifecycle event is required"))
  let window = render_cli_async(["lifecycle", "window-close-requested"])
  assert_eq(window.exit_code, 1)
  assert_true(window.output.contains("lifecycle window is required"))
  let unknown = render_cli_async(["lifecycle", "wat"])
  assert_eq(unknown.exit_code, 1)
  assert_true(unknown.output.contains("unknown lifecycle event: wat"))
}

///|
async test "generated project config drives runtime plan" {
  let root = "/tmp/lepusa-project-plan-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async(["plan", "--project", root + "/lepusa.json"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("backend: system-webview"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("plugins: 2"))
  assert_true(result.output.contains("capabilities: 1"))
  assert_false(result.output.contains("core.invoke"))
  assert_true(result.output.contains("log.write"))
  assert_true(result.output.contains("store.clear"))
}

///|
async test "generated project config drives dev plan" {
  let root = "/tmp/lepusa-project-dev-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async(["dev", "--project", root + "/lepusa.json"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa dev plan"))
  assert_true(result.output.contains("backend: system-webview"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_false(result.output.contains("core.invoke"))
  assert_false(result.output.contains("core.events"))
  assert_true(result.output.contains("registered-routes:"))
  assert_true(result.output.contains("bridge-sync-routes: 6"))
  assert_true(result.output.contains("bridge-async-routes: 0"))
  assert_true(result.output.contains("log.write"))
  assert_true(result.output.contains("store.set"))
  assert_true(result.output.contains("local-services: 0"))
  assert_true(result.output.contains("startup-operations: 1"))
  assert_true(result.output.contains("lifecycle-steps: 1"))
  let json_result = render_cli_async([
    "dev",
    "--json",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"kind\":\"runtime-dev-plan\""))
  assert_true(json_result.output.contains("\"launchManifest\":{"))
  assert_true(json_result.output.contains("\"bridgeRoutes\":{"))
  assert_true(json_result.output.contains("\"sync\":[\"log.write\""))
  assert_true(json_result.output.contains("\"async\":[]"))
  assert_true(json_result.output.contains("\"lifecycleSteps\":[{"))
}

///|
async test "generated project config drives doctor backend diagnostics" {
  let root = "/tmp/lepusa-project-doctor-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async(["doctor", "--project", root + "/lepusa.json"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("backend=system-webview"))
  assert_true(result.output.contains("[ok] handlers: registered=6 missing=0"))
  assert_true(result.output.contains("[ok] bundle: target=macos"))
  assert_true(result.output.contains("[ok] native-launch: target=macos"))
  assert_true(result.output.contains("[ok] signing: prerequisites=3"))
  assert_true(result.output.contains("Developer ID Application certificate"))
  assert_true(result.output.contains("platform: macos"))
  assert_true(result.output.contains("platform-detail: macos"))
  assert_true(result.output.contains("platform: windows"))
  assert_true(result.output.contains("platform-detail: windows"))
  assert_true(result.output.contains("webview2-loader="))
  assert_true(result.output.contains("creation-loop=false"))
  assert_true(result.output.contains("sync-bridge="))
  assert_true(result.output.contains("platform: linux"))
  assert_true(result.output.contains("platform-detail: linux"))
  let json_result = render_cli_async([
    "doctor",
    "linux",
    "--json",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"linux\""))
  assert_true(json_result.output.contains("\"backend\":\"system-webview\""))
  assert_true(json_result.output.contains("\"registered\":6"))
  assert_true(json_result.output.contains("\"missing\":0"))
  assert_true(json_result.output.contains("\"canLaunch\":true"))
  assert_true(json_result.output.contains("\"prerequisites\":["))
}

///|
async test "generated project doctor supports target selection" {
  let root = "/tmp/lepusa-project-doctor-target-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async([
    "doctor",
    "linux",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("[ok] bundle: target=linux"))
  assert_true(result.output.contains("[ok] native-launch: target=linux"))
  assert_true(result.output.contains("[ok] signing: prerequisites=2"))
  assert_true(result.output.contains("package signing key"))
}

///|
async test "generated project config drives manifest and bundle write" {
  let root = "/tmp/lepusa-project-bundle-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let project = root + "/lepusa.json"
  let manifest = render_cli_async(["manifest", "--project", project])
  assert_eq(manifest.exit_code, 0)
  assert_true(manifest.output.contains("\"backend\":\"system-webview\""))
  assert_true(manifest.output.contains("\"commandRoutes\""))
  assert_true(manifest.output.contains("\"registeredRoutes\""))
  assert_true(manifest.output.contains("\"capabilities\""))
  assert_true(manifest.output.contains("\"custom:log.write\""))
  assert_true(manifest.output.contains("\"log.write\""))
  assert_true(manifest.output.contains("\"store.keys\""))
  assert_true(manifest.output.contains("Count: 0"))
  assert_true(manifest.output.contains("\"startupActions\""))
  assert_true(manifest.output.contains("\"name\":\"boot\""))
  assert_true(manifest.output.contains("\"kind\":\"app-will-exit\""))
  assert_true(manifest.output.contains("\"name\":\"shutdown\""))
  let out = "/tmp/lepusa-project-bundle-out-\{@async.now().to_int()}"
  let build = render_cli_async(["build", "linux", out, "--project", project])
  assert_eq(build.exit_code, 0)
  assert_true(build.output.contains("target: linux"))
  assert_true(build.output.contains("local-services: 0"))
  assert_true(build.output.contains("resources: 0"))
  assert_true(build.output.contains("signing-prerequisites: 2"))
  let bundle_root = out + "/lepusa-app"
  assert_true(@fs.exists(bundle_root + "/lepusa/runtime.json"))
  assert_true(@fs.exists(bundle_root + "/lepusa-app.desktop"))
  let runtime_json = @fs.read_file(bundle_root + "/lepusa/runtime.json").text()
  assert_true(runtime_json.contains("\"registeredRoutes\""))
  assert_true(runtime_json.contains("\"capabilities\""))
  assert_true(runtime_json.contains("\"custom:log.write\""))
  assert_true(runtime_json.contains("\"log.write\""))
  assert_true(runtime_json.contains("\"store.set\""))
  assert_true(runtime_json.contains("\"signingPrerequisites\""))
}

///|
async test "generated project config drives native runner bootstrap" {
  let root = "/tmp/lepusa-project-native-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async([
    "native-plan",
    "linux",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"nativeBackend\":\"linux\""))
  assert_true(result.output.contains("\"webviewEngine\":\"WebKitGTK\""))
  assert_true(result.output.contains("\"registeredRoutes\""))
  assert_true(result.output.contains("\"log.write\""))
  assert_true(result.output.contains("\"store.set\""))
  assert_true(result.output.contains("\"webviewSpecs\""))
  assert_true(result.output.contains("\"startupOperations\""))
  assert_true(result.output.contains("\"lifecycleOperations\""))
}

///|
async test "generated project config drives native runner smoke command" {
  let root = "/tmp/lepusa-project-run-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async([
    "run",
    "linux",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("backend: linux"))
  assert_true(result.output.contains("engine: WebKitGTK"))
  assert_true(result.output.contains("startup-operations: 1"))
  assert_true(result.output.contains("lifecycle-steps: 1"))
  let json_result = render_cli_async([
    "run",
    "linux",
    "--json",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"linux\""))
  assert_true(json_result.output.contains("\"backend\":\"linux\""))
  assert_true(json_result.output.contains("\"startupOperations\":1"))
  assert_true(json_result.output.contains("\"lifecycleSteps\":1"))
  assert_true(json_result.output.contains("\"serviceSupervisor\":false"))
}

///|
async test "generated project config prints actionable dev commands" {
  let root = "/tmp/lepusa-project-dev-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let project = root + "/lepusa.json"
  let result = render_cli_async(["dev", "--project", project])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa dev plan"))
  assert_true(result.output.contains("commands:"))
  assert_true(
    result.output.contains("inspect: lepusa plan --project \{project}"),
  )
  assert_true(
    result.output.contains("manifest: lepusa manifest --project \{project}"),
  )
  assert_true(
    result.output.contains(
      "verify:linux: lepusa verify linux --project \{project}",
    ),
  )
  assert_true(
    result.output.contains(
      "run:macos: lepusa run macos --launch --project \{project}",
    ),
  )
  assert_true(
    result.output.contains(
      "bundle:windows: lepusa bundle-write windows _build/lepusa-windows --project \{project}",
    ),
  )
  let json = render_cli_async(["dev", "--json", "--project", project])
  assert_eq(json.exit_code, 0)
  assert_true(json.output.contains("\"commands\":[{"))
  assert_true(json.output.contains("\"targetRequired\":true"))
}

///|
async test "generated project config verifies end to end contracts" {
  let root = "/tmp/lepusa-project-verify-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async([
    "verify",
    "linux",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa verify"))
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("[ok] plan: windows=1"))
  assert_true(result.output.contains("[ok] dev: webviews=1"))
  assert_true(result.output.contains("[ok] manifest: webviews=1"))
  assert_true(
    result.output.contains("[ok] asset: bridge lepusa://runtime/bridge.js"),
  )
  assert_true(
    result.output.contains("[ok] content: windows=1 checked=1 skipped=0"),
  )
  assert_true(result.output.contains("[ok] handlers: registered=6 missing=0"))
  assert_true(result.output.contains("[ok] native-session: webviews=1"))
  assert_true(result.output.contains("target-can-launch=true"))
  assert_true(result.output.contains("[ok] bundle:"))
  let windows = render_cli_async([
    "verify",
    "windows",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(windows.exit_code, 0)
  assert_true(windows.output.contains("target: windows"))
  assert_true(windows.output.contains("scheduler-can-launch=true"))
  assert_true(windows.output.contains("target-can-launch=false"))
  assert_true(windows.output.contains("[warn] native-launch: Windows WebView2"))
  let strict = render_cli_async([
    "verify",
    "--strict",
    "linux",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(strict.exit_code, 0)
  assert_true(strict.output.contains("mode: strict"))
  assert_true(strict.output.contains("[ok] strict: native launch gate passed"))
  let strict_windows = render_cli_async([
    "verify",
    "windows",
    "--strict",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(strict_windows.exit_code, 1)
  assert_true(strict_windows.output.contains("[fail] strict: Windows WebView2"))
  let json_result = render_cli_async([
    "verify",
    "linux",
    "--json",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"linux\""))
  assert_true(json_result.output.contains("\"strict\":false"))
  assert_true(json_result.output.contains("\"ok\":true"))
  assert_true(json_result.output.contains("\"lines\":["))
  assert_true(json_result.output.contains("\"[ok] plan: windows=1"))
  assert_true(json_result.output.contains("[ok] native-session: webviews=1"))
  assert_true(json_result.output.contains("[ok] bundle: files="))
  let strict_windows_json = render_cli_async([
    "verify",
    "windows",
    "--strict",
    "--json",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(strict_windows_json.exit_code, 1)
  assert_true(strict_windows_json.output.contains("\"target\":\"windows\""))
  assert_true(strict_windows_json.output.contains("\"strict\":true"))
  assert_true(strict_windows_json.output.contains("\"ok\":false"))
  assert_true(
    strict_windows_json.output.contains("[fail] strict: Windows WebView2"),
  )
}

///|
async test "verify rejects blank initial webview content" {
  let root = "/tmp/lepusa-blank-content-\{@async.now().to_int()}"
  @fs.mkdir(root, recursive=true, permission=0o755)
  @fs.write_file(
    root + "/lepusa.json",
    (
      #|{
      #|  "identifier": "dev.local.blank",
      #|  "productName": "Blank App",
      #|  "version": "0.1.0",
      #|  "window": {
      #|    "label": "main",
      #|    "title": "Blank App",
      #|    "source": { "html": "   " }
      #|  }
      #|}
    ),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let result = render_cli_async([
    "verify",
    "linux",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 1)
  assert_true(
    result.output.contains(
      "[fail] content: window main has blank virtual asset",
    ),
  )
}

///|
async test "checked examples cover rabbita static and gateway modes" {
  let rabbita = render_cli_async([
    "dev", "--project", "examples/rabbita/lepusa.json",
  ])
  assert_eq(rabbita.exit_code, 0)
  assert_true(
    rabbita.output.contains(
      "first-window-url: lepusa://rabbita/main/index.html",
    ),
  )
  assert_true(rabbita.output.contains("counter.increment"))
  let static_asset = render_cli_async([
    "asset", "lepusa://packaged/main/app.css", "--project", "examples/static/lepusa.json",
  ])
  assert_eq(static_asset.exit_code, 0)
  assert_true(static_asset.output.contains("\"kind\":\"packaged-file\""))
  assert_true(
    static_asset.output.contains("\"path\":\"examples/static/dist/app.css\""),
  )
  let gateway = render_cli_async([
    "dev", "--project", "examples/gateway/lepusa.json",
  ])
  assert_eq(gateway.exit_code, 0)
  assert_true(
    gateway.output.contains("first-window-url: http://127.0.0.1:4317/"),
  )
  assert_true(gateway.output.contains("local-services: 1"))
  assert_true(gateway.output.contains("service-supervisor: true"))
  assert_true(gateway.output.contains("service-start-order: gateway"))
  assert_true(gateway.output.contains("startup-operations: 2"))
  let gateway_run = render_cli_async([
    "run", "linux", "--project", "examples/gateway/lepusa.json",
  ])
  assert_eq(gateway_run.exit_code, 0)
  assert_true(
    gateway_run.output.contains("first-window-url: http://127.0.0.1:4317/"),
  )
  assert_true(gateway_run.output.contains("local-services: 1"))
  assert_true(gateway_run.output.contains("service-supervisor: true"))
  assert_true(gateway_run.output.contains("service-start-order: gateway"))
  assert_true(gateway_run.output.contains("startup-operations: 2"))
  let static_verify = render_cli_async([
    "verify", "linux", "--project", "examples/static/lepusa.json",
  ])
  assert_eq(static_verify.exit_code, 0)
  assert_true(static_verify.output.contains("Lepusa verify"))
  assert_true(static_verify.output.contains("[ok] bundle:"))
  assert_true(
    static_verify.output.contains("[ok] content: windows=1 checked=1 skipped=0"),
  )
  assert_true(
    static_verify.output.contains("[ok] handlers: registered=3 missing=0"),
  )
  assert_true(static_verify.output.contains("resources=1"))
  let static_strict = render_cli_async([
    "verify", "linux", "--strict", "--project", "examples/static/lepusa.json",
  ])
  assert_eq(static_strict.exit_code, 0)
  assert_true(static_strict.output.contains("mode: strict"))
  assert_true(
    static_strict.output.contains("[ok] handlers: registered=3 missing=0"),
  )
  assert_true(
    static_strict.output.contains("[ok] strict: native launch gate passed"),
  )
  let gateway_strict = render_cli_async([
    "verify", "linux", "--strict", "--project", "examples/gateway/lepusa.json",
  ])
  assert_eq(gateway_strict.exit_code, 0)
  assert_true(gateway_strict.output.contains("mode: strict"))
  assert_true(
    gateway_strict.output.contains(
      "[ok] content: windows=1 checked=0 skipped=1",
    ),
  )
  assert_true(
    gateway_strict.output.contains("[ok] handlers: registered=9 missing=0"),
  )
  assert_true(
    gateway_strict.output.contains("[ok] strict: native launch gate passed"),
  )
}

///|
async test "foundation examples write bundles with runtime contracts" {
  let stamp = @async.now().to_int()
  let rabbita_out = "/tmp/lepusa-example-rabbita-bundle-\{stamp}"
  let rabbita = render_cli_async([
    "bundle-write", "linux", rabbita_out, "--project", "examples/rabbita/lepusa.json",
  ])
  assert_eq(rabbita.exit_code, 0)
  assert_true(rabbita.output.contains("resources: 0"))
  assert_true(rabbita.output.contains("resources-written: 0"))
  let rabbita_json = @fs.read_file(
    rabbita_out + "/lepusa-rabbita-example/lepusa/runtime.json",
  ).text()
  assert_true(rabbita_json.contains("\"target\":\"linux\""))
  assert_true(rabbita_json.contains("\"root\":\"memory:main\""))
  assert_true(rabbita_json.contains("Lepusa Rabbita Example"))
  assert_true(rabbita_json.contains("\"counter.increment\""))
  assert_true(rabbita_json.contains("\"log.write\""))
  let static_out = "/tmp/lepusa-example-static-bundle-\{stamp}"
  let static_bundle = render_cli_async([
    "bundle-write", "linux", static_out, "--project", "examples/static/lepusa.json",
  ])
  assert_eq(static_bundle.exit_code, 0)
  assert_true(static_bundle.output.contains("resources: 1"))
  assert_true(static_bundle.output.contains("resources-written: 1"))
  let static_root = static_out + "/lepusa-static-example"
  assert_true(@fs.exists(static_root + "/lepusa/assets/main/index.html"))
  assert_true(@fs.exists(static_root + "/lepusa/assets/main/app.css"))
  let runtime_json = @fs.read_file(static_root + "/lepusa/runtime.json").text()
  assert_true(runtime_json.contains("\"package:lepusa/assets/main\""))
  assert_false(
    runtime_json.contains("\"root\":\"package:examples/static/dist\""),
  )
  let gateway_out = "/tmp/lepusa-example-gateway-bundle-\{stamp}"
  let gateway = render_cli_async([
    "bundle-write", "linux", gateway_out, "--project", "examples/gateway/lepusa.json",
  ])
  assert_eq(gateway.exit_code, 0)
  assert_true(gateway.output.contains("local-services: 1"))
  assert_true(gateway.output.contains("resources: 0"))
  assert_true(gateway.output.contains("resources-written: 0"))
  let gateway_json = @fs.read_file(
    gateway_out + "/lepusa-gateway-example/lepusa/runtime.json",
  ).text()
  assert_true(gateway_json.contains("\"url\":\"http://127.0.0.1:4317/\""))
  assert_true(
    gateway_json.contains("\"readinessUrl\":\"http://127.0.0.1:4317/health\""),
  )
  assert_true(
    gateway_json.contains("\"command\":[\"moon\",\"run\",\"cmd/server\"]"),
  )
  assert_true(gateway_json.contains("\"localhost.waitUntilReady\""))
  assert_true(gateway_json.contains("\"serviceDiscovery.resolve\""))
}

///|
async test "generated project config invokes official plugin commands" {
  let root = "/tmp/lepusa-project-invoke-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let project = root + "/lepusa.json"
  let log = render_cli_async([
    "invoke", "main", "log.write", "{\"message\":\"hello\"}", "--project", project,
  ])
  assert_eq(log.exit_code, 0)
  assert_true(log.output.contains("\"id\":\"cli\""))
  assert_true(log.output.contains("\\\"message\\\":\\\"hello\\\""))
  let store = render_cli_async([
    "invoke", "main", "store.set", "{\"key\":\"theme\",\"value\":\"dark\"}", "--project",
    project,
  ])
  assert_eq(store.exit_code, 0)
  assert_true(store.output.contains("\\\"key\\\":\\\"theme\\\""))
  assert_true(store.output.contains("\\\"value\\\":\\\"dark\\\""))
}

///|
async test "bridge task command reports source scheduling mode" {
  let sync = render_cli_async(["bridge-task", "main", "core.invoke", "true"])
  assert_eq(sync.exit_code, 0)
  assert_true(sync.output.contains("\"windowLabel\":\"main\""))
  assert_true(
    sync.output.contains("\"responseHook\":\"__lepusaInvokeResponse\""),
  )
  assert_true(sync.output.contains("\"route\":\"core.invoke\""))
  assert_true(sync.output.contains("\"mode\":\"sync\""))
  assert_true(sync.output.contains("\"requiresAsyncDispatch\":false"))
  assert_true(sync.output.contains("\"message\":\"{\\\"id\\\":\\\"cli\\\","))
  let sync_handoff = render_cli_async([
    "bridge-handoff", "main", "core.invoke", "true",
  ])
  assert_eq(sync_handoff.exit_code, 0)
  assert_true(sync_handoff.output.contains("\"kind\":\"immediate\""))
  assert_true(sync_handoff.output.contains("\"immediateDispatch\":{"))
  let sync_loop = render_cli_async([
    "bridge-loop", "main", "core.invoke", "true",
  ])
  assert_eq(sync_loop.exit_code, 0)
  assert_true(sync_loop.output.contains("\"result\":{"))
  assert_true(sync_loop.output.contains("\"evaluationPlan\":{"))
  assert_true(sync_loop.output.contains("\"immediateScript\":\"globalThis"))
  assert_true(sync_loop.output.contains("\"completions\":[]"))
  assert_true(sync_loop.output.contains("\"operations\":[{"))
  assert_true(sync_loop.output.contains("\"kind\":\"evaluate-script\""))
  assert_true(
    sync_loop.output.contains(
      "\"evaluationScripts\":[\"globalThis[\\\"__lepusaInvokeResponse\\\"]",
    ),
  )
  let sync_drain = render_cli_async([
    "bridge-drain", "main", "core.invoke", "true",
  ])
  assert_eq(sync_drain.exit_code, 0)
  assert_true(sync_drain.output.contains("\"handoffScript\":\"globalThis"))
  assert_true(sync_drain.output.contains("\"pendingAfterHandoff\":0"))
  assert_true(sync_drain.output.contains("\"pendingAfterDrain\":0"))
  assert_true(sync_drain.output.contains("\"operations\":[]"))
  let sync_complete = render_cli_async([
    "bridge-complete", "main", "core.invoke", "true",
  ])
  assert_eq(sync_complete.exit_code, 1)
  assert_true(
    sync_complete.output.contains("native bridge handoff is immediate"),
  )
  let root = "/tmp/lepusa-project-bridge-task-\{@async.now().to_int()}"
  @fs.mkdir(root, recursive=true, permission=0o755)
  @fs.write_file(
    root + "/lepusa.json",
    (
      #|{
      #|  "identifier": "dev.local.bridgeTask",
      #|  "productName": "Bridge Task",
      #|  "version": "0.1.0",
      #|  "window": { "label": "main", "title": "Bridge Task" },
      #|  "plugins": [
      #|    { "name": "fs" }
      #|  ],
      #|  "capabilities": [
      #|    {
      #|      "name": "main-files",
      #|      "windows": ["main"],
      #|      "permissions": ["filesystem.read", "filesystem.write"]
      #|    }
      #|  ],
      #|  "filesystemScopes": [
      #|    { "name": "data", "root": "data", "writable": true }
      #|  ]
      #|}
    ),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let async_task = render_cli_async([
    "bridge-task",
    "main",
    "fs.readText",
    "{\"scope\":\"data\",\"path\":\"note.txt\"}",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(async_task.exit_code, 0)
  assert_true(async_task.output.contains("\"route\":\"fs.readText\""))
  assert_true(async_task.output.contains("\"mode\":\"async\""))
  assert_true(async_task.output.contains("\"requiresAsyncDispatch\":true"))
  let async_handoff = render_cli_async([
    "bridge-handoff",
    "main",
    "fs.readText",
    "{\"scope\":\"data\",\"path\":\"note.txt\"}",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(async_handoff.exit_code, 0)
  assert_true(async_handoff.output.contains("\"kind\":\"deferred\""))
  assert_true(async_handoff.output.contains("\"immediateDispatch\":null"))
  let async_loop = render_cli_async([
    "bridge-loop",
    "main",
    "fs.readText",
    "{\"scope\":\"data\",\"path\":\"note.txt\"}",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(async_loop.exit_code, 0)
  assert_true(async_loop.output.contains("\"result\":{"))
  assert_true(async_loop.output.contains("\"evaluationPlan\":{"))
  assert_true(async_loop.output.contains("\"immediateScript\":\"\""))
  assert_true(async_loop.output.contains("\"completions\":[{"))
  assert_true(async_loop.output.contains("\"route\":\"fs.readText\""))
  assert_true(async_loop.output.contains("\"operations\":[{"))
  assert_true(async_loop.output.contains("\"kind\":\"evaluate-script\""))
  assert_true(async_loop.output.contains("\"windowLabel\":\"main\""))
  assert_true(
    async_loop.output.contains(
      "\"evaluationScripts\":[\"globalThis[\\\"__lepusaInvokeResponse\\\"]",
    ),
  )
  let async_drain = render_cli_async([
    "bridge-drain",
    "main",
    "fs.readText",
    "{\"scope\":\"data\",\"path\":\"note.txt\"}",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(async_drain.exit_code, 0)
  assert_true(async_drain.output.contains("\"handoffScript\":\"\""))
  assert_true(async_drain.output.contains("\"pendingAfterHandoff\":1"))
  assert_true(async_drain.output.contains("\"pendingAfterDrain\":0"))
  assert_true(async_drain.output.contains("\"delivery\":{"))
  assert_true(async_drain.output.contains("\"route\":\"fs.readText\""))
  assert_true(async_drain.output.contains("\"kind\":\"evaluate-script\""))
  let async_complete = render_cli_async([
    "bridge-complete",
    "main",
    "fs.readText",
    "{\"scope\":\"data\",\"path\":\"note.txt\"}",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(async_complete.exit_code, 0)
  assert_true(async_complete.output.contains("\"task\":{"))
  assert_true(async_complete.output.contains("\"dispatch\":{"))
  assert_true(async_complete.output.contains("\"route\":\"fs.readText\""))
  assert_true(
    async_complete.output.contains(
      "\"evaluationScript\":\"globalThis[\\\"__lepusaInvokeResponse\\\"]",
    ),
  )
  let invalid = render_cli_async(["bridge-task", "main", "log"])
  assert_eq(invalid.exit_code, 1)
  assert_true(
    invalid.output.contains("bridge-task route must be <plugin.command>"),
  )
  let invalid_loop = render_cli_async(["bridge-loop", "main", "log"])
  assert_eq(invalid_loop.exit_code, 1)
  assert_true(
    invalid_loop.output.contains("bridge-loop route must be <plugin.command>"),
  )
  let invalid_drain = render_cli_async(["bridge-drain", "main", "log"])
  assert_eq(invalid_drain.exit_code, 1)
  assert_true(
    invalid_drain.output.contains("bridge-drain route must be <plugin.command>"),
  )
}

///|
async test "bridge dispatch command renders source callback script" {
  let app_root = "/tmp/lepusa-project-bridge-dispatch-log-\{@async.now().to_int()}"
  let init = render_cli_async(["init", app_root])
  assert_eq(init.exit_code, 0)
  let log = render_cli_async([
    "bridge-dispatch",
    "main",
    "log.write",
    "{\"message\":\"hello\"}",
    "--project",
    app_root + "/lepusa.json",
  ])
  assert_eq(log.exit_code, 0)
  assert_true(log.output.contains("\"windowLabel\":\"main\""))
  assert_true(
    log.output.contains("\"responseHook\":\"__lepusaInvokeResponse\""),
  )
  assert_true(log.output.contains("\"responseJson\":\"{\\\"id\\\":\\\"cli\\\""))
  assert_true(log.output.contains("hello"))
  assert_true(
    log.output.contains(
      "\"evaluationScript\":\"globalThis[\\\"__lepusaInvokeResponse\\\"]",
    ),
  )
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-project-bridge-dispatch-\{stamp}"
  @fs.mkdir(root + "/data", recursive=true, permission=0o755)
  @fs.write_file(
    root + "/data/note.txt",
    "hello async bridge",
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  @fs.write_file(
    root + "/lepusa.json",
    (
      #|{
      #|  "identifier": "dev.local.bridgeDispatch",
      #|  "productName": "Bridge Dispatch",
      #|  "version": "0.1.0",
      #|  "window": { "label": "main", "title": "Bridge Dispatch" },
      #|  "plugins": [
      #|    { "name": "fs" }
      #|  ],
      #|  "capabilities": [
      #|    {
      #|      "name": "main-files",
      #|      "windows": ["main"],
      #|      "permissions": ["filesystem.read"]
      #|    }
      #|  ],
      #|  "filesystemScopes": [
      #|    { "name": "data", "root": "data", "writable": false }
      #|  ]
      #|}
    ),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let read = render_cli_async([
    "bridge-dispatch",
    "main",
    "fs.readText",
    "{\"scope\":\"data\",\"path\":\"note.txt\"}",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(read.exit_code, 0)
  assert_true(read.output.contains("hello async bridge"))
  let invalid = render_cli_async(["bridge-dispatch", "main", "log"])
  assert_eq(invalid.exit_code, 1)
  assert_true(
    invalid.output.contains("bridge-dispatch route must be <plugin.command>"),
  )
}

///|
async test "invoke enforces project capabilities" {
  let root = "/tmp/lepusa-project-invoke-denied-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async([
    "invoke",
    "other",
    "log.write",
    "{\"message\":\"hello\"}",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(
    result.output.contains("\"error\":\"permission denied: log.write\""),
  )
}

///|
test "project config parses startup and lifecycle commands" {
  let config =
    #|{
    #|  "identifier": "dev.local.actions",
    #|  "productName": "Actions",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Actions" },
    #|  "startup": [
    #|    { "emit": { "name": "ready", "target": { "window": "main" } } },
    #|    {
    #|      "navigate": {
    #|        "window": "main",
    #|        "source": { "html": "<main>ready</main>" }
    #|      }
    #|    }
    #|  ],
    #|  "lifecycle": [
    #|    {
    #|      "event": "window-close-requested",
    #|      "window": "main",
    #|      "command": { "effect": "persist" }
    #|    }
    #|  ]
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          match plan.startup_actions() {
            Ok(actions) => {
              assert_eq(actions.length(), 2)
              assert_true(actions[0] is RuntimeEmit(WindowTarget("main"), _))
              assert_true(actions[1] is RuntimeNavigate("main", _))
            }
            Err(_) => abort("unexpected invalid startup actions")
          }
          match plan.lifecycle_actions(WindowCloseRequested("main")) {
            Ok(actions) => {
              assert_eq(actions.length(), 1)
              assert_true(actions[0] is RuntimeEffect("persist"))
            }
            Err(_) => abort("unexpected invalid lifecycle actions")
          }
        }
        Err(_) => abort("unexpected invalid runtime plan")
      }
    Err(_) => abort("unexpected invalid project config")
  }
}

///|
test "project config parses localhost source" {
  let config =
    #|{
    #|  "identifier": "dev.local.gateway",
    #|  "productName": "Gateway",
    #|  "version": "0.1.0",
    #|  "window": {
    #|    "label": "main",
    #|    "title": "Gateway",
    #|    "source": {
    #|      "localhost": {
    #|        "port": 4317,
    #|        "path": "/app",
    #|        "readinessPath": "/health",
    #|        "command": ["moon", "run", "cmd/server"]
    #|      }
    #|    }
    #|  }
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          assert_eq(plan.windows()[0].url(), "http://127.0.0.1:4317/app")
          match plan.launch_manifest() {
            Ok(manifest) => {
              assert_eq(manifest.local_services().length(), 1)
              assert_true(manifest.to_json().contains("\"localServices\""))
              assert_true(manifest.to_json().contains("\"readinessUrl\""))
            }
            Err(_) => abort("unexpected invalid launch manifest")
          }
        }
        Err(_) => abort("unexpected invalid runtime plan")
      }
    Err(_) => abort("unexpected invalid project config")
  }
}

///|
test "project config parses packaged asset source" {
  let config =
    #|{
    #|  "identifier": "dev.local.packaged",
    #|  "productName": "Packaged",
    #|  "version": "0.1.0",
    #|  "window": {
    #|    "label": "main",
    #|    "title": "Packaged",
    #|    "source": { "packaged": "dist" }
    #|  }
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          assert_eq(
            plan.windows()[0].url(),
            "lepusa://packaged/main/index.html",
          )
          match plan.launch_manifest() {
            Ok(manifest) => {
              assert_eq(manifest.protocol_mappings()[0].root(), "package:dist")
              match manifest.resolve_asset("lepusa://packaged/main/app.css") {
                Ok(asset) =>
                  assert_true(
                    asset.body() is LaunchPackagedFile("dist/app.css"),
                  )
                Err(_) => abort("unexpected packaged launch asset")
              }
            }
            Err(_) => abort("unexpected invalid launch manifest")
          }
        }
        Err(_) => abort("unexpected invalid runtime plan")
      }
    Err(_) => abort("unexpected invalid project config")
  }
}

///|
test "project config parses command and capability permissions" {
  let config =
    #|{
    #|  "identifier": "dev.local.permissions",
    #|  "productName": "Permissions",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Permissions" },
    #|  "plugins": [
    #|    {
    #|      "name": "fs",
    #|      "commands": [
    #|        { "name": "read", "mode": "sync", "permission": "filesystem.read" }
    #|      ]
    #|    }
    #|  ],
    #|  "capabilities": [
    #|    {
    #|      "name": "main-files",
    #|      "windows": ["main"],
    #|      "permissions": ["filesystem.read"]
    #|    }
    #|  ]
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          let routes = plan.window_command_routes("main")
          assert_eq(routes.length(), 1)
          assert_eq(routes[0], "fs.read")
          assert_true(
            plan.command_permission("fs.read") is Some(FileSystemRead),
          )
        }
        Err(_) => abort("unexpected invalid runtime plan")
      }
    Err(_) => abort("unexpected invalid project config")
  }
}

///|
async test "project config parses filesystem scopes" {
  let config =
    #|{
    #|  "identifier": "dev.local.scopes",
    #|  "productName": "Scopes",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Scopes" },
    #|  "plugins": [
    #|    { "name": "fs" }
    #|  ],
    #|  "capabilities": [
    #|    {
    #|      "name": "main-files",
    #|      "windows": ["main"],
    #|      "permissions": ["filesystem.read", "filesystem.write"]
    #|    }
    #|  ],
    #|  "filesystemScopes": [
    #|    { "name": "assets", "root": "assets" },
    #|    { "name": "data", "root": ".lepusa/data", "writable": true }
    #|  ]
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          assert_eq(plan.file_system_scopes().length(), 2)
          assert_eq(plan.file_system_scopes()[0].name(), "assets")
          assert_true(plan.file_system_scopes()[1].writable())
          assert_true(
            plan.window_command_routes("main").contains("fs.readText"),
          )
          assert_true(
            plan.window_command_routes("main").contains("fs.writeText"),
          )
          let exists = project
            .registry()
            .dispatch_async(
              @lepusa.InvokeRequest::new(
                id="exists",
                window_label="main",
                plugin="fs",
                command="exists",
                payload="{\"scope\":\"assets\",\"path\":\"missing.txt\"}",
              ),
              capabilities=plan.capabilities(),
            )
          assert_true(
            exists.payload().unwrap_or("").contains("\"exists\":false"),
          )
          match plan.launch_manifest() {
            Ok(manifest) => {
              assert_eq(manifest.file_system_scopes().length(), 2)
              assert_eq(manifest.capabilities()[0].name(), "main-files")
              assert_true(
                manifest.capabilities()[0]
                .permissions()
                .contains("filesystem.read"),
              )
              assert_true(manifest.to_json().contains("\"filesystemScopes\""))
              assert_true(manifest.to_json().contains("\"capabilities\""))
              assert_true(manifest.to_json().contains("\"root\":\"assets\""))
            }
            Err(_) => abort("unexpected invalid launch manifest")
          }
        }
        Err(_) => abort("unexpected invalid runtime plan")
      }
    Err(_) => abort("unexpected invalid project config")
  }
}

///|
test "project config parses bundle icon resources" {
  let config =
    #|{
    #|  "identifier": "dev.local.icon",
    #|  "productName": "Icon App",
    #|  "version": "0.1.0",
    #|  "icon": "assets/icon.png",
    #|  "signing": {
    #|    "identity": "Developer ID Application: Vectie",
    #|    "teamId": "ABCDE12345",
    #|    "entitlements": "macos/entitlements.plist",
    #|    "notarizationProfile": "lepusa-notary",
    #|    "timestampUrl": "https://timestamp.local"
    #|  },
    #|  "window": { "label": "main", "title": "Icon App" }
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().bundle_plan(project.root(), target=Linux) {
        Ok(plan) => {
          assert_eq(plan.resources().length(), 1)
          assert_eq(plan.resources()[0].source_path(), "assets/icon.png")
          assert_eq(plan.resources()[0].path(), "icon-app/icon-app.png")
          assert_true(plan.signing().configured())
          assert_eq(
            plan.signing().identity().unwrap(),
            "Developer ID Application: Vectie",
          )
          assert_eq(plan.signing().team_id().unwrap(), "ABCDE12345")
          assert_eq(
            plan.signing().entitlements_path().unwrap(),
            "macos/entitlements.plist",
          )
          assert_eq(plan.signing_steps().length(), 1)
          assert_eq(plan.signing_steps()[0].tool(), "gpg")
          match plan.files() {
            Ok(files) => {
              assert_true(
                files[2]
                .content()
                .contains("\"timestampUrl\":\"https://timestamp.local\""),
              )
              assert_true(files[2].content().contains("\"signingSteps\""))
            }
            Err(_) => abort("unexpected invalid bundle files")
          }
        }
        Err(_) => abort("unexpected invalid bundle plan")
      }
    Err(_) => abort("unexpected invalid project config")
  }
}

///|
test "project config expands official plugin declarations" {
  let config =
    #|{
    #|  "identifier": "dev.local.official",
    #|  "productName": "Official Plugins",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Official Plugins" },
    #|  "plugins": [
    #|    { "name": "autoLaunch" },
    #|    { "name": "clipboard" },
    #|    { "name": "deepLink" },
    #|    { "name": "dialog" },
    #|    { "name": "fileDialog" },
    #|    { "name": "localhost" },
    #|    { "name": "log" },
    #|    { "name": "notification" },
    #|    { "name": "opener" },
    #|    { "name": "process" },
    #|    { "name": "serviceDiscovery" },
    #|    { "name": "shell" },
    #|    { "name": "singleInstance" },
    #|    { "name": "store" },
    #|    { "name": "tray" },
    #|    { "name": "updater" },
    #|    { "name": "windowState" },
    #|    { "name": "fs" }
    #|  ],
    #|  "capabilities": [
    #|    {
    #|      "name": "main",
    #|      "windows": ["main"],
    #|      "commands": ["log.write", "store.keys"],
    #|      "permissions": ["auto-launch", "clipboard", "deep-link", "dialog", "file-dialog", "filesystem.read", "localhost", "notification", "opener", "process.info", "service-discovery", "shell", "single-instance", "tray", "updater", "window-state"]
    #|    }
    #|  ]
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          let routes = plan.command_routes()
          assert_true(routes.contains("autoLaunch.status"))
          assert_true(routes.contains("clipboard.readText"))
          assert_true(routes.contains("deepLink.getInitialUrls"))
          assert_true(routes.contains("dialog.message"))
          assert_true(routes.contains("fileDialog.openFile"))
          assert_true(routes.contains("localhost.status"))
          assert_true(routes.contains("log.write"))
          assert_true(routes.contains("notification.show"))
          assert_true(routes.contains("opener.openUrl"))
          assert_true(routes.contains("process.info"))
          assert_true(routes.contains("serviceDiscovery.list"))
          assert_true(routes.contains("shell.execute"))
          assert_true(routes.contains("singleInstance.acquire"))
          assert_true(routes.contains("store.set"))
          assert_true(routes.contains("tray.setMenu"))
          assert_true(routes.contains("updater.check"))
          assert_true(routes.contains("windowState.save"))
          assert_true(routes.contains("fs.readText"))
          assert_true(routes.contains("fs.writeText"))
          assert_true(
            plan.command_permission("fs.readText") is Some(FileSystemRead),
          )
          assert_true(
            plan.command_permission("fs.writeText") is Some(FileSystemWrite),
          )
          let window_routes = plan.window_command_routes("main")
          assert_true(window_routes.contains("autoLaunch.setEnabled"))
          assert_true(window_routes.contains("clipboard.writeText"))
          assert_true(window_routes.contains("deepLink.onOpenUrl"))
          assert_true(window_routes.contains("deepLink.openUrl"))
          assert_true(window_routes.contains("dialog.confirm"))
          assert_true(window_routes.contains("fileDialog.saveFile"))
          assert_true(window_routes.contains("localhost.waitUntilReady"))
          assert_true(window_routes.contains("log.write"))
          assert_true(window_routes.contains("notification.requestPermission"))
          assert_true(window_routes.contains("opener.revealPath"))
          assert_true(window_routes.contains("process.cwd"))
          assert_false(window_routes.contains("process.env"))
          assert_true(
            window_routes.contains("serviceDiscovery.onServiceChanged"),
          )
          assert_true(window_routes.contains("shell.spawn"))
          assert_true(window_routes.contains("singleInstance.onSecondLaunch"))
          assert_true(window_routes.contains("store.keys"))
          assert_true(window_routes.contains("tray.onMenuItemClick"))
          assert_true(window_routes.contains("updater.downloadAndInstall"))
          assert_true(window_routes.contains("windowState.restore"))
          assert_true(window_routes.contains("fs.readText"))
          assert_false(window_routes.contains("fs.writeText"))
        }
        Err(_) => abort("unexpected invalid runtime plan")
      }
    Err(_) => abort("unexpected invalid project config")
  }
}

///|
test "project config validates required shape" {
  match @project.ProjectConfig::parse("{}") {
    Ok(_) => abort("expected invalid project config")
    Err(problems) => {
      assert_true(problems.contains("project identifier is required"))
      assert_true(problems.contains("project productName is required"))
      assert_true(problems.contains("project window is required"))
    }
  }
}

///|
test "project config rejects unknown permissions" {
  let config =
    #|{
    #|  "identifier": "dev.local.bad-permission",
    #|  "productName": "Bad Permission",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Bad Permission" },
    #|  "capabilities": [
    #|    { "name": "main", "permissions": ["root"] }
    #|  ]
    #|}
    #|
  match @project.ProjectConfig::parse(config) {
    Ok(_) => abort("expected invalid project config")
    Err(problems) => assert_true(problems.contains("unknown permission: root"))
  }
}

///|
async test "project option requires path" {
  let result = render_cli_async(["plan", "--project"])
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("--project requires a file path"))
}

///|
async test "plugin new writes standalone plugin skeleton" {
  let root = "/tmp/lepusa-plugin-\{@async.now().to_int()}"
  let result = render_cli_async(["plugin", "new", "File Dialog", root])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa plugin new"))
  assert_true(result.output.contains("plugin: file-dialog"))
  assert_true(result.output.contains("files: 4"))
  assert_true(@fs.exists(root + "/moon.mod"))
  assert_true(@fs.exists(root + "/src/moon.pkg"))
  assert_true(@fs.exists(root + "/src/plugin.mbt"))
  assert_true(@fs.exists(root + "/README.mbt.md"))
  let module_file = @fs.read_file(root + "/moon.mod").text()
  assert_true(module_file.contains("local/lepusa_plugin_file_dialog"))
  assert_true(module_file.contains("vectie/lepusa@0.1.0"))
  let plugin_file = @fs.read_file(root + "/src/plugin.mbt").text()
  assert_true(plugin_file.contains("@lepusa.Plugin::new(\"file-dialog\")"))
  assert_true(plugin_file.contains("\"file-dialog.invoke\""))
  assert_true(plugin_file.contains("CommandRegistry"))
}

///|
async test "plugin new can write local workspace scaffold" {
  let root = "/tmp/lepusa-plugin-workspace-\{@async.now().to_int()}"
  let result = render_cli_async([
    "plugin", "new", "File Dialog", root, "--workspace", "/Users/kq/Workspace/lepusa",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("plugin: file-dialog"))
  assert_true(result.output.contains("workspace: /Users/kq/Workspace/lepusa"))
  assert_true(result.output.contains("files: 5"))
  assert_true(@fs.exists(root + "/moon.work"))
  let workspace_file = @fs.read_file(root + "/moon.work").text()
  assert_true(workspace_file.contains("\".\""))
  assert_true(workspace_file.contains("\"/Users/kq/Workspace/lepusa\""))
}

///|
async test "plugin new workspace option requires path" {
  let result = render_cli_async([
    "plugin", "new", "demo", "/tmp/lepusa-plugin-missing-workspace", "--workspace",
  ])
  assert_eq(result.exit_code, 1)
  assert_true(
    result.output.contains("--workspace requires a Lepusa checkout path"),
  )
}

///|
async test "plugin new validates plugin name" {
  let result = render_cli_async(["plugin", "new", "!!!"])
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("plugin name is required"))
}

///|
async test "bundle write materializes planned files" {
  let root = "/tmp/lepusa-bundle-write-\{@async.now().to_int()}"
  let result = render_cli_async(["bundle-write", "linux", root])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("local-services: 0"))
  assert_true(result.output.contains("resources: 0"))
  assert_true(result.output.contains("runtime-dependencies: 1"))
  assert_true(result.output.contains("verification-checks: 9"))
  assert_true(result.output.contains("verified: true"))
  assert_true(result.output.contains("[ok] verify: planned-file"))
  assert_true(result.output.contains("planned file content matches"))
  assert_true(result.output.contains("executable planned file content matches"))
  assert_true(result.output.contains("[ok] verify: runtime-manifest"))
  assert_true(
    result.output.contains("runtime manifest parses with webview data"),
  )
  assert_true(result.output.contains("[ok] verify: distribution-manifest"))
  assert_true(
    result.output.contains(
      "distribution manifest parses with artifact and dependency data",
    ),
  )
  assert_true(result.output.contains("[ok] verify: initial-content"))
  assert_true(result.output.contains("initial content checked=1 skipped=0"))
  assert_true(result.output.contains("[ok] verify: native-launch-session"))
  assert_true(result.output.contains("native launch session prepares"))
  assert_true(result.output.contains("[ok] verify: runtime-dependency"))
  assert_true(
    result.output.contains("external runtime dependency declared: WebKitGTK"),
  )
  assert_true(result.output.contains("signing-prerequisites: 2"))
  assert_true(result.output.contains("files: 4"))
  let bundle_root = root + "/lepusa-example"
  let desktop_path = bundle_root + "/lepusa-example.desktop"
  let launcher_path = bundle_root + "/lepusa-example"
  let runtime_path = bundle_root + "/lepusa/runtime.json"
  let distribution_path = bundle_root + "/lepusa/distribution.json"
  assert_true(@fs.exists(desktop_path))
  assert_true(@fs.exists(launcher_path))
  assert_true(@fs.exists(runtime_path))
  assert_true(@fs.exists(distribution_path))
  assert_true(
    @fs.read_file(desktop_path).text().contains("Name=Lepusa Example"),
  )
  let launcher = @fs.read_file(launcher_path).text()
  assert_true(launcher.contains("RUNTIME=lepusa-runtime"))
  assert_true(launcher.contains("trap cleanup INT TERM HUP"))
  assert_true(launcher.contains("\"$RUNTIME\" launch"))
  assert_true(launcher.contains("RUNTIME_PID=$!"))
  assert_true(launcher.contains("wait \"$RUNTIME_PID\""))
  assert_true(launcher.contains("lepusa/runtime.json"))
  let runtime_manifest = @fs.read_file(runtime_path).text()
  assert_true(runtime_manifest.contains("\"target\":\"linux\""))
  assert_true(runtime_manifest.contains("\"capabilities\""))
  assert_true(runtime_manifest.contains("\"signingPrerequisites\""))
  assert_true(runtime_manifest.contains("\"initializationScripts\""))
  assert_true(runtime_manifest.contains("__lepusaInvoke"))
  let distribution_manifest = @fs.read_file(distribution_path).text()
  assert_true(distribution_manifest.contains("\"target\":\"linux\""))
  assert_true(distribution_manifest.contains("\"runtimeDependencies\""))
  assert_true(distribution_manifest.contains("\"runtimeExecutable\""))
  assert_true(distribution_manifest.contains("WebKitGTK 4.1 or 4.0"))
  let inspect = render_cli_async(["bundle-inspect", distribution_path])
  assert_eq(inspect.exit_code, 0)
  assert_true(inspect.output.contains("Lepusa distribution"))
  assert_true(inspect.output.contains("identifier: dev.vectie.lepusa.example"))
  assert_true(inspect.output.contains("target: linux"))
  assert_true(inspect.output.contains("runtime-dependencies: 1"))
  let inspect_json = render_cli_async([
    "bundle-inspect", distribution_path, "--json",
  ])
  assert_eq(inspect_json.exit_code, 0)
  assert_true(inspect_json.output.contains("\"target\":\"linux\""))
  assert_true(inspect_json.output.contains("\"runtimeDependencies\":["))
  assert_true(inspect_json.output.contains("WebKitGTK 4.1 or 4.0"))
  let release = render_cli_async(["bundle-release-plan", distribution_path])
  assert_eq(release.exit_code, 0)
  assert_true(release.output.contains("Lepusa release plan"))
  assert_true(release.output.contains("steps: 5"))
  assert_true(release.output.contains("required-steps: 3"))
  assert_true(release.output.contains("required-items: 5"))
  assert_true(release.output.contains("ready: true"))
  assert_true(release.output.contains("step: validate-runtime-dependencies"))
  assert_true(release.output.contains("step: collect-artifacts"))
  let release_json = render_cli_async([
    "bundle-release-plan", distribution_path, "--json",
  ])
  assert_eq(release_json.exit_code, 0)
  assert_true(release_json.output.contains("\"ready\":true"))
  assert_true(release_json.output.contains("\"requiredStepCount\":3"))
  assert_true(release_json.output.contains("\"missingRequiredSteps\":[]"))
  assert_true(release_json.output.contains("\"steps\":["))
  assert_true(
    release_json.output.contains("\"kind\":\"validate-signing-prerequisites\""),
  )
  assert_true(release_json.output.contains("\"kind\":\"collect-artifacts\""))
  let json_root = "/tmp/lepusa-bundle-write-json-\{@async.now().to_int()}"
  let json_result = render_cli_async([
    "bundle-write", "linux", json_root, "--json",
  ])
  assert_eq(json_result.exit_code, 0)
  assert_true(json_result.output.contains("\"target\":\"linux\""))
  assert_true(
    json_result.output.contains("\"identifier\":\"dev.vectie.lepusa.example\""),
  )
  assert_true(json_result.output.contains("\"bundle\":{"))
  assert_true(json_result.output.contains("\"root\":\"\{json_root}\""))
  assert_true(json_result.output.contains("\"verified\":true"))
  assert_true(json_result.output.contains("\"checks\":["))
  assert_true(json_result.output.contains("\"kind\":\"planned-file\""))
  assert_true(json_result.output.contains("\"kind\":\"runtime-manifest\""))
  assert_true(json_result.output.contains("\"kind\":\"distribution-manifest\""))
  assert_true(json_result.output.contains("\"kind\":\"initial-content\""))
  assert_true(json_result.output.contains("\"kind\":\"native-launch-session\""))
  assert_true(json_result.output.contains("\"kind\":\"runtime-dependency\""))
  assert_true(json_result.output.contains("WebKitGTK 4.1 or 4.0"))
  assert_true(
    json_result.output.contains(
      "\"message\":\"native launch session prepares\"",
    ),
  )
  assert_true(json_result.output.contains("\"signingPrerequisites\":2"))
}

///|
async test "bundle write embeds host runtime executable when compatible" {
  let root = "/tmp/lepusa-runtime-executable-\{@async.now().to_int()}"
  let result = render_cli_async(["bundle-write", "macos", root])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: macos"))
  let source_exists = @fs.exists(
    "_build/native/debug/build/cmd/runtime/runtime.exe",
  ) catch {
    _ => false
  }
  if @macos_backend.available() && source_exists {
    assert_true(result.output.contains("verification-checks: 10"))
    assert_true(result.output.contains("files: 5"))
    assert_true(result.output.contains("[ok] verify: runtime-executable"))
    assert_true(result.output.contains("runtime executable is bundled"))
    assert_true(
      @fs.exists(root + "/lepusa-example.app/Contents/MacOS/lepusa-runtime"),
    )
  } else {
    assert_true(result.output.contains("verification-checks: 9"))
    assert_true(result.output.contains("[ok] verify: runtime-dependency"))
    assert_true(
      result.output.contains("external runtime dependency declared: WKWebView"),
    )
    assert_false(result.output.contains("runtime-executable"))
  }
}

///|
async test "bundle write gates target launch capability" {
  let root = "/tmp/lepusa-windows-bundle-write-\{@async.now().to_int()}"
  let result = render_cli_async(["bundle-write", "windows", root])
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("target: windows"))
  assert_true(result.output.contains("verified: false"))
  assert_true(result.output.contains("[fail] verify: native-launch-session"))
  assert_true(result.output.contains("[fail] verify: runtime-dependency"))
  assert_true(result.output.contains("WebView2Loader.dll"))
  assert_true(
    result.output.contains(
      "from _build/native/debug/build/cmd/runtime/WebView2Loader.dll",
    ),
  )
  assert_true(result.output.contains("Windows WebView2"))
  assert_true(@fs.exists(root + "/lepusa-example/lepusa-example.cmd"))
  assert_true(@fs.exists(root + "/lepusa-example/lepusa/runtime.json"))
  let json_root = "/tmp/lepusa-windows-bundle-write-json-\{@async.now().to_int()}"
  let json_result = render_cli_async([
    "bundle-write", "windows", json_root, "--json",
  ])
  assert_eq(json_result.exit_code, 1)
  assert_true(json_result.output.contains("\"target\":\"windows\""))
  assert_true(json_result.output.contains("\"verified\":false"))
  assert_true(json_result.output.contains("\"kind\":\"native-launch-session\""))
  assert_true(json_result.output.contains("\"kind\":\"runtime-dependency\""))
  assert_true(json_result.output.contains("\"ok\":false"))
  assert_true(json_result.output.contains("WebView2Loader.dll"))
  assert_true(
    json_result.output.contains(
      "_build/native/debug/build/cmd/runtime/WebView2Loader.dll",
    ),
  )
  assert_true(json_result.output.contains("Windows WebView2"))
  assert_true(@fs.exists(json_root + "/lepusa-example/lepusa/runtime.json"))
}

///|
async test "bundle write copies configured runtime dependency files" {
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-windows-loader-\{stamp}"
  let out = "/tmp/lepusa-windows-loader-out-\{stamp}"
  @fs.mkdir(root + "/vendor", recursive=true, permission=0o755)
  @fs.write_file(
    root + "/vendor/WebView2Loader.dll",
    b"fake-loader",
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let config = [
    "{", "\"identifier\":\"dev.local.loader\",", "\"productName\":\"Loader App\",",
    "\"version\":\"0.1.0\",", "\"window\":{\"label\":\"main\",\"title\":\"Loader App\"},",
    "\"runtimeDependencies\":[{", "\"name\":\"WebView2Loader.dll\",", "\"source\":\"vendor/WebView2Loader.dll\"",
    "}]", "}",
  ].join("")
  @fs.write_file(
    root + "/lepusa.json",
    @utf8.encode(config),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let result = render_cli_async([
    "bundle-write",
    "windows",
    out,
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("[fail] verify: native-launch-session"))
  assert_true(result.output.contains("[ok] verify: runtime-dependency"))
  assert_true(
    result.output.contains("runtime dependency is bundled: WebView2Loader.dll"),
  )
  let loader_path = out + "/loader-app/WebView2Loader.dll"
  assert_true(@fs.exists(loader_path))
  assert_eq(@fs.read_file(loader_path).text(), "fake-loader")
}

///|
async test "bundle write fails when native launch session is blocked" {
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-async-bundle-\{stamp}"
  let out = "/tmp/lepusa-async-bundle-out-\{stamp}"
  @fs.mkdir(root + "/data", recursive=true, permission=0o755)
  let config = [
    "{", "\"identifier\":\"dev.local.async\",", "\"productName\":\"Async App\",",
    "\"version\":\"0.1.0\",", "\"window\":{\"label\":\"main\",\"title\":\"Async App\"},",
    "\"plugins\":[{\"name\":\"fs\"}],", "\"filesystemScopes\":[{\"name\":\"data\",\"root\":\"data\",\"writable\":true}],",
    "\"capabilities\":[{\"name\":\"main\",\"windows\":[\"main\"],\"permissions\":[\"filesystem.read\",\"filesystem.write\"]}]",
    "}",
  ].join("")
  @fs.write_file(
    root + "/lepusa.json",
    config,
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let result = render_cli_async([
    "bundle-write",
    "linux",
    out,
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("verified: false"))
  assert_true(result.output.contains("[fail] verify: native-launch-session"))
  assert_true(result.output.contains("requires native async bridge scheduling"))
}

///|
async test "bundle write rejects blank initial webview content" {
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-blank-bundle-\{stamp}"
  let out = "/tmp/lepusa-blank-bundle-out-\{stamp}"
  @fs.mkdir(root, recursive=true, permission=0o755)
  @fs.write_file(
    root + "/lepusa.json",
    (
      #|{
      #|  "identifier": "dev.local.blankbundle",
      #|  "productName": "Blank Bundle",
      #|  "version": "0.1.0",
      #|  "window": {
      #|    "label": "main",
      #|    "title": "Blank Bundle",
      #|    "source": { "html": "   " }
      #|  }
      #|}
    ),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let result = render_cli_async([
    "bundle-write",
    "linux",
    out,
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("verified: false"))
  assert_true(result.output.contains("[fail] verify: initial-content"))
  assert_true(result.output.contains("window main has blank virtual asset"))
  assert_true(@fs.exists(out + "/blank-bundle/lepusa/runtime.json"))
}

///|
async test "bundle write materializes planned resources" {
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-resource-project-\{stamp}"
  let bundle_root = "/tmp/lepusa-resource-bundle-\{stamp}-out"
  @fs.mkdir(root, recursive=true, permission=0o755)
  @fs.mkdir(root + "/assets", recursive=true, permission=0o755)
  @fs.write_file(
    root + "/assets/icon.png",
    b"icon-bytes",
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let config = [
    "{",
    "\"identifier\":\"dev.local.resource\",",
    "\"productName\":\"Resource App\",",
    "\"version\":\"0.1.0\",",
    "\"icon\":\"\{root}/assets/icon.png\",",
    "\"window\":{\"label\":\"main\",\"title\":\"Resource App\"}",
    "}",
  ].join("")
  @fs.write_file(
    root + "/lepusa.json",
    config,
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let result = render_cli_async([
    "bundle-write",
    "linux",
    bundle_root,
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("resources: 1"))
  assert_true(result.output.contains("resources-written: 1"))
  assert_true(result.output.contains("runtime-dependencies: 1"))
  assert_true(result.output.contains("verification-checks: 10"))
  assert_true(result.output.contains("verified: true"))
  assert_true(result.output.contains("[ok] verify: initial-content"))
  assert_true(result.output.contains("[ok] verify: planned-resource"))
  assert_true(result.output.contains("[ok] verify: runtime-dependency"))
  assert_true(result.output.contains("resource exists"))
  let icon_path = bundle_root + "/resource-app/resource-app.png"
  assert_true(@fs.exists(icon_path))
  assert_eq(@fs.read_file(icon_path).text(), "icon-bytes")
}

///|
async test "bundle write materializes packaged asset directories" {
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-packaged-project-\{stamp}"
  let bundle_root = "/tmp/lepusa-packaged-bundle-\{stamp}-out"
  @fs.mkdir(root + "/dist/css", recursive=true, permission=0o755)
  @fs.write_file(
    root + "/dist/index.html",
    b"<main>packaged</main>",
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  @fs.write_file(
    root + "/dist/css/app.css",
    b"body{}",
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let config = [
    "{",
    "\"identifier\":\"dev.local.packaged\",",
    "\"productName\":\"Packaged App\",",
    "\"version\":\"0.1.0\",",
    "\"window\":{\"label\":\"main\",\"title\":\"Packaged App\",",
    "\"source\":{\"packaged\":\"\{root}/dist\"}}",
    "}",
  ].join("")
  @fs.write_file(
    root + "/lepusa.json",
    config,
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let result = render_cli_async([
    "bundle-write",
    "linux",
    bundle_root,
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("resources: 1"))
  assert_true(result.output.contains("resources-written: 1"))
  assert_true(result.output.contains("[ok] verify: initial-content"))
  assert_true(result.output.contains("initial content checked=1 skipped=0"))
  let asset_root = bundle_root + "/packaged-app/lepusa/assets/main"
  assert_true(@fs.exists(asset_root + "/index.html"))
  assert_true(@fs.exists(asset_root + "/css/app.css"))
  assert_eq(@fs.read_file(asset_root + "/css/app.css").text(), "body{}")
  let runtime_json = @fs.read_file(
    bundle_root + "/packaged-app/lepusa/runtime.json",
  ).text()
  assert_true(runtime_json.contains("\"package:lepusa/assets/main\""))
  assert_false(runtime_json.contains("\"package:\{root}/dist\""))
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
  let bundle = render_cli_async(["bundle", "linux", bundle_root])
  assert_eq(bundle.exit_code, 0)
  assert_true(bundle.output.contains("target: linux"))
  assert_true(
    @fs.exists(bundle_root + "/lepusa-example/lepusa-example.desktop"),
  )
  assert_true(@fs.exists(bundle_root + "/lepusa-example/lepusa-example"))
  let linux_runtime_json = @fs.read_file(
    bundle_root + "/lepusa-example/lepusa/runtime.json",
  ).text()
  assert_true(linux_runtime_json.contains("\"target\":\"linux\""))
  assert_true(linux_runtime_json.contains("\"productName\":\"Lepusa Example\""))
}

///|
async test "bridge prints generated javascript" {
  let result = render_cli_async(["bridge"])
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
