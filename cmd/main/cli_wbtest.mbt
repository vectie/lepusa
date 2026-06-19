///|
test "help text names available commands" {
  let result = render_cli([])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("lepusa doctor"))
  assert_true(result.output.contains("lepusa bridge"))
  assert_true(result.output.contains("lepusa dev"))
  assert_true(result.output.contains("lepusa invoke"))
  assert_true(result.output.contains("lepusa asset"))
  assert_true(result.output.contains("lepusa lifecycle"))
  assert_true(result.output.contains("lepusa manifest"))
  assert_true(result.output.contains("lepusa native-plan"))
  assert_true(result.output.contains("lepusa run"))
  assert_true(result.output.contains("lepusa init"))
  assert_true(result.output.contains("lepusa build"))
  assert_true(result.output.contains("lepusa bundle"))
  assert_true(result.output.contains("lepusa plugin new"))
  assert_true(result.output.contains("lepusa bundle-plan"))
  assert_true(result.output.contains("lepusa bundle-write"))
  assert_true(result.output.contains("--project <lepusa.json>"))
}

///|
test "doctor renders framework boundary checks" {
  let result = render_cli(["doctor"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("[ok] public-api"))
  assert_true(result.output.contains("backend=headless"))
  assert_true(result.output.contains("[ok] manifest: webviews=1 routes=2"))
  assert_true(result.output.contains("[ok] bundle: target=macos"))
  assert_true(result.output.contains("[ok] signing: prerequisites=3"))
  assert_true(result.output.contains("Developer ID Application certificate"))
  assert_true(result.output.contains("platform: macos"))
  assert_true(result.output.contains("engine=WKWebView"))
  assert_true(result.output.contains("platform: windows"))
  assert_true(result.output.contains("platform: linux"))
}

///|
test "doctor supports target-specific signing diagnostics" {
  let result = render_cli(["doctor", "linux"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("[ok] bundle: target=linux"))
  assert_true(result.output.contains("[ok] signing: prerequisites=2"))
  assert_false(result.output.contains("package-signing-key"))
  assert_true(result.output.contains("package signing key"))
  let unknown = render_cli(["doctor", "ios"])
  assert_eq(unknown.exit_code, 1)
  assert_true(unknown.output.contains("unknown bundle target: ios"))
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
test "native plan prints backend bootstrap json" {
  let result = render_cli(["native-plan", "macos"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"nativeBackend\":\"macos\""))
  assert_true(result.output.contains("\"webviewEngine\":\"WKWebView\""))
  assert_true(result.output.contains("\"webviewSpecs\""))
  assert_true(result.output.contains("\"startupOperations\""))
  assert_true(result.output.contains("\"lifecycleOperations\""))
  assert_true(result.output.contains("\"nativeHook\":\"__lepusaInvoke\""))
}

///|
test "run prints native runner smoke summary" {
  let result = render_cli(["run", "linux"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa run"))
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("backend: linux"))
  assert_true(result.output.contains("engine: WebKitGTK"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("bridge: lepusa://runtime/bridge.js"))
  assert_true(result.output.contains("startup-operations: 0"))
  assert_true(result.output.contains("lifecycle-steps: 0"))
}

///|
test "run launch rejects unwired native targets" {
  let result = render_cli(["run", "linux", "--launch"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa launch"))
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("backend: linux"))
  assert_true(result.output.contains("engine: WebKitGTK"))
  assert_true(result.output.contains("status: unsupported"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("startup-operations: 0"))
}

///|
test "bundle plan supports target selection" {
  let result = render_cli(["bundle-plan", "windows"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: windows"))
  assert_true(result.output.contains("bundle: lepusa-example.exe"))
  assert_true(result.output.contains("resources: 0"))
  assert_true(result.output.contains("signing-prerequisites: 3"))
  assert_true(result.output.contains("files: 3"))
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
  assert_true(@fs.exists(root + "/moon.pkg"))
  assert_true(@fs.exists(root + "/lepusa.json"))
  assert_true(@fs.exists(root + "/main.mbt"))
  assert_true(@fs.exists(root + "/README.mbt.md"))
  let module_file = @fs.read_file(root + "/moon.mod").text()
  assert_true(module_file.contains("vectie/lepusa@0.1.0"))
  assert_true(module_file.contains("\"preferred-target\": \"native\""))
  let config_file = @fs.read_file(root + "/lepusa.json").text()
  assert_true(config_file.contains("\"productName\": \"Lepusa App\""))
  assert_true(config_file.contains("\"name\": \"log\""))
  assert_true(config_file.contains("\"name\": \"store\""))
  assert_true(config_file.contains("Count: 0"))
  assert_true(config_file.contains("\"log.write\""))
  assert_true(config_file.contains("\"store.set\""))
  assert_true(config_file.contains("\"startup\": { \"effect\": \"boot\" }"))
  assert_true(config_file.contains("\"event\": \"app-will-exit\""))
  let main_file = @fs.read_file(root + "/main.mbt").text()
  assert_true(main_file.contains("enum Msg"))
  assert_true(main_file.contains("cell_with_dispatch"))
  assert_true(main_file.contains("@lepusa.new(root)"))
  assert_true(main_file.contains("RuntimeConfig::system_webview"))
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
  assert_true(result.output.contains("plugins: 3"))
  assert_true(result.output.contains("capabilities: 1"))
  assert_true(result.output.contains("core.invoke"))
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
  assert_true(result.output.contains("routes: core.invoke,core.events"))
  assert_true(result.output.contains("registered-routes:"))
  assert_true(result.output.contains("log.write"))
  assert_true(result.output.contains("store.set"))
  assert_true(result.output.contains("local-services: 0"))
  assert_true(result.output.contains("startup-operations: 1"))
}

///|
async test "generated project config drives doctor backend diagnostics" {
  let root = "/tmp/lepusa-project-doctor-\{@async.now().to_int()}"
  let init = render_cli_async(["init", root])
  assert_eq(init.exit_code, 0)
  let result = render_cli_async(["doctor", "--project", root + "/lepusa.json"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("backend=system-webview"))
  assert_true(result.output.contains("[ok] bundle: target=macos"))
  assert_true(result.output.contains("[ok] signing: prerequisites=3"))
  assert_true(result.output.contains("Developer ID Application certificate"))
  assert_true(result.output.contains("platform: macos"))
  assert_true(result.output.contains("platform: windows"))
  assert_true(result.output.contains("platform: linux"))
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
  assert_true(@fs.exists(root + "/moon.pkg"))
  assert_true(@fs.exists(root + "/plugin.mbt"))
  assert_true(@fs.exists(root + "/README.mbt.md"))
  let module_file = @fs.read_file(root + "/moon.mod").text()
  assert_true(module_file.contains("local/lepusa_plugin_file_dialog"))
  assert_true(module_file.contains("vectie/lepusa@0.1.0"))
  let plugin_file = @fs.read_file(root + "/plugin.mbt").text()
  assert_true(plugin_file.contains("@lepusa.Plugin::new(\"file-dialog\")"))
  assert_true(plugin_file.contains("\"file-dialog.invoke\""))
  assert_true(plugin_file.contains("CommandRegistry"))
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
  assert_true(result.output.contains("signing-prerequisites: 2"))
  assert_true(result.output.contains("files: 3"))
  let bundle_root = root + "/lepusa-example"
  let desktop_path = bundle_root + "/lepusa-example.desktop"
  let launcher_path = bundle_root + "/lepusa-example"
  let runtime_path = bundle_root + "/lepusa/runtime.json"
  assert_true(@fs.exists(desktop_path))
  assert_true(@fs.exists(launcher_path))
  assert_true(@fs.exists(runtime_path))
  assert_true(
    @fs.read_file(desktop_path).text().contains("Name=Lepusa Example"),
  )
  let launcher = @fs.read_file(launcher_path).text()
  assert_true(launcher.contains("lepusa-runtime launch"))
  assert_true(launcher.contains("lepusa/runtime.json"))
  let runtime_manifest = @fs.read_file(runtime_path).text()
  assert_true(runtime_manifest.contains("\"target\":\"linux\""))
  assert_true(runtime_manifest.contains("\"capabilities\""))
  assert_true(runtime_manifest.contains("\"signingPrerequisites\""))
  assert_true(runtime_manifest.contains("\"initializationScripts\""))
  assert_true(runtime_manifest.contains("__lepusaInvoke"))
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
  let bundle = render_cli_async(["bundle", "windows", bundle_root])
  assert_eq(bundle.exit_code, 0)
  assert_true(bundle.output.contains("target: windows"))
  assert_true(@fs.exists(bundle_root + "/lepusa-example/app.manifest.xml"))
  assert_true(@fs.exists(bundle_root + "/lepusa-example/lepusa-example.cmd"))
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
