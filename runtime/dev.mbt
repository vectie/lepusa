///|
pub struct RuntimeDevPlan {
  launch_manifest : @lepusa.RuntimeLaunchManifest
  session : RuntimeSession
  webviews : Array[RuntimeWebViewSpec]
  startup_operations : Array[RuntimeOperation]
  lifecycle_steps : Array[RuntimeRunnerStep]
  bridge_sync_routes : Array[String]
  bridge_async_routes : Array[String]
} derive(Debug, Eq)

///|
pub fn RuntimeHost::dev_plan(
  self : RuntimeHost,
) -> Result[RuntimeDevPlan, Array[String]] {
  match self.runner_plan() {
    Ok(plan) =>
      Ok({
        launch_manifest: plan.launch_manifest(),
        session: plan.session(),
        webviews: plan.webviews(),
        startup_operations: plan.startup_operations(),
        lifecycle_steps: plan.lifecycle_steps(),
        bridge_sync_routes: self.sync_command_routes(),
        bridge_async_routes: self.async_command_routes(),
      })
    Err(problems) => Err(problems)
  }
}

///|
pub fn RuntimeDevPlan::launch_manifest(
  self : RuntimeDevPlan,
) -> @lepusa.RuntimeLaunchManifest {
  self.launch_manifest
}

///|
pub fn RuntimeDevPlan::session(self : RuntimeDevPlan) -> RuntimeSession {
  self.session
}

///|
pub fn RuntimeDevPlan::webviews(
  self : RuntimeDevPlan,
) -> Array[RuntimeWebViewSpec] {
  self.webviews.copy()
}

///|
pub fn RuntimeDevPlan::startup_operations(
  self : RuntimeDevPlan,
) -> Array[RuntimeOperation] {
  self.startup_operations.copy()
}

///|
pub fn RuntimeDevPlan::lifecycle_steps(
  self : RuntimeDevPlan,
) -> Array[RuntimeRunnerStep] {
  self.lifecycle_steps.copy()
}

///|
pub fn RuntimeDevPlan::bridge_sync_routes(
  self : RuntimeDevPlan,
) -> Array[String] {
  self.bridge_sync_routes.copy()
}

///|
pub fn RuntimeDevPlan::bridge_async_routes(
  self : RuntimeDevPlan,
) -> Array[String] {
  self.bridge_async_routes.copy()
}

///|
pub fn RuntimeDevPlan::to_json(self : RuntimeDevPlan) -> String {
  [
    "{",
    "\"kind\":\"runtime-dev-plan\",",
    "\"launchManifest\":\{self.launch_manifest.to_json()},",
    "\"session\":\{self.session.to_json()},",
    "\"webviews\":[\{self.webviews.map(fn(webview) { webview.to_json() }).join(",")}],",
    "\"startupOperations\":[\{self.startup_operations.map(fn(operation) { operation.to_json() }).join(",")}],",
    "\"lifecycleSteps\":[\{self.lifecycle_steps.map(fn(step) { step.to_json() }).join(",")}],",
    "\"bridgeRoutes\":{",
    "\"sync\":[\{self.bridge_sync_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"async\":[\{self.bridge_async_routes.map(fn(route) { route.json_string() }).join(",")}]",
    "}",
    "}",
  ].join("")
}
