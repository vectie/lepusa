///|
test "help text names available commands" {
  let result = render_cli([])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("lepusa doctor"))
  assert_true(result.output.contains("lepusa bridge"))
  assert_true(result.output.contains("lepusa dev"))
  assert_true(result.output.contains("lepusa invoke"))
  assert_true(result.output.contains("lepusa manifest"))
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
  assert_true(result.output.contains("files: 5"))
  assert_true(@fs.exists(root + "/moon.mod"))
  assert_true(@fs.exists(root + "/moon.pkg"))
  assert_true(@fs.exists(root + "/lepusa.json"))
  assert_true(@fs.exists(root + "/main.mbt"))
  assert_true(@fs.exists(root + "/README.mbt.md"))
  let module_file = @fs.read_file(root + "/moon.mod").text()
  assert_true(module_file.contains("vectie/lepusa"))
  assert_true(module_file.contains("\"preferred-target\": \"native\""))
  let config_file = @fs.read_file(root + "/lepusa.json").text()
  assert_true(config_file.contains("\"productName\": \"Lepusa App\""))
  assert_true(config_file.contains("\"name\": \"log\""))
  assert_true(config_file.contains("\"name\": \"store\""))
  assert_true(config_file.contains("\"log.write\""))
  assert_true(config_file.contains("\"store.set\""))
  assert_true(config_file.contains("\"startup\": { \"effect\": \"boot\" }"))
  assert_true(config_file.contains("\"event\": \"app-will-exit\""))
  let main_file = @fs.read_file(root + "/main.mbt").text()
  assert_true(main_file.contains("@lepusa.new(root)"))
  assert_true(main_file.contains("RuntimeConfig::system_webview"))
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
  assert_true(result.output.contains("startup-operations: 1"))
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
  assert_true(manifest.output.contains("\"log.write\""))
  assert_true(manifest.output.contains("\"store.keys\""))
  assert_true(manifest.output.contains("Hello Lepusa"))
  assert_true(manifest.output.contains("\"startupActions\""))
  assert_true(manifest.output.contains("\"name\":\"boot\""))
  assert_true(manifest.output.contains("\"kind\":\"app-will-exit\""))
  assert_true(manifest.output.contains("\"name\":\"shutdown\""))
  let out = "/tmp/lepusa-project-bundle-out-\{@async.now().to_int()}"
  let build = render_cli_async(["build", "linux", out, "--project", project])
  assert_eq(build.exit_code, 0)
  assert_true(build.output.contains("target: linux"))
  let bundle_root = out + "/lepusa-app"
  assert_true(@fs.exists(bundle_root + "/lepusa/runtime.json"))
  assert_true(@fs.exists(bundle_root + "/lepusa-app.desktop"))
  let runtime_json = @fs.read_file(bundle_root + "/lepusa/runtime.json").text()
  assert_true(runtime_json.contains("\"registeredRoutes\""))
  assert_true(runtime_json.contains("\"log.write\""))
  assert_true(runtime_json.contains("\"store.set\""))
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
  match parse_project_config(config) {
    Ok(project) =>
      match project.manifest.runtime_plan(project.root) {
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
  match parse_project_config(config) {
    Ok(project) =>
      match project.manifest.runtime_plan(project.root) {
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
test "project config validates required shape" {
  match parse_project_config("{}") {
    Ok(_) => abort("expected invalid project config")
    Err(problems) => {
      assert_true(problems.contains("project identifier is required"))
      assert_true(problems.contains("project productName is required"))
      assert_true(problems.contains("project window is required"))
    }
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
  assert_true(module_file.contains("vectie/lepusa"))
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
