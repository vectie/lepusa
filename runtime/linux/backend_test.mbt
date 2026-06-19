///|
fn test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="Linux", source=@lepusa.Source::html("<main>Linux</main>"))
    .with_startup(@lepusa.Cmd::effect("boot"))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => @runtime.RuntimeHost::new(plan)
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "linux backend exposes webkitgtk descriptor" {
  let descriptor = backend()
  assert_eq(descriptor.name(), "linux")
  assert_eq(descriptor.webview_engine(), "WebKitGTK")
}

///|
test "linux backend reports host availability" {
  match detect() {
    Ok(descriptor) => assert_eq(descriptor.name(), "linux")
    Err(problem) =>
      assert_eq(problem, "Linux WebKitGTK backend is not available")
  }
}

///|
test "linux backend lowers runtime host to native runner contract" {
  match backend().runner_plan(test_host()) {
    Ok(plan) => {
      assert_eq(plan.backend_name(), "linux")
      assert_eq(plan.webview_engine(), "WebKitGTK")
      assert_eq(plan.webviews().length(), 1)
      assert_true(plan.startup_operations()[0] is NativeRunEffect("boot"))
      assert_true(plan.bootstrap_json().contains("\"nativeBackend\":\"linux\""))
    }
    Err(_) => abort("unexpected invalid Linux runner plan")
  }
}

///|
test "linux backend exposes native runtime facade" {
  match runtime(test_host()) {
    Ok(runtime) => {
      assert_eq(runtime.backend().name(), "linux")
      assert_true(
        runtime.bootstrap_json().contains("\"nativeBackend\":\"linux\""),
      )
    }
    Err(_) => abort("unexpected invalid Linux native runtime")
  }
}

///|
test "linux backend prepares run plan and reports unsupported launch" {
  match runtime(test_host()) {
    Ok(runtime) => {
      match run(runtime) {
        Ok(result) => {
          assert_true(result.status() is RunPrepared)
          assert_eq(result.plan().webview_count(), 1)
          assert_eq(
            result.plan().first_webview_url(),
            "lepusa://inline/main/index.html",
          )
          assert_eq(result.plan().startup_operation_count(), 1)
        }
        Err(_) => abort("unexpected invalid Linux dry run")
      }
      match launch(runtime) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(message.contains("WebKitGTK launch loop"))
            _ => abort("unexpected Linux launch status")
          }
        Err(_) => abort("unexpected invalid Linux launch plan")
      }
    }
    Err(_) => abort("unexpected invalid Linux native runtime")
  }
}

///|
test "linux backend prepares bundled runtime contract" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      linux_bundled_manifest(),
    ) {
    Ok(manifest) => {
      match prepare_bundled_run(manifest) {
        Ok(plan) => {
          assert_eq(plan.webview_count(), 1)
          assert_eq(
            plan.first_webview_url(),
            "lepusa://rabbita/main/index.html",
          )
          assert_eq(plan.startup_operation_count(), 2)
          assert_eq(plan.lifecycle_step_count(), 1)
          assert_true(
            plan.bootstrap_json().contains("\"nativeBackend\":\"linux\""),
          )
          assert_true(
            plan.bootstrap_json().contains("\"webviewEngine\":\"WebKitGTK\""),
          )
        }
        Err(_) => abort("unexpected invalid Linux bundled run plan")
      }
      match run_bundled(manifest) {
        Ok(result) => {
          assert_true(result.status() is RunPrepared)
          assert_eq(result.report().target(), "linux")
          assert_eq(result.report().backend(), "linux")
          assert_eq(result.report().engine(), "WebKitGTK")
          assert_eq(result.report().startup_operations(), 2)
        }
        Err(_) => abort("unexpected invalid Linux bundled dry run")
      }
      match launch_bundled(manifest) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(message.contains("WebKitGTK launch loop"))
            _ => abort("unexpected Linux bundled launch status")
          }
        Err(_) => abort("unexpected invalid Linux bundled launch plan")
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "linux backend rejects mismatched bundled target" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      linux_bundled_manifest().replace_all(
        old="\"target\": \"linux\"",
        new="\"target\": \"windows\"",
      ),
    ) {
    Ok(manifest) =>
      match prepare_bundled_run(manifest) {
        Ok(_) => abort("unexpected Linux bundled target match")
        Err(problems) =>
          assert_eq(
            problems[0],
            "Linux bundled run requires target linux: windows",
          )
      }
    Err(problem) => abort(problem)
  }
}

///|
fn linux_bundled_manifest() -> String {
  (
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "linux",
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "headless",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Runtime App",
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "allowedRoutes": ["log.write"]
    #|    }],
    #|    "localServices": [{
    #|      "name": "api",
    #|      "command": ["moon", "run", "cmd/server"],
    #|      "readinessUrl": "http://127.0.0.1:4317/ready"
    #|    }],
    #|    "startupActions": [{ "kind": "effect", "name": "boot" }],
    #|    "lifecycleHooks": [
    #|      {
    #|        "event": { "kind": "app-will-exit" },
    #|        "actions": [{ "kind": "effect", "name": "flush" }]
    #|      }
    #|    ],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  )
}
