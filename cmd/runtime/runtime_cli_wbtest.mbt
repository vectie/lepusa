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
}
