///|
pub struct RuntimeHost {
  manager : @lepusa.AppManager
}

///|
pub fn RuntimeHost::new(
  plan : @lepusa.RuntimePlan,
  registry? : @lepusa.CommandRegistry = @lepusa.CommandRegistry::new(),
) -> RuntimeHost {
  { manager: @lepusa.AppManager::new(plan, registry~) }
}

///|
pub fn RuntimeHost::from_manager(manager : @lepusa.AppManager) -> RuntimeHost {
  { manager, }
}

///|
pub fn RuntimeHost::plan(self : RuntimeHost) -> @lepusa.RuntimePlan {
  self.manager.plan()
}

///|
pub fn RuntimeHost::registry(self : RuntimeHost) -> @lepusa.CommandRegistry {
  self.manager.registry()
}

///|
pub fn RuntimeHost::sync_command_routes(self : RuntimeHost) -> Array[String] {
  self.registry().sync_routes()
}

///|
pub fn RuntimeHost::async_command_routes(self : RuntimeHost) -> Array[String] {
  self.registry().async_routes()
}

///|
pub fn RuntimeHost::audit(self : RuntimeHost) -> @lepusa.RuntimeAudit {
  self.plan().audit_with_registered_routes(self.registry().routes())
}

///|
pub fn RuntimeHost::invoke_contracts(
  self : RuntimeHost,
) -> Array[@lepusa.InvokeContract] {
  self.registry().invoke_contracts(self.security_profile())
}

///|
pub fn RuntimeHost::invoke_contract_report(
  self : RuntimeHost,
) -> @lepusa.InvokeContractReport {
  self.registry().invoke_contract_report(self.security_profile())
}

///|
pub fn RuntimeHost::security_profile(
  self : RuntimeHost,
) -> @lepusa.SecurityProfile {
  self.manager.security_profile()
}

///|
pub fn RuntimeHost::snapshot(
  self : RuntimeHost,
) -> Result[RuntimeSession, Array[String]] {
  let problems : Array[String] = []
  let mut bridge_source = ""
  let startup_actions : Array[@lepusa.RuntimeAction] = []
  let lifecycle_hooks : Array[@lepusa.RuntimeLifecycleHook] = []
  let webviews : Array[RuntimeWebViewSpec] = []
  match self.plan().startup_actions() {
    Ok(actions) =>
      for action in actions {
        startup_actions.push(action)
      }
    Err(action_problems) =>
      for problem in action_problems {
        problems.push(problem)
      }
  }
  match self.plan().lifecycle_hooks() {
    Ok(hooks) =>
      for hook in hooks {
        lifecycle_hooks.push(hook)
      }
    Err(hook_problems) =>
      for problem in hook_problems {
        problems.push(problem)
      }
  }
  match self.webviews() {
    Ok(specs) =>
      for spec in specs {
        if bridge_source == "" {
          match spec.initialization_scripts().get(0) {
            Some(script) => bridge_source = script
            None => ()
          }
        }
        webviews.push(spec)
      }
    Err(webview_problems) =>
      for problem in webview_problems {
        problems.push(problem)
      }
  }
  if problems.is_empty() {
    Ok(
      RuntimeSession::from_plan(
        self.plan(),
        bridge_source~,
        startup_actions~,
        lifecycle_hooks~,
        registered_routes=self.registry().routes(),
        webviews~,
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
  self.plan().startup_actions()
}

///|
pub fn RuntimeHost::lifecycle_actions(
  self : RuntimeHost,
  event : @lepusa.LifecycleEvent,
) -> Result[Array[@lepusa.RuntimeAction], Array[String]] {
  self.plan().lifecycle_actions(event)
}

///|
pub fn RuntimeHost::lifecycle_hooks(
  self : RuntimeHost,
) -> Result[Array[@lepusa.RuntimeLifecycleHook], Array[String]] {
  self.plan().lifecycle_hooks()
}

///|
pub fn RuntimeHost::dispatch(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
) -> @lepusa.InvokeResponse {
  self.manager.dispatch(request)
}

///|
pub async fn RuntimeHost::dispatch_async(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
) -> @lepusa.InvokeResponse {
  self.manager.dispatch_async(request)
}
