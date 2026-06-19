///|
test "bundled runtime manifest summarizes launch data" {
  let manifest = sample_bundled_manifest()
  match BundledRuntimeManifest::parse("/app/lepusa/runtime.json", manifest) {
    Ok(runtime) => {
      assert_eq(runtime.bundle_root(), "/app")
      let summary = runtime.summary()
      assert_true(summary.contains("identifier: dev.vectie.runtime"))
      assert_true(summary.contains("product: Runtime App"))
      assert_true(summary.contains("target: linux"))
      assert_true(
        summary.contains("first-window-url: lepusa://rabbita/main/index.html"),
      )
      assert_true(summary.contains("local-services: 1"))
      assert_true(summary.contains("service-supervisor: true"))
      assert_true(summary.contains("service-start-order: api"))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest exposes service plan" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) =>
      match runtime.service_plan() {
        Ok(plan) => {
          assert_eq(plan.services().length(), 1)
          assert_eq(plan.service_names()[0], "api")
          assert_eq(plan.startup_services().length(), 1)
          assert_eq(plan.startup_service_names()[0], "api")
          assert_true(plan.requires_supervisor())
          assert_true(plan.to_json().contains("\"requiresSupervisor\":true"))
        }
        Err(problem) => abort(problem)
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest builds target-aware run plan" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      assert_eq(runtime.target(), "linux")
      assert_eq(runtime.runtime_backend(), "headless")
      match runtime.run() {
        Ok(result) => {
          assert_true(result.status() is BundledPrepared)
          let plan = result.plan()
          assert_eq(plan.target(), "linux")
          assert_eq(plan.backend(), "linux")
          assert_eq(plan.webview_engine(), "WebKitGTK")
          assert_eq(plan.webviews().length(), 1)
          assert_true(plan.first_webview() is Some(_))
          assert_eq(plan.service_plan().startup_service_names()[0], "api")
          assert_eq(plan.startup_operation_count(), 2)
          assert_eq(plan.lifecycle_step_count(), 2)
          assert_eq(plan.sync_route_count(), 1)
          assert_eq(plan.async_route_count(), 0)
        }
        Err(problem) => abort(problem)
      }
      match runtime.run(mode=BundledOpenWindow) {
        Ok(result) =>
          match result.status() {
            BundledLaunchUnsupported(message) =>
              assert_true(message.contains("WebKitGTK launch loop"))
            _ => abort("unexpected bundled launch status")
          }
        Err(problem) => abort(problem)
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime service plan validates service shape" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "localServices": [
    #|      { "name": "api", "command": ["moon", "run", "cmd/server"] }
    #|    ]
    #|  }
    #|}
  match BundledRuntimeManifest::parse("runtime.json", manifest) {
    Ok(runtime) =>
      match runtime.service_plan() {
        Ok(_) => abort("unexpected valid service plan")
        Err(problem) =>
          assert_eq(problem, "local service readiness url is required")
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest exposes first webview" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) =>
      match runtime.first_webview() {
        Ok(webview) => {
          assert_eq(webview.label(), "main")
          assert_eq(webview.title(), "Runtime App")
          assert_eq(webview.url(), "lepusa://rabbita/main/index.html")
          assert_eq(webview.width(), 1000)
          assert_eq(webview.height(), 720)
          assert_eq(webview.resizable(), true)
          assert_eq(webview.native_hook(), "__lepusaInvoke")
          assert_eq(webview.initialization_scripts().length(), 1)
          assert_eq(runtime.webview_count(), 1)
        }
        Err(problem) => abort(problem)
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest emits bootstrap json" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      let bootstrap = runtime.bootstrap_json()
      assert_true(
        bootstrap.contains("\"manifestPath\":\"/app/lepusa/runtime.json\""),
      )
      assert_true(bootstrap.contains("\"bundleRoot\":\"/app\""))
      assert_true(bootstrap.contains("\"identifier\":\"dev.vectie.runtime\""))
      assert_true(bootstrap.contains("\"productName\":\"Runtime App\""))
      assert_true(bootstrap.contains("\"target\":\"linux\""))
      assert_true(bootstrap.contains("\"runtime\":{"))
      assert_true(bootstrap.contains("\"webviews\""))
      assert_true(bootstrap.contains("\"startupActions\""))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest resolves protocol assets" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      let bridge = runtime.resolve_asset_json("lepusa://runtime/bridge.js")
      assert_true(bridge.contains("\"kind\":\"virtual\""))
      assert_true(bridge.contains("console.log"))
      let virtual_asset = runtime.resolve_asset_json(
        "lepusa://rabbita/main/index.html?v=1#top",
      )
      assert_true(virtual_asset.contains("\"mimeType\":\"text/html\""))
      assert_true(virtual_asset.contains("<main></main>"))
      let local_asset = runtime.resolve_asset_json(
        "lepusa://local/static/app.css",
      )
      assert_true(local_asset.contains("\"path\":\"public/app.css\""))
      let packaged = runtime.resolve_asset_json(
        "lepusa://packaged/packaged/app.css",
      )
      assert_true(
        packaged.contains("\"path\":\"/app/lepusa/assets/packaged/app.css\""),
      )
      let unsafe_asset = runtime.resolve_asset_json(
        "lepusa://rabbita/main/../secret.txt",
      )
      assert_true(unsafe_asset.contains("\"ok\":false"))
      assert_true(unsafe_asset.contains("unsafe asset path"))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest selects lifecycle actions" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      let startup = runtime.lifecycle_json(BundledLifecycleEvent::app_started())
      assert_true(startup.contains("\"name\":\"api\""))
      assert_true(startup.contains("\"name\":\"boot\""))
      let shutdown = runtime.lifecycle_json(
        BundledLifecycleEvent::app_will_exit(),
      )
      assert_true(shutdown.contains("\"name\":\"flush\""))
      assert_false(shutdown.contains("\"name\":\"api\""))
      match BundledLifecycleEvent::window_close_requested("main") {
        Ok(event) => {
          let close = runtime.lifecycle_json(event)
          assert_true(close.contains("\"label\":\"main\""))
          assert_true(close.contains("\"name\":\"closing\""))
        }
        Err(problem) => abort(problem)
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest validates input shape" {
  assert_true(
    BundledRuntimeManifest::parse("runtime.json", "{}")
    is Err("runtime object is required"),
  )
  let invalid = BundledRuntimeManifest::parse("runtime.json", "{")
  assert_true(invalid is Err(_))
  assert_true(
    BundledLifecycleEvent::window_closed("")
    is Err("lifecycle window is required"),
  )
}

///|
async test "bundled runtime preserves official plugin state" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [
    #|      { "label": "main", "allowedRoutes": ["store.set", "store.get"] }
    #|    ],
    #|    "filesystemScopes": [],
    #|    "registeredRoutes": ["store.set", "store.get"]
    #|  }
    #|}
  match BundledRuntimeManifest::parse("runtime.json", manifest) {
    Ok(manifest) => {
      let runtime = BundledRuntime::new(manifest)
      let set = runtime.dispatch_json_async(
        id="set",
        window_label="main",
        route="store.set",
        payload="{\"key\":\"theme\",\"value\":\"dark\"}",
      )
      assert_true(set.contains("\"id\":\"set\""))
      let get = runtime.dispatch_json_async(
        id="get",
        window_label="main",
        route="store.get",
        payload="{\"key\":\"theme\"}",
      )
      assert_true(get.contains("\\\"value\\\":\\\"dark\\\""))
      assert_true(get.contains("\\\"found\\\":true"))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime dispatches sync official plugins" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [
    #|      { "label": "main", "allowedRoutes": ["log.write", "fs.writeText"] }
    #|    ],
    #|    "filesystemScopes": [],
    #|    "registeredRoutes": ["log.write", "fs.writeText"]
    #|  }
    #|}
  match BundledRuntimeManifest::parse("runtime.json", manifest) {
    Ok(manifest) => {
      let sync_routes = manifest.registered_sync_routes()
      assert_eq(sync_routes.length(), 1)
      assert_eq(sync_routes[0], "log.write")
      let async_routes = manifest.registered_async_routes()
      assert_eq(async_routes.length(), 1)
      assert_eq(async_routes[0], "fs.writeText")
      let log = manifest.dispatch_json(
        id="log",
        window_label="main",
        route="log.write",
        payload="{\"message\":\"ready\"}",
      )
      assert_true(log.contains("\"id\":\"log\""))
      assert_true(log.contains("\\\"message\\\":\\\"ready\\\""))
      let async_only = manifest.dispatch_json(
        id="write",
        window_label="main",
        route="fs.writeText",
        payload="{\"scope\":\"data\",\"path\":\"note.txt\",\"content\":\"hello\"}",
      )
      assert_true(
        async_only.contains("command requires async dispatch: fs.writeText"),
      )
    }
    Err(problem) => abort(problem)
  }
}

///|
fn sample_bundled_manifest() -> String {
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
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "initializationScripts": ["console.log(\"bridge\")"]
    #|    }],
    #|    "protocolMappings": [
    #|      { "windowLabel": "main", "scheme": "lepusa", "root": "memory:main" },
    #|      { "windowLabel": "static", "scheme": "lepusa", "root": "public" },
    #|      { "windowLabel": "packaged", "scheme": "lepusa", "root": "package:lepusa/assets/packaged" }
    #|    ],
    #|    "virtualFiles": [
    #|      {
    #|        "windowLabel": "main",
    #|        "path": "index.html",
    #|        "mimeType": "text/html",
    #|        "content": "<main></main>"
    #|      }
    #|    ],
    #|    "localServices": [
    #|      {
    #|        "name": "api",
    #|        "command": ["moon", "run", "cmd/server"],
    #|        "readinessUrl": "http://127.0.0.1:4317/ready"
    #|      }
    #|    ],
    #|    "startupActions": [
    #|      { "kind": "effect", "name": "boot" }
    #|    ],
    #|    "lifecycleHooks": [
    #|      {
    #|        "event": { "kind": "app-will-exit" },
    #|        "actions": [{ "kind": "effect", "name": "flush" }]
    #|      },
    #|      {
    #|        "event": { "kind": "window-close-requested", "label": "main" },
    #|        "actions": [{ "kind": "emit", "event": { "name": "closing" } }]
    #|      }
    #|    ],
    #|    "commandRoutes": ["log.write"],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  )
}
