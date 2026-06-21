///|
test "bundled runtime resolves plugin lifecycle plans" {
  let manifest_text =
    #|{
    #|  "runtime": {
    #|    "lifecycleHooks": [{
    #|      "event": { "kind": "plugin-setup", "plugin": "log" },
    #|      "actions": [{ "kind": "effect", "name": "log.setup" }]
    #|    }]
    #|  },
    #|  "bundle": {}
    #|}
    #|
  match BundledRuntimeManifest::parse("runtime.json", manifest_text) {
    Ok(manifest) => {
      match manifest.lifecycle_plans() {
        Ok(plans) => {
          assert_eq(plans.length(), 1)
          assert_eq(plans[0].event().kind(), "plugin-setup")
          assert_eq(plans[0].event().plugin(), "log")
        }
        Err(problem) => abort(problem)
      }
      match BundledLifecycleEvent::plugin_setup("log") {
        Ok(event) => {
          let json = manifest.lifecycle_json(event)
          assert_true(json.contains("\"kind\":\"plugin-setup\""))
          assert_true(json.contains("\"plugin\":\"log\""))
          assert_true(json.contains("\"name\":\"log.setup\""))
        }
        Err(problem) => abort(problem)
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled plugin lifecycle events require plugin names" {
  match BundledLifecycleEvent::plugin_ready("") {
    Ok(_) => abort("unexpected valid plugin lifecycle event")
    Err(problem) => assert_eq(problem, "lifecycle plugin is required")
  }
}
