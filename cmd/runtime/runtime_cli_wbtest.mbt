///|
test "runtime cli summarizes bundled manifest envelope" {
  let manifest =
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "linux",
    #|  "runtime": {
    #|    "backend": "headless",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{ "url": "lepusa://rabbita/main/index.html" }],
    #|    "localServices": [{ "name": "api" }],
    #|    "startupActions": [{ "kind": "event" }],
    #|    "lifecycleHooks": [{ "event": "app-started" }],
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
  assert_true(result.output.contains("backend: headless"))
  assert_true(result.output.contains("bridge: lepusa://runtime/bridge.js"))
  assert_true(result.output.contains("webviews: 1"))
  assert_true(
    result.output.contains("first-window-url: lepusa://rabbita/main/index.html"),
  )
  assert_true(result.output.contains("local-services: 1"))
  assert_true(result.output.contains("startup-actions: 1"))
  assert_true(result.output.contains("lifecycle-hooks: 1"))
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
