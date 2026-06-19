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
    #|      { "name": "api", "command": ["moon", "run", "cmd/server"] }
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
