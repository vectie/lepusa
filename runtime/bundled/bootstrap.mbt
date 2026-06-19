///|
pub struct BundledBootstrapPlan {
  manifest : BundledRuntimeManifest
  run_plan : BundledRunPlan
  startup_operations : Array[String]
  lifecycle_operations : Array[String]
} derive(Debug)

///|
pub fn BundledRuntimeManifest::bootstrap_json(
  self : BundledRuntimeManifest,
) -> String {
  match self.bootstrap_plan() {
    Ok(plan) => plan.to_json()
    Err(problem) =>
      [
        "{",
        "\"manifestPath\":\{self.path.json_string()},",
        "\"bundleRoot\":\{self.bundle_root.json_string()},",
        "\"error\":\{problem.json_string()}",
        "}",
      ].join("")
  }
}

///|
pub fn BundledRuntimeManifest::bootstrap_plan(
  self : BundledRuntimeManifest,
) -> Result[BundledBootstrapPlan, String] {
  match self.run_plan() {
    Err(problem) => Err(problem)
    Ok(run_plan) =>
      Ok({
        manifest: self,
        run_plan,
        startup_operations: self.bundled_startup_operations(),
        lifecycle_operations: match self.bundled_lifecycle_operations() {
          Ok(operations) => operations
          Err(problem) => return Err(problem)
        },
      })
  }
}

///|
pub fn BundledBootstrapPlan::to_json(self : BundledBootstrapPlan) -> String {
  let manifest = self.manifest
  let run_plan = self.run_plan
  [
    "{",
    "\"manifestPath\":\{manifest.path.json_string()},",
    "\"bundleRoot\":\{manifest.bundle_root.json_string()},",
    "\"identifier\":\{optional_string(manifest.bundle, "identifier").unwrap_or("").json_string()},",
    "\"productName\":\{optional_string(manifest.bundle, "productName").unwrap_or("").json_string()},",
    "\"target\":\{run_plan.target().json_string()},",
    "\"nativeBackend\":\{run_plan.backend().json_string()},",
    "\"webviewEngine\":\{run_plan.webview_engine().json_string()},",
    "\"bridgeUrl\":\{run_plan.bridge_url().json_string()},",
    "\"runtime\":\{json_object_string(manifest.runtime)},",
    "\"webviewSpecs\":[\{run_plan.webviews().map(fn(webview) { webview.bootstrap_json() }).join(",")}],",
    "\"startupOperations\":[\{self.startup_operations.join(",")}],",
    "\"lifecycleOperations\":[\{self.lifecycle_operations.join(",")}],",
    "\"bridgeRoutes\":{",
    "\"sync\":[\{manifest.registered_sync_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"async\":[\{manifest.registered_async_routes().map(fn(route) { route.json_string() }).join(",")}]",
    "}",
    "}",
  ].join("")
}

///|
pub fn BundledBootstrapPlan::run_plan(
  self : BundledBootstrapPlan,
) -> BundledRunPlan {
  self.run_plan
}

///|
pub fn BundledBootstrapPlan::startup_operations(
  self : BundledBootstrapPlan,
) -> Array[String] {
  self.startup_operations.copy()
}

///|
pub fn BundledBootstrapPlan::lifecycle_operations(
  self : BundledBootstrapPlan,
) -> Array[String] {
  self.lifecycle_operations.copy()
}

///|
fn BundledWebView::bootstrap_json(self : BundledWebView) -> String {
  [
    "{",
    "\"label\":\{self.label().json_string()},",
    "\"title\":\{self.title().json_string()},",
    "\"url\":\{self.url().json_string()},",
    "\"width\":\{self.width()},",
    "\"height\":\{self.height()},",
    "\"resizable\":\{self.resizable().json_bool()},",
    "\"titleBar\":\{self.title_bar().json_string()},",
    "\"devtools\":\{self.devtools().json_bool()},",
    "\"assetProtocol\":\{self.asset_protocol().json_string()},",
    "\"bridgeGlobalName\":\{self.bridge_global_name().json_string()},",
    "\"nativeHook\":\{self.native_hook().json_string()},",
    "\"eventDispatchHook\":\{self.event_dispatch_hook().json_string()},",
    "\"allowedRoutes\":[\{self.allowed_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"initializationScripts\":[\{self.initialization_scripts().map(fn(script) { script.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn BundledRuntimeManifest::bundled_startup_operations(
  self : BundledRuntimeManifest,
) -> Array[String] {
  let operations : Array[String] = []
  for service in self.local_service_jsons() {
    operations.push(bundled_start_service_operation_json(service))
  }
  for action in self.startup_action_jsons() {
    operations.push(bundled_operation_json_from_runtime_action_json(action))
  }
  operations
}

///|
fn BundledRuntimeManifest::bundled_lifecycle_operations(
  self : BundledRuntimeManifest,
) -> Result[Array[String], String] {
  let operations : Array[String] = []
  match self.lifecycle_plans() {
    Ok(plans) =>
      for plan in plans {
        operations.push(bundled_lifecycle_operation_json(plan))
      }
    Err(problem) => return Err(problem)
  }
  Ok(operations)
}

///|
fn bundled_lifecycle_operation_json(plan : BundledLifecyclePlan) -> String {
  [
    "{",
    "\"event\":\{bundled_lifecycle_event_json(plan.event())},",
    "\"operations\":[\{plan.action_jsons().map(bundled_operation_json_from_runtime_action_json).join(",")}]",
    "}",
  ].join("")
}

///|
fn bundled_start_service_operation_json(service_json : String) -> String {
  "{\"kind\":\"start-service\",\"service\":\{service_json}}"
}

///|
fn bundled_lifecycle_event_json(event : BundledLifecycleEvent) -> String {
  if event.label() == "" {
    "{\"kind\":\{event.kind().json_string()}}"
  } else {
    [
      "{",
      "\"kind\":\{event.kind().json_string()},",
      "\"label\":\{event.label().json_string()}",
      "}",
    ].join("")
  }
}

///|
fn bundled_operation_json_from_runtime_action_json(
  action_json : String,
) -> String {
  try @json.parse(action_json) catch {
    _ => "{\"kind\":\"runtime-action\",\"action\":\{action_json.json_string()}}"
  } noraise {
    Object(action) =>
      match optional_string(action, "kind").unwrap_or("") {
        "effect" =>
          [
            "{",
            "\"kind\":\"run-effect\",",
            "\"name\":\{optional_string(action, "name").unwrap_or("").json_string()}",
            "}",
          ].join("")
        "emit" =>
          match (action.get("target"), action.get("event")) {
            (Some(target), Some(event)) =>
              [
                "{",
                "\"kind\":\"send-event\",",
                "\"target\":\{json_value_string(target)},",
                "\"event\":\{json_value_string(event)}",
                "}",
              ].join("")
            _ => "{\"kind\":\"runtime-action\",\"action\":\{action_json}}"
          }
        "navigate" =>
          [
            "{",
            "\"kind\":\"navigate-window\",",
            "\"label\":\{optional_string(action, "windowLabel").unwrap_or("").json_string()},",
            "\"url\":\{optional_string(action, "url").unwrap_or("").json_string()}",
            "}",
          ].join("")
        _ => "{\"kind\":\"runtime-action\",\"action\":\{action_json}}"
      }
    _ => "{\"kind\":\"runtime-action\",\"action\":\{action_json}}"
  }
}
