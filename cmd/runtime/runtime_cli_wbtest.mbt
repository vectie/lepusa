///|
test "runtime cli summarizes bundled manifest envelope" {
  let manifest =
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "linux",
    #|  "artifacts": [
    #|    { "kind": "portable-directory", "path": "dist/runtime-app" }
    #|  ],
    #|  "resources": [
    #|    { "kind": "runtime-manifest", "path": "lepusa/runtime.json" }
    #|  ],
    #|  "signing": {
    #|    "identity": "Developer ID",
    #|    "notarize": false
    #|  },
    #|  "signingPrerequisites": ["codesign identity Developer ID"],
    #|  "signingSteps": [{
    #|    "name": "sign executable",
    #|    "tool": "codesign",
    #|    "command": "codesign --sign Developer ID runtime-app"
    #|  }],
    #|  "runtime": {
    #|    "backend": "headless",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{ "url": "lepusa://rabbita/main/index.html" }],
    #|    "localServices": [{
    #|      "name": "api",
    #|      "command": ["moon", "run", "cmd/server"],
    #|      "readinessUrl": "http://127.0.0.1:4317/ready"
    #|    }],
    #|    "startupActions": [{ "kind": "event" }],
    #|    "lifecycleHooks": [{ "event": "app-started" }],
    #|    "capabilities": [{
    #|      "name": "main-log",
    #|      "windows": ["main"],
    #|      "permissions": ["custom:log.write"]
    #|    }],
    #|    "commandRoutes": ["log.write"],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  let result = render_runtime_manifest_text("lepusa/runtime.json", manifest)
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa runtime"))
  assert_true(result.output.contains("identifier: dev.vectie.runtime"))
  assert_true(result.output.contains("product: Runtime App"))
  assert_true(result.output.contains("target: linux"))
  assert_true(result.output.contains("artifacts: 1"))
  assert_true(result.output.contains("resources: 1"))
  assert_true(result.output.contains("signing-configured: true"))
  assert_true(result.output.contains("signing-prerequisites: 1"))
  assert_true(result.output.contains("signing-steps: 1"))
  assert_true(result.output.contains("backend: headless"))
  assert_true(result.output.contains("bridge: lepusa://runtime/bridge.js"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("local-services: 1"))
  assert_true(result.output.contains("service-supervisor: true"))
  assert_true(result.output.contains("service-start-order: api"))
  assert_true(result.output.contains("startup-actions: 1"))
  assert_true(result.output.contains("lifecycle-hooks: 1"))
  assert_true(result.output.contains("capabilities: 1"))
  assert_true(result.output.contains("command-routes: 1"))
  assert_true(result.output.contains("registered-routes: 1"))
}

///|
test "runtime cli validates manifest shape" {
  let missing = render_runtime_manifest_text("runtime.json", "{}")
  assert_eq(missing.exit_code, 1)
  assert_true(missing.output.contains("runtime object is required"))
  let invalid = render_runtime_manifest_text("runtime.json", "{")
  assert_eq(invalid.exit_code, 1)
  assert_true(invalid.output.contains("invalid runtime json"))
}

///|
test "runtime cli renders bundled bootstrap json" {
  let manifest =
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "linux",
    #|  "runtime": {
    #|    "backend": "headless",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{ "url": "lepusa://rabbita/main/index.html" }],
    #|    "localServices": [],
    #|    "startupActions": [],
    #|    "lifecycleHooks": [],
    #|    "capabilities": [{
    #|      "name": "main-log",
    #|      "windows": ["main"],
    #|      "permissions": ["custom:log.write"]
    #|    }],
    #|    "commandRoutes": ["log.write"],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  let result = render_runtime_bootstrap_text(
    "/app/lepusa/runtime.json", manifest,
  )
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\"bundleRoot\":\"/app\""))
  assert_true(result.output.contains("\"identifier\":\"dev.vectie.runtime\""))
  assert_true(result.output.contains("\"nativeBackend\":\"linux\""))
  assert_true(result.output.contains("\"webviewEngine\":\"WebKitGTK\""))
  assert_true(result.output.contains("\"runtime\":{"))
  assert_true(result.output.contains("\"webviewSpecs\""))
  assert_true(result.output.contains("\"startupOperations\""))
  assert_true(result.output.contains("\"lifecycleOperations\""))
  assert_true(result.output.contains("\"capabilities\""))
  assert_true(result.output.contains("\"permissions\":[\"custom:log.write\"]"))
  assert_true(result.output.contains("\"bridgeRoutes\""))
  assert_true(result.output.contains("\"registeredRoutes\":[\"log.write\"]"))
}

