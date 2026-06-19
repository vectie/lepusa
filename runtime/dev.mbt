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
  match self.runner_plan() {
    Ok(plan) =>
      Ok({
        session: plan.session(),
        webviews: plan.webviews(),
        startup_operations: plan.startup_operations(),
      })
    Err(problems) => Err(problems)
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
