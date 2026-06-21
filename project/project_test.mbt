///|
test "project config parses app manifest boundary" {
  let config =
    #|{
    #|  "identifier": "dev.vectie.project",
    #|  "productName": "Project",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Project" },
    #|  "plugins": [{ "name": "log" }],
    #|  "capabilities": [{
    #|    "name": "main",
    #|    "windows": ["main"],
    #|    "commands": ["log.write"]
    #|  }]
    #|}
    #|
  match ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          assert_eq(plan.windows().length(), 1)
          assert_true(project.registry().routes().contains("log.write"))
          assert_true(plan.window_command_routes("main").contains("log.write"))
        }
        Err(problems) => abort(problems.join(", "))
      }
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "project config parses command request and response schemas" {
  let config =
    #|{
    #|  "identifier": "dev.vectie.typed",
    #|  "productName": "Typed",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Typed" },
    #|  "plugins": [{
    #|    "name": "window",
    #|    "commands": [{
    #|      "name": "setTitle",
    #|      "permission": "window",
    #|      "requestSchema": {
    #|        "name": "SetTitleRequest",
    #|        "typescript": "{ readonly title: string }"
    #|      },
    #|      "responseSchema": {
    #|        "name": "Unit",
    #|        "typescript": "void"
    #|      }
    #|    }]
    #|  }],
    #|  "capabilities": [{
    #|    "name": "main",
    #|    "windows": ["main"],
    #|    "permissions": ["window"]
    #|  }]
    #|}
    #|
  match ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) =>
          match plan.command_manifest().entry("window.setTitle") {
            Some(entry) => {
              assert_eq(entry.request_schema().name(), "SetTitleRequest")
              assert_eq(
                entry.request_schema().typescript(),
                "{ readonly title: string }",
              )
              assert_eq(entry.response_schema().typescript(), "void")
            }
            None => abort("missing typed command")
          }
        Err(problems) => abort(problems.join(", "))
      }
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "project config parses plugin lifecycle hooks" {
  let config =
    #|{
    #|  "identifier": "dev.vectie.plugin.lifecycle",
    #|  "productName": "PluginLifecycle",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Lifecycle" },
    #|  "plugins": [{
    #|    "name": "log",
    #|    "commands": ["write"],
    #|    "lifecycle": [
    #|      { "event": "setup", "command": "log.setup" },
    #|      { "event": "ready", "command": { "emit": "log-ready" } },
    #|      { "event": "will-exit", "command": "log.flush" }
    #|    ]
    #|  }],
    #|  "capabilities": [{
    #|    "name": "main",
    #|    "windows": ["main"],
    #|    "commands": ["log.write"]
    #|  }]
    #|}
    #|
  match ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          match plan.lifecycle_actions(PluginSetup("log")) {
            Ok(actions) => assert_true(actions[0] is RuntimeEffect("log.setup"))
            Err(problems) => abort(problems.join(", "))
          }
          match plan.lifecycle_actions(PluginWillExit("log")) {
            Ok(actions) => assert_true(actions[0] is RuntimeEffect("log.flush"))
            Err(problems) => abort(problems.join(", "))
          }
          let hooks = plan.lifecycle_hooks().unwrap()
          assert_eq(hooks.length(), 3)
          assert_true(hooks[0].event() is PluginSetup("log"))
          assert_true(hooks[1].event() is PluginReady("log"))
          assert_true(hooks[2].event() is PluginWillExit("log"))
        }
        Err(problems) => abort(problems.join(", "))
      }
    Err(problems) => abort(problems.join(", "))
  }
}

///|
async test "project config loads file relative resources" {
  let root = "/tmp/lepusa-project-load-\{@async.now().to_int()}"
  @fs.mkdir(root + "/dist", recursive=true, permission=0o755)
  @fs.mkdir(root + "/vendor", recursive=true, permission=0o755)
  @fs.write_file(
    root + "/dist/index.html",
    b"<main>loaded</main>",
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let config =
    #|{
    #|  "identifier": "dev.vectie.loaded",
    #|  "productName": "Loaded",
    #|  "version": "0.1.0",
    #|  "window": {
    #|    "label": "main",
    #|    "title": "Loaded",
    #|    "source": { "packaged": "dist" }
    #|  },
    #|  "runtimeDependencies": [{
    #|    "name": "WebView2Loader.dll",
    #|    "source": "vendor/WebView2Loader.dll"
    #|  }]
    #|}
    #|
  @fs.write_file(
    root + "/lepusa.json",
    @utf8.encode(config),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  match ProjectConfig::load(root + "/lepusa.json") {
    Ok(project) =>
      match project.manifest().bundle_plan(project.root(), target=Linux) {
        Ok(plan) => {
          assert_eq(plan.resources().length(), 1)
          assert_eq(plan.resources()[0].source_path(), root + "/dist")
          assert_eq(plan.resources()[0].path(), "loaded/lepusa/assets/main")
        }
        Err(problems) => abort(problems.join(", "))
      }
    Err(problems) => abort(problems.join(", "))
  }
  match ProjectConfig::load(root + "/lepusa.json") {
    Ok(project) =>
      match project.manifest().bundle_plan(project.root(), target=Windows) {
        Ok(plan) => {
          let sources = plan.runtime_dependency_sources()
          assert_eq(sources.length(), 1)
          assert_eq(sources[0].name(), "WebView2Loader.dll")
          assert_eq(
            sources[0].source_path(),
            root + "/vendor/WebView2Loader.dll",
          )
          assert_eq(
            plan.runtime_dependencies()[1].source_path().unwrap(),
            root + "/vendor/WebView2Loader.dll",
          )
        }
        Err(problems) => abort(problems.join(", "))
      }
    Err(problems) => abort(problems.join(", "))
  }
}
