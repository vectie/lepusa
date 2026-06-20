///|
pub struct BundledNativeLifecycleStep {
  event : BundledLifecycleEvent
  evaluation_scripts : Array[@runtime.NativeEvaluationScript]
  navigations : Array[@runtime.NativeNavigation]
} derive(Debug)

///|
pub fn BundledBootstrapPlan::startup_evaluation_scripts(
  self : BundledBootstrapPlan,
) -> Array[@runtime.NativeEvaluationScript] {
  bundled_native_evaluation_scripts(self.startup_operations())
}

///|
pub fn BundledBootstrapPlan::startup_navigations(
  self : BundledBootstrapPlan,
) -> Array[@runtime.NativeNavigation] {
  bundled_native_navigations(self.startup_operations())
}

///|
pub fn BundledBootstrapPlan::native_lifecycle_steps(
  self : BundledBootstrapPlan,
) -> Result[Array[BundledNativeLifecycleStep], String] {
  bundled_native_lifecycle_steps(self.lifecycle_operations())
}

///|
pub fn BundledNativeRunPlan::startup_evaluation_scripts(
  self : BundledNativeRunPlan,
) -> Array[@runtime.NativeEvaluationScript] {
  self.bootstrap().startup_evaluation_scripts()
}

///|
pub fn BundledNativeRunPlan::startup_navigations(
  self : BundledNativeRunPlan,
) -> Array[@runtime.NativeNavigation] {
  self.bootstrap().startup_navigations()
}

///|
pub fn BundledNativeRunPlan::native_lifecycle_steps(
  self : BundledNativeRunPlan,
) -> Result[Array[BundledNativeLifecycleStep], String] {
  self.bootstrap().native_lifecycle_steps()
}

///|
pub fn BundledNativeLifecycleStep::event(
  self : BundledNativeLifecycleStep,
) -> BundledLifecycleEvent {
  self.event
}

///|
pub fn BundledNativeLifecycleStep::evaluation_scripts(
  self : BundledNativeLifecycleStep,
) -> Array[@runtime.NativeEvaluationScript] {
  self.evaluation_scripts.copy()
}

///|
pub fn BundledNativeLifecycleStep::navigations(
  self : BundledNativeLifecycleStep,
) -> Array[@runtime.NativeNavigation] {
  self.navigations.copy()
}

///|
fn bundled_native_lifecycle_steps(
  items : Array[String],
) -> Result[Array[BundledNativeLifecycleStep], String] {
  let steps : Array[BundledNativeLifecycleStep] = []
  for item in items {
    match bundled_native_lifecycle_step(item) {
      Ok(step) => steps.push(step)
      Err(problem) => return Err(problem)
    }
  }
  Ok(steps)
}

///|
fn bundled_native_lifecycle_step(
  item : String,
) -> Result[BundledNativeLifecycleStep, String] {
  try @json.parse(item) catch {
    error => Err("invalid bundled native lifecycle operation: \{error}")
  } noraise {
    Object(object) =>
      match
        (optional_object(object, "event"), optional_array(object, "operations")) {
        (Some(event_json), Some(operations_json)) =>
          match bundled_lifecycle_event_from_json(event_json) {
            Ok(event) => {
              let operation_strings = operations_json.map(json_value_string)
              Ok({
                event,
                evaluation_scripts: bundled_native_evaluation_scripts(
                  operation_strings,
                ),
                navigations: bundled_native_navigations(operation_strings),
              })
            }
            Err(problem) => Err(problem)
          }
        _ => Err("bundled native lifecycle operation is malformed")
      }
    _ => Err("bundled native lifecycle operation must be an object")
  }
}

///|
fn bundled_native_evaluation_scripts(
  operations : Array[String],
) -> Array[@runtime.NativeEvaluationScript] {
  let scripts : Array[@runtime.NativeEvaluationScript] = []
  for operation in operations {
    match bundled_native_evaluation_script(operation) {
      Some(script) => scripts.push(script)
      None => ()
    }
  }
  scripts
}

///|
fn bundled_native_navigations(
  operations : Array[String],
) -> Array[@runtime.NativeNavigation] {
  let navigations : Array[@runtime.NativeNavigation] = []
  for operation in operations {
    match bundled_native_navigation(operation) {
      Some(navigation) => navigations.push(navigation)
      None => ()
    }
  }
  navigations
}

///|
fn bundled_native_evaluation_script(
  operation : String,
) -> @runtime.NativeEvaluationScript? {
  match bundled_operation_object(operation) {
    Some(object) =>
      if optional_string(object, "kind").unwrap_or("") == "dispatch-event" {
        match optional_object(object, "dispatch") {
          Some(dispatch) =>
            Some(
              @runtime.NativeEvaluationScript::new(
                window_label=optional_string(dispatch, "windowLabel").unwrap_or(
                  "",
                ),
                script=optional_string(dispatch, "script").unwrap_or(""),
              ),
            )
          None => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn bundled_native_navigation(operation : String) -> @runtime.NativeNavigation? {
  match bundled_operation_object(operation) {
    Some(object) =>
      if optional_string(object, "kind").unwrap_or("") == "navigate-window" {
        Some(
          @runtime.NativeNavigation::new(
            window_label=optional_string(object, "label").unwrap_or(""),
            url=optional_string(object, "url").unwrap_or(""),
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn bundled_operation_object(operation : String) -> Map[String, Json]? {
  try @json.parse(operation) catch {
    _ => None
  } noraise {
    Object(object) => Some(object)
    _ => None
  }
}
