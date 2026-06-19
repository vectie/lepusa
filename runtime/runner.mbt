///|
pub struct RuntimeRunnerPlan {
  launch_manifest : @lepusa.RuntimeLaunchManifest
  session : RuntimeSession
  webviews : Array[RuntimeWebViewSpec]
  startup_operations : Array[RuntimeOperation]
} derive(Debug, Eq)

///|
pub fn RuntimeHost::runner_plan(
  self : RuntimeHost,
) -> Result[RuntimeRunnerPlan, Array[String]] {
  let problems : Array[String] = []
  let mut launch_manifest : @lepusa.RuntimeLaunchManifest? = None
  let mut session : RuntimeSession? = None
  let webviews : Array[RuntimeWebViewSpec] = []
  let startup_operations : Array[RuntimeOperation] = []
  match self.launch_manifest() {
    Ok(manifest) => launch_manifest = Some(manifest)
    Err(manifest_problems) =>
      for problem in manifest_problems {
        problems.push(problem)
      }
  }
  match self.webviews() {
    Ok(specs) =>
      for spec in specs {
        webviews.push(spec)
      }
    Err(webview_problems) =>
      for problem in webview_problems {
        problems.push(problem)
      }
  }
  match self.startup_step() {
    Ok(step) => {
      session = Some(step.session())
      for operation in step.operations() {
        startup_operations.push(operation)
      }
    }
    Err(step_problems) =>
      for problem in step_problems {
        problems.push(problem)
      }
  }
  match (launch_manifest, session) {
    (Some(launch_manifest), Some(session)) =>
      if problems.is_empty() {
        Ok({ launch_manifest, session, webviews, startup_operations })
      } else {
        Err(problems)
      }
    _ => Err(problems)
  }
}

///|
pub fn RuntimeRunnerPlan::launch_manifest(
  self : RuntimeRunnerPlan,
) -> @lepusa.RuntimeLaunchManifest {
  self.launch_manifest
}

///|
pub fn RuntimeRunnerPlan::session(self : RuntimeRunnerPlan) -> RuntimeSession {
  self.session
}

///|
pub fn RuntimeRunnerPlan::webviews(
  self : RuntimeRunnerPlan,
) -> Array[RuntimeWebViewSpec] {
  self.webviews.copy()
}

///|
pub fn RuntimeRunnerPlan::startup_operations(
  self : RuntimeRunnerPlan,
) -> Array[RuntimeOperation] {
  self.startup_operations.copy()
}
