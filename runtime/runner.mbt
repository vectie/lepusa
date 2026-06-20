///|
pub struct RuntimeRunnerPlan {
  launch_manifest : @lepusa.RuntimeLaunchManifest
  session : RuntimeSession
  webviews : Array[RuntimeWebViewSpec]
  startup_operations : Array[RuntimeOperation]
  lifecycle_steps : Array[RuntimeRunnerStep]
} derive(Debug, Eq)

///|
pub struct RuntimeRunnerStep {
  event : @lepusa.LifecycleEvent
  session : RuntimeSession
  operations : Array[RuntimeOperation]
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
  let lifecycle_steps : Array[RuntimeRunnerStep] = []
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
  match self.snapshot() {
    Ok(initial_session) =>
      match initial_session.apply_actions(initial_session.startup_actions()) {
        Ok(step) => {
          session = Some(step.session())
          for
            service in runtime_runner_startup_services(
              initial_session,
              step.session(),
            ) {
            startup_operations.push(RuntimeStartService(service))
          }
          for operation in step.operations() {
            startup_operations.push(operation)
          }
          match runtime_lifecycle_steps_from_session(step.session()) {
            Ok(steps) =>
              for step in steps {
                lifecycle_steps.push(step)
              }
            Err(lifecycle_problems) =>
              for problem in lifecycle_problems {
                problems.push(problem)
              }
          }
        }
        Err(step_problems) =>
          for problem in step_problems {
            problems.push(problem)
          }
      }
    Err(snapshot_problems) =>
      for problem in snapshot_problems {
        problems.push(problem)
      }
  }
  match (launch_manifest, session) {
    (Some(launch_manifest), Some(session)) =>
      if problems.is_empty() {
        Ok({
          launch_manifest,
          session,
          webviews,
          startup_operations,
          lifecycle_steps,
        })
      } else {
        Err(problems)
      }
    _ => Err(problems)
  }
}

///|
fn runtime_runner_startup_services(
  initial_session : RuntimeSession,
  startup_session : RuntimeSession,
) -> Array[@lepusa.LocalService] {
  let services : Array[@lepusa.LocalService] = []
  for service in initial_session.local_services() {
    services.push(service)
  }
  for service in startup_session.local_services() {
    if !runtime_service_names(services).contains(service.name()) {
      services.push(service)
    }
  }
  services
}

///|
fn runtime_service_names(
  services : Array[@lepusa.LocalService],
) -> Array[String] {
  let names : Array[String] = []
  for service in services {
    names.push(service.name())
  }
  names
}

///|
fn runtime_lifecycle_steps_from_session(
  session : RuntimeSession,
) -> Result[Array[RuntimeRunnerStep], Array[String]] {
  let steps : Array[RuntimeRunnerStep] = []
  let seen : Array[@lepusa.LifecycleEvent] = []
  let problems : Array[String] = []
  for hook in session.lifecycle_hooks() {
    let event = hook.event()
    if !(event is AppStarted) && !seen.contains(event) {
      seen.push(event)
      match session.lifecycle_step(event) {
        Ok(step) =>
          if !step.operations().is_empty() {
            steps.push({
              event,
              session: step.session(),
              operations: step.operations(),
            })
          }
        Err(step_problems) =>
          for problem in step_problems {
            problems.push(problem)
          }
      }
    }
  }
  if problems.is_empty() {
    Ok(steps)
  } else {
    Err(problems)
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

///|
pub fn RuntimeRunnerPlan::lifecycle_steps(
  self : RuntimeRunnerPlan,
) -> Array[RuntimeRunnerStep] {
  self.lifecycle_steps.copy()
}

///|
pub fn RuntimeRunnerPlan::lifecycle_step(
  self : RuntimeRunnerPlan,
  event : @lepusa.LifecycleEvent,
) -> RuntimeRunnerStep {
  for step in self.lifecycle_steps {
    if step.event() == event {
      return step
    }
  }
  match event {
    AppStarted =>
      {
        event,
        session: self.session,
        operations: self.startup_operations.copy(),
      }
    _ => { event, session: self.session, operations: [] }
  }
}

///|
pub fn RuntimeRunnerStep::event(
  self : RuntimeRunnerStep,
) -> @lepusa.LifecycleEvent {
  self.event
}

///|
pub fn RuntimeRunnerStep::session(self : RuntimeRunnerStep) -> RuntimeSession {
  self.session
}

///|
pub fn RuntimeRunnerStep::operations(
  self : RuntimeRunnerStep,
) -> Array[RuntimeOperation] {
  self.operations.copy()
}

///|
pub fn RuntimeRunnerStep::to_json(self : RuntimeRunnerStep) -> String {
  [
    "{",
    "\"event\":\{self.event.to_json()},",
    "\"operations\":[\{self.operations.map(fn(operation) { operation.to_json() }).join(",")}],",
    "\"session\":\{self.session.to_json()}",
    "}",
  ].join("")
}
