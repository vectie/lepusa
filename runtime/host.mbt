///|
pub struct RuntimeHost {
  plan : @lepusa.RuntimePlan
  registry : @lepusa.CommandRegistry
}

///|
pub fn RuntimeHost::new(
  plan : @lepusa.RuntimePlan,
  registry? : @lepusa.CommandRegistry = @lepusa.CommandRegistry::new(),
) -> RuntimeHost {
  { plan, registry }
}

///|
pub fn RuntimeHost::plan(self : RuntimeHost) -> @lepusa.RuntimePlan {
  self.plan
}

///|
pub fn RuntimeHost::registry(self : RuntimeHost) -> @lepusa.CommandRegistry {
  self.registry
}

///|
pub fn RuntimeHost::snapshot(
  self : RuntimeHost,
) -> Result[RuntimeSession, Array[String]] {
  match self.plan.bridge_script() {
    Ok(bridge) =>
      Ok(
        RuntimeSession::from_plan(
          self.plan,
          bridge_source=bridge.source(),
          registered_routes=self.registry.routes(),
        ),
      )
    Err(problems) => Err(problems)
  }
}

///|
pub fn RuntimeHost::dispatch(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
) -> @lepusa.InvokeResponse {
  self.registry.dispatch(request, capabilities=self.plan.capabilities())
}