///|
test "runtime cli rejects invalid bundled bootstrap plan" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [{ "url": "lepusa://rabbita/main/index.html" }],
    #|    "lifecycleHooks": [
    #|      { "event": { "kind": "unknown" }, "actions": [] }
    #|    ]
    #|  }
    #|}
  let result = render_runtime_bootstrap_text(
    "/app/lepusa/runtime.json", manifest,
  )
  assert_eq(result.exit_code, 1)
  assert_true(result.output.contains("unsupported runtime lifecycle event"))
}

///|
test "runtime cli dry-runs bundled macos launch" {
  let manifest =
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "macos",
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "macos",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Runtime App",
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "initializationScripts": ["console.log(\"bridge\")"]
    #|    }],
    #|    "protocolMappings": [
    #|      { "windowLabel": "main", "scheme": "lepusa", "root": "memory:main" }
    #|    ],
    #|    "virtualFiles": [
    #|      {
    #|        "windowLabel": "main",
    #|        "path": "index.html",
    #|        "mimeType": "text/html",
    #|        "content": "<main></main>"
    #|      }
    #|    ],
    #|    "localServices": [{
    #|      "name": "api",
    #|      "command": ["moon", "run", "cmd/server"],
    #|      "readinessUrl": "http://127.0.0.1:4317/ready"
    #|    }],
    #|    "registeredRoutes": []
    #|  }
    #|}
  let result = render_runtime_run_text(
    "/Runtime.app/Contents/Resources/lepusa/runtime.json", manifest,
  )
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("mode: dry-run"))
  assert_true(result.output.contains("backend: macos"))
  assert_true(result.output.contains("engine: WKWebView"))
  assert_true(result.output.contains("status: prepared"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(
    result.output.contains("load-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("local-services: 1"))
  assert_true(result.output.contains("service-supervisor: true"))
  assert_true(result.output.contains("service-start-order: api"))
  assert_true(result.output.contains("startup-operations: 1"))
  assert_true(result.output.contains("lifecycle-steps: 0"))
  assert_true(result.output.contains("bridge-sync-routes: 0"))
  assert_true(result.output.contains("bridge-async-routes: 0"))
}

///|
test "runtime cli dry-runs bundled linux manifest by target" {
  let manifest =
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
    #|      "url": "lepusa://rabbita/main/index.html"
    #|    }],
    #|    "localServices": [{
    #|      "name": "api",
    #|      "command": ["moon", "run", "cmd/server"],
    #|      "readinessUrl": "http://127.0.0.1:4317/ready"
    #|    }],
    #|    "startupActions": [{ "kind": "effect", "name": "boot" }],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  let dry_run = render_runtime_run_text("/app/lepusa/runtime.json", manifest)
  assert_eq(dry_run.exit_code, 0)
  assert_true(dry_run.output.contains("target: linux"))
  assert_true(dry_run.output.contains("backend: linux"))
  assert_true(dry_run.output.contains("engine: WebKitGTK"))
  assert_true(dry_run.output.contains("status: prepared"))
  assert_true(dry_run.output.contains("bridge: lepusa://runtime/bridge.js"))
  assert_true(dry_run.output.contains("startup-operations: 2"))
  assert_true(dry_run.output.contains("service-start-order: api"))
  let launch = render_runtime_run_text(
    "/app/lepusa/runtime.json",
    manifest,
    launch=true,
  )
  assert_eq(launch.exit_code, 0)
  assert_true(launch.output.contains("mode: launch"))
  assert_true(launch.output.contains("status: unsupported"))
  assert_true(launch.output.contains("engine: WebKitGTK"))
}

///|
test "runtime cli dry-runs bundled windows manifest by target" {
  let manifest =
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "windows",
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "headless",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Runtime App",
    #|      "url": "lepusa://rabbita/main/index.html"
    #|    }],
    #|    "localServices": [],
    #|    "startupActions": [{ "kind": "effect", "name": "boot" }],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  let dry_run = render_runtime_run_text("/app/lepusa/runtime.json", manifest)
  assert_eq(dry_run.exit_code, 0)
  assert_true(dry_run.output.contains("target: windows"))
  assert_true(dry_run.output.contains("backend: windows"))
  assert_true(dry_run.output.contains("engine: WebView2"))
  assert_true(dry_run.output.contains("status: prepared"))
  assert_true(dry_run.output.contains("bridge: lepusa://runtime/bridge.js"))
  assert_true(dry_run.output.contains("startup-operations: 1"))
  let launch = render_runtime_run_text(
    "/app/lepusa/runtime.json",
    manifest,
    launch=true,
  )
  assert_eq(launch.exit_code, 0)
  assert_true(launch.output.contains("mode: launch"))
  assert_true(launch.output.contains("status: unsupported"))
  assert_true(launch.output.contains("engine: WebView2"))
}

///|
test "runtime cli resolves bundled runtime assets" {
  let manifest =
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
    #|    "localServices": [],
    #|    "startupActions": [],
    #|    "lifecycleHooks": [],
    #|    "commandRoutes": [],
    #|    "registeredRoutes": []
    #|  }
    #|}
  let bridge = render_runtime_asset_text(
    "/app/lepusa/runtime.json", manifest, "lepusa://runtime/bridge.js",
  )
  assert_eq(bridge.exit_code, 0)
  assert_true(bridge.output.contains("\"kind\":\"virtual\""))
  assert_true(bridge.output.contains("console.log"))
  let virtual_asset = render_runtime_asset_text(
    "/app/lepusa/runtime.json", manifest, "lepusa://rabbita/main/index.html?v=1#top",
  )
  assert_true(virtual_asset.output.contains("\"mimeType\":\"text/html\""))
  assert_true(virtual_asset.output.contains("<main></main>"))
  let local_asset = render_runtime_asset_text(
    "/app/lepusa/runtime.json", manifest, "lepusa://local/static/app.css",
  )
  assert_true(local_asset.output.contains("\"kind\":\"local-file\""))
  assert_true(local_asset.output.contains("\"path\":\"public/app.css\""))
  let packaged = render_runtime_asset_text(
    "/app/lepusa/runtime.json", manifest, "lepusa://packaged/packaged/app.css",
  )
  assert_true(packaged.output.contains("\"kind\":\"packaged-file\""))
  assert_true(
    packaged.output.contains("\"path\":\"/app/lepusa/assets/packaged/app.css\""),
  )
  let unsafe_asset = render_runtime_asset_text(
    "/app/lepusa/runtime.json", manifest, "lepusa://rabbita/main/../secret.txt",
  )
  assert_true(unsafe_asset.output.contains("\"ok\":false"))
  assert_true(unsafe_asset.output.contains("unsafe asset path"))
}

///|
test "runtime cli renders lifecycle actions from bundled manifest" {
  let manifest =
    #|{
    #|  "runtime": {
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
    #|    ]
    #|  }
    #|}
  let startup = render_runtime_lifecycle_text(
    manifest,
    @bundled.BundledLifecycleEvent::app_started(),
  )
  assert_eq(startup.exit_code, 0)
  assert_true(startup.output.contains("\"localServices\""))
  assert_true(startup.output.contains("\"name\":\"api\""))
  assert_true(startup.output.contains("\"name\":\"boot\""))
  let shutdown = render_runtime_lifecycle_text(
    manifest,
    @bundled.BundledLifecycleEvent::app_will_exit(),
  )
  assert_true(shutdown.output.contains("\"name\":\"flush\""))
  assert_false(shutdown.output.contains("\"name\":\"api\""))
  match @bundled.BundledLifecycleEvent::window_close_requested("main") {
    Ok(event) => {
      let close = render_runtime_lifecycle_text(manifest, event)
      assert_true(close.output.contains("\"label\":\"main\""))
      assert_true(close.output.contains("\"name\":\"closing\""))
    }
    Err(problem) => abort(problem)
  }
  let missing_event = match
    @bundled.BundledLifecycleEvent::window_closed("main") {
    Ok(event) => event
    Err(problem) => abort(problem)
  }
  let missing = render_runtime_lifecycle_text(manifest, missing_event)
  assert_true(missing.output.contains("\"actions\":[]"))
}

///|
test "runtime cli validates lifecycle arguments" {
  assert_true(
    runtime_lifecycle_event_arg(["lifecycle"])
    is Err("lifecycle event is required"),
  )
  assert_true(
    runtime_lifecycle_event_arg(["lifecycle", "window-closed"])
    is Err("lifecycle window is required"),
  )
  assert_true(
    runtime_lifecycle_event_arg(["lifecycle", "app-will-exit"]) is Ok(_),
  )
  match runtime_lifecycle_event_arg(["lifecycle", "app-will-exit"]) {
    Ok(event) => assert_eq(event.kind(), "app-will-exit")
    Err(problem) => abort(problem)
  }
}

///|
test "runtime cli parses manifest flag" {
  assert_true(runtime_manifest_arg([]) is Ok("lepusa/runtime.json"))
  assert_true(
    runtime_manifest_arg(["--manifest", "app/runtime.json"])
    is Ok("app/runtime.json"),
  )
  assert_true(
    runtime_manifest_arg(["--manifest"])
    is Err("--manifest requires a file path"),
  )
  assert_true(
    runtime_manifest_path(["asset", "lepusa://rabbita/main/index.html"])
    is Ok("lepusa/runtime.json"),
  )
  assert_true(
    runtime_manifest_path([
      "asset", "lepusa://rabbita/main/index.html", "--manifest", "runtime.json",
    ])
    is Ok("runtime.json"),
  )
}

///|
async test "runtime cli invokes bundled official plugins" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [
    #|      {
    #|        "label": "main",
    #|        "allowedRoutes": ["log.write", "store.set", "store.get"]
    #|      }
    #|    ],
    #|    "filesystemScopes": [],
    #|    "registeredRoutes": ["log.write", "store.set", "store.get"]
    #|  }
    #|}
  let log = render_runtime_invoke_text(
    "lepusa/runtime.json", manifest, "main", "log.write", "{\"message\":\"hello\"}",
  )
  assert_eq(log.exit_code, 0)
  assert_true(log.output.contains("\"id\":\"cli\""))
  assert_true(log.output.contains("\\\"message\\\":\\\"hello\\\""))
  let store_set = render_runtime_invoke_text(
    "lepusa/runtime.json", manifest, "main", "store.set", "{\"key\":\"theme\",\"value\":\"dark\"}",
  )
  assert_true(store_set.output.contains("\\\"key\\\":\\\"theme\\\""))
  let store_get = render_runtime_invoke_text(
    "lepusa/runtime.json", manifest, "main", "store.get", "{\"key\":\"theme\"}",
  )
  assert_true(store_get.output.contains("\\\"found\\\":false"))
}

///|
async test "runtime cli enforces bundled route grants" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [
    #|      { "label": "main", "allowedRoutes": ["log.write"] },
    #|      { "label": "settings", "allowedRoutes": [] }
    #|    ],
    #|    "filesystemScopes": [],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  let denied = render_runtime_invoke_text(
    "lepusa/runtime.json", manifest, "settings", "log.write", "{\"message\":\"hello\"}",
  )
  assert_eq(denied.exit_code, 0)
  assert_true(
    denied.output.contains("\"error\":\"permission denied: log.write\""),
  )
  let unknown = render_runtime_invoke_text(
    "lepusa/runtime.json", manifest, "main", "store.set", "{\"key\":\"theme\",\"value\":\"dark\"}",
  )
  assert_true(
    unknown.output.contains("\"error\":\"unknown command: store.set\""),
  )
}

///|
async test "runtime cli invokes bundled scoped filesystem handlers" {
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-runtime-fs-\{stamp}"
  @fs.mkdir(root, recursive=true, permission=0o755)
  let manifest = [
    "{", "\"runtime\":{", "\"webviews\":[{\"label\":\"main\",\"allowedRoutes\":[\"fs.writeText\",\"fs.readText\"]}],",
    "\"filesystemScopes\":[{\"name\":\"data\",\"root\":\"", root, "\",\"writable\":true}],",
    "\"registeredRoutes\":[\"fs.writeText\",\"fs.readText\"]", "}", "}",
  ].join("")
  let write = render_runtime_invoke_text(
    "lepusa/runtime.json", manifest, "main", "fs.writeText", "{\"scope\":\"data\",\"path\":\"note.txt\",\"content\":\"hello fs\"}",
  )
  assert_eq(write.exit_code, 0)
  assert_true(write.output.contains("\\\"written\\\":true"))
  let read = render_runtime_invoke_text(
    "lepusa/runtime.json", manifest, "main", "fs.readText", "{\"scope\":\"data\",\"path\":\"note.txt\"}",
  )
  assert_true(read.output.contains("\\\"content\\\":\\\"hello fs\\\""))
}

///|
async test "runtime cli invoke ignores manifest flag when payload is omitted" {
  let stamp = @async.now().to_int()
  let root = "/tmp/lepusa-runtime-invoke-flags-\{stamp}"
  @fs.mkdir(root, recursive=true, permission=0o755)
  let manifest_path = root + "/runtime.json"
  @fs.write_file(
    manifest_path,
    (
      #|{
      #|  "runtime": {
      #|    "webviews": [
      #|      { "label": "main", "allowedRoutes": ["store.keys"] }
      #|    ],
      #|    "filesystemScopes": [],
      #|    "registeredRoutes": ["store.keys"]
      #|  }
      #|}
    ),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let result = render_runtime_cli_async([
    "invoke", "main", "store.keys", "--manifest", manifest_path,
  ])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("\\\"keys\\\":[]"))
}
