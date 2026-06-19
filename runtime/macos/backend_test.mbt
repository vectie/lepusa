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
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid runtime plan")
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
          assert_eq(plan.title(), "macOS")
          assert_eq(plan.url(), "lepusa://inline/main/index.html")
          assert_true(plan.load_url().has_prefix("data:text/html;base64,"))
          assert_false(plan.load_url().contains("lepusa://"))
          assert_true(
            plan.initialization_script().contains("webkit.messageHandlers"),
          )
          assert_true(
            plan.initialization_script().contains("__lepusaInvokeResponse"),
          )
          assert_true(plan.initialization_script().contains("windowLabel"))
          assert_eq(plan.width(), 1000)
          assert_eq(plan.height(), 720)
          assert_eq(plan.webviews(), 1)
        }
        Err(_) => abort("unexpected invalid macOS run plan")
      }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos backend dry run does not enter native loop" {
  match runtime(test_host()) {
    Ok(runtime) =>
      match run(runtime) {
        Ok(result) => {
          assert_true(result.status() is MacOSPrepared)
          assert_true(
            result.plan().load_url().has_prefix("data:text/html;base64,"),
          )
          assert_true(
            result.plan().initialization_script().contains("__lepusaInvoke"),
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
          assert_eq(plan.title(), "Bundled App")
          assert_eq(plan.url(), "lepusa://rabbita/main/index.html")
          assert_true(plan.load_url().has_prefix("data:text/html;base64,"))
          assert_true(
            plan.initialization_script().contains("webkit.messageHandlers"),
          )
          assert_true(
            plan.initialization_script().contains("__lepusaInvokeResponse"),
          )
          assert_true(plan.initialization_script().contains("bridge ready"))
          assert_eq(plan.width(), 900)
          assert_eq(plan.height(), 640)
          assert_eq(plan.resizable(), false)
          assert_eq(plan.webviews(), 1)
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
    #|    "registeredRoutes": ["log.write"]
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
