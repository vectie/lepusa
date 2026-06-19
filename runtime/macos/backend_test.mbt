///|
fn test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="macOS", source=@lepusa.Source::html("<main>macOS</main>"))
    .with_startup(
      @lepusa.Cmd::batch([
        @lepusa.Cmd::emit(
          @lepusa.Event::new("ready"),
          target=WindowTarget("main"),
        ),
        @lepusa.Cmd::effect("boot"),
        @lepusa.Cmd::navigate(
          "main",
          @lepusa.Source::html("<main>ready</main>"),
        ),
      ]),
    )
    .with_lifecycle(
      @lepusa.LifecycleEvent::app_will_exit(),
      @lepusa.Cmd::effect("flush"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
fn multi_window_test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(
      label="main",
      title="Main",
      width=900,
      height=640,
      source=@lepusa.Source::html("<main>Main</main>"),
    )
    .window(
      label="settings",
      title="Settings",
      width=700,
      height=520,
      resizable=false,
      source=@lepusa.Source::html("<main>Settings</main>"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid multi-window runtime plan")
  }
}

///|
fn bridge_test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="macOS", source=@lepusa.Source::html("<main>macOS</main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => {
      let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
        payload,
      ) {
        Ok("{\"seen\":\{payload}}")
      })
      @runtime.RuntimeHost::new(plan, registry~)
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
fn async_bridge_test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="macOS", source=@lepusa.Source::html("<main>macOS</main>"))
    .with_plugin(@lepusa.Plugin::new("fs").command_async("readText"))
    .with_capability(
      @lepusa.Capability::new("fs").window("main").command("fs.readText"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => {
      let registry = @lepusa.CommandRegistry::new().register_async_fn(
        "fs.readText",
        handler=fn(payload) { Ok("{\"read\":\{payload}}") },
      )
      @runtime.RuntimeHost::new(plan, registry~)
    }
    Err(_) => abort("unexpected invalid async runtime plan")
  }
}

///|
test "macos backend exposes wkwebview descriptor" {
  let descriptor = backend()
  assert_eq(descriptor.name(), "macos")
  assert_eq(descriptor.webview_engine(), "WKWebView")
}

///|
test "macos backend links Cocoa and WebKit" {
  match detect() {
    Ok(descriptor) => {
      assert_eq(descriptor.name(), "macos")
      assert_eq(descriptor.webview_engine(), "WKWebView")
    }
    Err(problem) => abort(problem)
  }
}

///|
test "macos backend lowers runtime host to launch plan" {
  match backend().plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "macos")
      assert_eq(plan.webview_engine(), "WKWebView")
      let webviews = plan.webviews()
      assert_eq(webviews.length(), 1)
      assert_eq(webviews[0].title(), "macOS")
      assert_eq(webviews[0].url(), "lepusa://inline/main/index.html")
      assert_true(
        webviews[0].initialization_scripts()[0].contains("__lepusaInvoke"),
      )
      assert_eq(
        plan.runtime_manifest().bridge_url(),
        "lepusa://runtime/bridge.js",
      )
      let json = plan.manifest_json()
      assert_true(json.contains("\"nativeBackend\":\"macos\""))
      assert_true(json.contains("\"webviewEngine\":\"WKWebView\""))
      assert_true(json.contains("\"runtime\""))
      assert_true(json.contains("\"label\":\"main\""))
    }
    Err(_) => abort("unexpected invalid macOS launch plan")
  }
}

///|
test "macos backend prepares startup operations for native runner" {
  match backend().runner_plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "macos")
      assert_eq(plan.webview_engine(), "WKWebView")
      assert_eq(plan.webviews().length(), 1)
      let operations = plan.startup_operations()
      assert_eq(operations.length(), 3)
      assert_true(operations[0] is NativeSendEvent(WindowTarget("main"), _))
      assert_true(operations[1] is NativeRunEffect("boot"))
      assert_true(
        operations[2]
        is NativeNavigateWindow("main", "lepusa://inline/main/index.html"),
      )
      assert_eq(
        plan.session().windows()[0].url(),
        "lepusa://inline/main/index.html",
      )
      match plan.session().resolve_asset("lepusa://inline/main/index.html") {
        Ok(asset) =>
          assert_true(asset.body() is VirtualContent("<main>ready</main>"))
        Err(_) => abort("unexpected missing navigated macOS asset")
      }
      let json = plan.bootstrap_json()
      assert_true(json.contains("\"startupOperations\""))
      assert_true(json.contains("\"kind\":\"navigate-window\""))
      assert_true(json.contains("\"lifecycleOperations\""))
      assert_true(json.contains("\"name\":\"flush\""))
    }
    Err(_) => abort("unexpected invalid macOS runner plan")
  }
}

