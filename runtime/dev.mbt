///|
pub struct RuntimeDevPlan {
  session : RuntimeSession
  webviews : Array[RuntimeWebViewSpec]
  startup_operations : Array[RuntimeOperation]
} derive(Debug, Eq)

///|
pub fn RuntimeHost::dev_plan(
  self : RuntimeHost,
) -> Result[RuntimeDevPlan, Array[String]] {
  let problems : Array[String] = []
  let mut session : RuntimeSession? = None
  let webviews : Array[RuntimeWebViewSpec] = []
  let startup_operations : Array[RuntimeOperation] = []
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
  match session {
    Some(session) =>
      if problems.is_empty() {
        Ok({ session, webviews, startup_operations })
      } else {
        Err(problems)
      }
    None => Err(problems)
  }
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
