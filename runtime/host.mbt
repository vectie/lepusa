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
  let problems : Array[String] = []
  let mut bridge_source = ""
  let startup_actions : Array[@lepusa.RuntimeAction] = []
  let lifecycle_hooks : Array[@lepusa.RuntimeLifecycleHook] = []
  match self.plan.bridge_script() {
    Ok(bridge) => bridge_source = bridge.source()
    Err(bridge_problems) =>
      for problem in bridge_problems {
        problems.push(problem)
      }
  }
  match self.plan.startup_actions() {
    Ok(actions) =>
      for action in actions {
        startup_actions.push(action)
      }
    Err(action_problems) =>
      for problem in action_problems {
        problems.push(problem)
      }
  }
  match self.plan.lifecycle_hooks() {
    Ok(hooks) =>
      for hook in hooks {
        lifecycle_hooks.push(hook)
      }
    Err(hook_problems) =>
      for problem in hook_problems {
        problems.push(problem)
      }
  }
  if problems.is_empty() {
    Ok(
      RuntimeSession::from_plan(
        self.plan,
        bridge_source~,
        startup_actions~,
        lifecycle_hooks~,
        registered_routes=self.registry.routes(),
      ),
    )
  } else {
    Err(problems)
  }
}

///|
pub fn RuntimeHost::startup_actions(
  self : RuntimeHost,
) -> Result[Array[@lepusa.RuntimeAction], Array[String]] {
  self.plan.startup_actions()
}

///|
pub fn RuntimeHost::lifecycle_actions(
  self : RuntimeHost,
  event : @lepusa.LifecycleEvent,
) -> Result[Array[@lepusa.RuntimeAction], Array[String]] {
  self.plan.lifecycle_actions(event)
}

///|
pub fn RuntimeHost::lifecycle_hooks(
  self : RuntimeHost,
) -> Result[Array[@lepusa.RuntimeLifecycleHook], Array[String]] {
  self.plan.lifecycle_hooks()
}

///|
pub fn RuntimeHost::dispatch(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
) -> @lepusa.InvokeResponse {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return @lepusa.InvokeResponse::error(request.id(), request_problems[0])
  }
  let route = request.route()
  if !self.plan.command_routes().contains(route) {
    return @lepusa.InvokeResponse::error(
      request.id(),
      "unknown command: \{route}",
    )
  }
  self.registry.dispatch(request, capabilities=self.plan.capabilities())
}