///|
test "macos backend exposes native runtime facade" {
  match runtime(test_host()) {
    Ok(runtime) => {
      assert_eq(runtime.backend().name(), "macos")
      assert_true(
        runtime.bootstrap_json().contains("\"nativeBackend\":\"macos\""),
      )
      assert_true(
        runtime
        .resolve_asset_json("lepusa://inline/main/index.html")
        .contains("\"kind\":\"virtual\""),
      )
    }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos backend prepares first webview load url" {
  match runtime(test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          let webviews = plan.webviews()
          assert_eq(webviews.length(), 1)
          let webview = webviews[0]
          assert_eq(webview.label(), "main")
          assert_eq(webview.title(), "macOS")
          assert_eq(webview.url(), "lepusa://inline/main/index.html")
          assert_eq(webview.load_url(), "lepusa://inline/main/index.html")
          assert_eq(webview.asset_protocol(), "lepusa")
          assert_true(
            webview.initialization_script().contains("webkit.messageHandlers"),
          )
          assert_true(
            webview.initialization_script().contains("__lepusaInvokeResponse"),
          )
          assert_true(webview.initialization_script().contains("windowLabel"))
          assert_eq(webview.width(), 1000)
          assert_eq(webview.height(), 720)
          let execution = plan.execution()
          assert_eq(execution.startup_operations().length(), 3)
          assert_true(
            execution.startup_operations()[1].contains(
              "\"kind\":\"run-effect\"",
            ),
          )
          let lifecycle_steps = execution.lifecycle_steps()
          assert_eq(lifecycle_steps.length(), 1)
          assert_true(
            lifecycle_steps[0]
            .event_json()
            .contains("\"kind\":\"app-will-exit\""),
          )
          assert_true(lifecycle_steps[0].operations()[0].contains("flush"))
          let bridge = plan.bridge()
          assert_eq(bridge.sync_command_routes().length(), 0)
          assert_eq(bridge.async_command_routes().length(), 0)
          assert_false(bridge.requires_async_dispatch())
        }
        Err(_) => abort("unexpected invalid macOS run plan")
      }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos backend marks async bridge routes" {
  match runtime(async_bridge_test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          let bridge = plan.bridge()
          assert_eq(bridge.sync_command_routes().length(), 0)
          let async_routes = bridge.async_command_routes()
          assert_eq(async_routes.length(), 1)
          assert_eq(async_routes[0], "fs.readText")
          assert_true(bridge.requires_async_dispatch())
        }
        Err(_) => abort("unexpected invalid async macOS run plan")
      }
    Err(_) => abort("unexpected invalid async macOS runtime")
  }
}

///|
test "macos backend preserves all webviews in run plan" {
  match runtime(multi_window_test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          let webviews = plan.webviews()
          assert_eq(webviews.length(), 2)
          assert_eq(webviews[0].label(), "main")
          assert_eq(webviews[0].title(), "Main")
          assert_eq(webviews[0].width(), 900)
          assert_eq(webviews[0].load_url(), "lepusa://inline/main/index.html")
          assert_eq(webviews[1].label(), "settings")
          assert_eq(webviews[1].title(), "Settings")
          assert_eq(webviews[1].width(), 700)
          assert_eq(webviews[1].height(), 520)
          assert_eq(webviews[1].resizable(), false)
          assert_eq(
            webviews[1].load_url(),
            "lepusa://inline/settings/index.html",
          )
          match plan.first_webview() {
            Ok(first) => assert_eq(first.label(), "main")
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid multi-window macOS run plan")
      }
    Err(_) => abort("unexpected invalid multi-window macOS runtime")
  }
}

///|
test "macos backend dry run does not enter native loop" {
  match runtime(test_host()) {
    Ok(runtime) =>
      match run(runtime) {
        Ok(result) => {
          assert_true(result.status() is MacOSPrepared)
          match result.plan().first_webview() {
            Ok(webview) =>
              assert_eq(webview.load_url(), "lepusa://inline/main/index.html")
            Err(problem) => abort(problem)
          }
          assert_true(
            result.plan().webviews()[0]
            .initialization_script()
            .contains("__lepusaInvoke"),
          )
        }
        Err(_) => abort("unexpected invalid macOS dry run")
      }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos backend prepares bundled runtime manifest" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/Example.app/Contents/Resources/lepusa/runtime.json",
      bundled_macos_manifest(),
    ) {
    Ok(manifest) =>
      match prepare_bundled_run(manifest) {
        Ok(plan) => {
          let webviews = plan.webviews()
          assert_eq(webviews.length(), 1)
          let webview = webviews[0]
          assert_eq(webview.title(), "Bundled App")
          assert_eq(webview.url(), "lepusa://rabbita/main/index.html")
          assert_eq(webview.load_url(), "lepusa://rabbita/main/index.html")
          assert_eq(webview.asset_protocol(), "lepusa")
          assert_true(
            webview.initialization_script().contains("webkit.messageHandlers"),
          )
          assert_true(
            webview.initialization_script().contains("__lepusaInvokeResponse"),
          )
          assert_true(webview.initialization_script().contains("bridge ready"))
          assert_eq(webview.width(), 900)
          assert_eq(webview.height(), 640)
          assert_eq(webview.resizable(), false)
          let execution = plan.execution()
          assert_eq(execution.startup_operations().length(), 2)
          assert_true(
            execution.startup_operations()[0].contains(
              "\"kind\":\"start-service\"",
            ),
          )
          assert_true(
            execution.startup_operations()[1].contains("\"name\":\"boot\""),
          )
          let lifecycle_steps = execution.lifecycle_steps()
          assert_eq(lifecycle_steps.length(), 1)
          assert_true(
            lifecycle_steps[0]
            .event_json()
            .contains("\"kind\":\"app-will-exit\""),
          )
          assert_true(lifecycle_steps[0].operations()[0].contains("flush"))
          let bridge = plan.bridge()
          let sync_routes = bridge.sync_command_routes()
          assert_eq(sync_routes.length(), 1)
          assert_eq(sync_routes[0], "log.write")
          let async_routes = bridge.async_command_routes()
          assert_eq(async_routes.length(), 1)
          assert_eq(async_routes[0], "fs.writeText")
          assert_true(bridge.requires_async_dispatch())
        }
        Err(_) => abort("unexpected invalid bundled macOS plan")
      }
    Err(problem) => abort(problem)
  }
}

