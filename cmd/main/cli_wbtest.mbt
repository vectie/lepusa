///|
test "help text names available commands" {
  let result = render_cli([])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("lepusa doctor"))
  assert_true(result.output.contains("lepusa bridge"))
  assert_true(result.output.contains("lepusa dev"))
  assert_true(result.output.contains("lepusa invoke"))
  assert_true(result.output.contains("lepusa manifest"))
  assert_true(result.output.contains("lepusa native-plan"))
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
  assert_true(result.output.contains("platform: macos"))
  assert_true(result.output.contains("engine=WKWebView"))
  assert_true(result.output.contains("platform: windows"))
  assert_true(result.output.contains("platform: linux"))
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
  assert_true(result.output.contains("\"nativeHook\":\"__lepusaInvoke\""))
}

///|
test "bundle plan supports target selection" {
  let result = render_cli(["bundle-plan", "windows"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("target: windows"))
  assert_true(result.output.contains("bundle: lepusa-example.exe"))
  assert_true(result.output.contains("resources: 0"))
  assert_true(result.output.contains("signing-prerequisites: 3"))
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
  assert_true(result.output.contains("platform: macos"))
  assert_true(result.output.contains("platform: windows"))
  assert_true(result.output.contains("platform: linux"))
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
  assert_true(build.output.contains("local-services: 0"))
  assert_true(build.output.contains("resources: 0"))
  assert_true(build.output.contains("signing-prerequisites: 2"))
  let bundle_root = out + "/lepusa-app"
  assert_true(@fs.exists(bundle_root + "/lepusa/runtime.json"))
  assert_true(@fs.exists(bundle_root + "/lepusa-app.desktop"))
  let runtime_json = @fs.read_file(bundle_root + "/lepusa/runtime.json").text()
  assert_true(runtime_json.contains("\"registeredRoutes\""))
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
  match parse_project_config(config) {
    Ok(project) =>
      match project.manifest.runtime_plan(project.root) {
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
test "project config parses filesystem scopes" {
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
  match parse_project_config(config) {
    Ok(project) =>
      match project.manifest.runtime_plan(project.root) {
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
          match plan.launch_manifest() {
            Ok(manifest) => {
              assert_eq(manifest.file_system_scopes().length(), 2)
              assert_true(manifest.to_json().contains("\"filesystemScopes\""))
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
    #|  "window": { "label": "main", "title": "Icon App" }
    #|}
    #|
  match parse_project_config(config) {
    Ok(project) =>
      match project.manifest.bundle_plan(project.root, target=Linux) {
        Ok(plan) => {
          assert_eq(plan.resources().length(), 1)
          assert_eq(plan.resources()[0].source_path(), "assets/icon.png")
          assert_eq(plan.resources()[0].path(), "icon-app/icon-app.png")
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
    #|    { "name": "clipboard" },
    #|    { "name": "deepLink" },
    #|    { "name": "dialog" },
    #|    { "name": "fileDialog" },
    #|    { "name": "localhost" },
    #|    { "name": "log" },
    #|    { "name": "notification" },
    #|    { "name": "opener" },
    #|    { "name": "process" },
    #|    { "name": "shell" },
    #|    { "name": "singleInstance" },
    #|    { "name": "store" },
    #|    { "name": "fs" }
    #|  ],
    #|  "capabilities": [
    #|    {
    #|      "name": "main",
    #|      "windows": ["main"],
    #|      "commands": ["log.write", "store.keys"],
    #|      "permissions": ["clipboard", "deep-link", "dialog", "file-dialog", "filesystem.read", "localhost", "notification", "opener", "process.info", "shell", "single-instance"]
    #|    }
    #|  ]
    #|}
    #|
  match parse_project_config(config) {
    Ok(project) =>
      match project.manifest.runtime_plan(project.root) {
        Ok(plan) => {
          let routes = plan.command_routes()
          assert_true(routes.contains("clipboard.readText"))
          assert_true(routes.contains("deepLink.getInitialUrls"))
          assert_true(routes.contains("dialog.message"))
          assert_true(routes.contains("fileDialog.openFile"))
          assert_true(routes.contains("localhost.status"))
          assert_true(routes.contains("log.write"))
          assert_true(routes.contains("notification.show"))
          assert_true(routes.contains("opener.openUrl"))
          assert_true(routes.contains("process.info"))
          assert_true(routes.contains("shell.execute"))
          assert_true(routes.contains("singleInstance.acquire"))
          assert_true(routes.contains("store.set"))
          assert_true(routes.contains("fs.readText"))
          assert_true(routes.contains("fs.writeText"))
          assert_true(
            plan.command_permission("fs.readText") is Some(FileSystemRead),
          )
          assert_true(
            plan.command_permission("fs.writeText") is Some(FileSystemWrite),
          )
          let window_routes = plan.window_command_routes("main")
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
          assert_true(window_routes.contains("shell.spawn"))
          assert_true(window_routes.contains("singleInstance.onSecondLaunch"))
          assert_true(window_routes.contains("store.keys"))
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
  match parse_project_config(config) {
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
  assert_true(result.output.contains("local-services: 0"))
  assert_true(result.output.contains("resources: 0"))
  assert_true(result.output.contains("signing-prerequisites: 2"))
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
