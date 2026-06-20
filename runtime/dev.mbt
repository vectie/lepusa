///|
pub struct RuntimeDevPlan {
  launch_manifest : @lepusa.RuntimeLaunchManifest
  session : RuntimeSession
  webviews : Array[RuntimeWebViewSpec]
  startup_operations : Array[RuntimeOperation]
  lifecycle_steps : Array[RuntimeRunnerStep]
  bridge_sync_routes : Array[String]
  bridge_async_routes : Array[String]
  commands : Array[RuntimeDevCommand]
} derive(Debug, Eq)

///|
pub struct RuntimeDevCommand {
  name : String
  purpose : String
  template : String
  target_required : Bool
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
        commands: runtime_dev_commands(),
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
pub fn RuntimeDevPlan::commands(
  self : RuntimeDevPlan,
) -> Array[RuntimeDevCommand] {
  self.commands.copy()
}

///|
pub fn RuntimeDevCommand::new(
  name~ : String,
  purpose~ : String,
  template~ : String,
  target_required? : Bool = false,
) -> RuntimeDevCommand {
  { name, purpose, template, target_required }
}

///|
pub fn RuntimeDevCommand::name(self : RuntimeDevCommand) -> String {
  self.name
}

///|
pub fn RuntimeDevCommand::purpose(self : RuntimeDevCommand) -> String {
  self.purpose
}

///|
pub fn RuntimeDevCommand::template(self : RuntimeDevCommand) -> String {
  self.template
}

///|
pub fn RuntimeDevCommand::target_required(self : RuntimeDevCommand) -> Bool {
  self.target_required
}

///|
pub fn RuntimeDevCommand::to_json(self : RuntimeDevCommand) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"purpose\":\{self.purpose.json_string()},",
    "\"template\":\{self.template.json_string()},",
    "\"targetRequired\":\{self.target_required.json_bool()}",
    "}",
  ].join("")
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
    "},",
    "\"commands\":[\{self.commands.map(fn(command) { command.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn runtime_dev_commands() -> Array[RuntimeDevCommand] {
  [
    RuntimeDevCommand::new(
      name="inspect",
      purpose="print the resolved runtime plan",
      template="lepusa plan{project}",
    ),
    RuntimeDevCommand::new(
      name="manifest",
      purpose="print the native launch manifest consumed by runtime hosts",
      template="lepusa manifest{project}",
    ),
    RuntimeDevCommand::new(
      name="verify",
      purpose="check runtime, IPC, native launch, and bundle contracts",
      template="lepusa verify {target}{project}",
      target_required=true,
    ),
    RuntimeDevCommand::new(
      name="run",
      purpose="open the native development window for the selected target",
      template="lepusa run {target} --launch{project}",
      target_required=true,
    ),
    RuntimeDevCommand::new(
      name="bundle",
      purpose="materialize a platform bundle for local release testing",
      template="lepusa bundle-write {target} _build/lepusa-{target}{project}",
      target_required=true,
    ),
  ]
}