///|
async test "macos bridge dispatch returns response callback script" {
  match runtime(bridge_test_host()) {
    Ok(runtime) => {
      let message = "{\"id\":\"42\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}"
      match dispatch_bridge_message(runtime, message) {
        Ok(dispatch) => {
          assert_eq(dispatch.window_label(), "main")
          assert_eq(dispatch.response_hook(), "__lepusaInvokeResponse")
          assert_eq(dispatch.message(), message)
          assert_true(dispatch.response_json().contains("\"id\":\"42\""))
          assert_true(
            dispatch
            .response_json()
            .contains("\"payload\":\"{\\\"seen\\\":true}\""),
          )
          assert_true(
            dispatch
            .evaluation_script()
            .contains("globalThis[\"__lepusaInvokeResponse\"]"),
          )
          assert_true(dispatch.evaluation_script().contains("\"id\":\"42\""))
        }
        Err(_) => abort("unexpected bridge dispatch failure")
      }
    }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
async test "macos bridge prepares async messages before dispatch" {
  match runtime(async_bridge_test_host()) {
    Ok(runtime) => {
      let message = "{\"id\":\"44\",\"window_label\":\"main\",\"plugin\":\"fs\",\"command\":\"readText\",\"payload\":\"true\"}"
      match prepare_bridge_message(runtime, message) {
        Ok(prepared) => {
          assert_eq(prepared.window_label(), "main")
          assert_eq(prepared.response_hook(), "__lepusaInvokeResponse")
          assert_eq(prepared.message(), message)
          let dispatch = prepared.dispatch(runtime)
          assert_eq(dispatch.window_label(), "main")
          assert_eq(dispatch.response_hook(), "__lepusaInvokeResponse")
          assert_true(dispatch.response_json().contains("\"id\":\"44\""))
          assert_true(
            dispatch
            .response_json()
            .contains("\"payload\":\"{\\\"read\\\":true}\""),
          )
          assert_true(
            dispatch
            .evaluation_script()
            .contains("globalThis[\"__lepusaInvokeResponse\"]"),
          )
        }
        Err(_) => abort("unexpected bridge prepare failure")
      }
    }
    Err(_) => abort("unexpected invalid async macOS native runtime")
  }
}

///|
fn bundled_macos_manifest() -> String {
  (
    #|{
    #|  "identifier": "dev.vectie.bundle",
    #|  "productName": "Bundled App",
    #|  "target": "macos",
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "macos",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Bundled App",
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "width": 900,
    #|      "height": 640,
    #|      "resizable": false,
    #|      "nativeHook": "__lepusaInvoke",
    #|      "initializationScripts": ["console.log(\"bridge ready\")"]
    #|    }],
    #|    "protocolMappings": [
    #|      { "windowLabel": "main", "scheme": "lepusa", "root": "memory:main" }
    #|    ],
    #|    "virtualFiles": [
    #|      {
    #|        "windowLabel": "main",
    #|        "path": "index.html",
    #|        "mimeType": "text/html",
    #|        "content": "<main>bundled</main>"
    #|      }
    #|    ],
    #|    "localServices": [
    #|      {
    #|        "name": "api",
    #|        "url": "http://127.0.0.1:4317/",
    #|        "readinessUrl": "http://127.0.0.1:4317/ready",
    #|        "command": ["moon", "run", "cmd/server"]
    #|      }
    #|    ],
    #|    "startupActions": [{ "kind": "effect", "name": "boot" }],
    #|    "lifecycleHooks": [
    #|      {
    #|        "event": { "kind": "app-will-exit" },
    #|        "actions": [{ "kind": "effect", "name": "flush" }]
    #|      }
    #|    ],
    #|    "registeredRoutes": ["log.write", "fs.writeText"]
    #|  }
    #|}
  )
}

///|
async test "macos bridge dispatch reports missing window" {
  match runtime(bridge_test_host()) {
    Ok(runtime) => {
      let message = "{\"id\":\"43\",\"window_label\":\"other\",\"plugin\":\"core\",\"command\":\"invoke\"}"
      match dispatch_bridge_message(runtime, message) {
        Ok(_) => abort("unexpected bridge dispatch success")
        Err(problems) =>
          assert_eq(problems[0], "macOS bridge window not found: other")
      }
    }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}
