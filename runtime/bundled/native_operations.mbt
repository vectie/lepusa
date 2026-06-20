///|
pub struct BundledNativeLifecycleStep {
  event : BundledLifecycleEvent
  executable_operations : Array[@runtime.NativeExecutableOperation]
  evaluation_scripts : Array[@runtime.NativeEvaluationScript]
  navigations : Array[@runtime.NativeNavigation]
} derive(Debug)

///|
pub fn BundledBootstrapPlan::startup_executable_operations(
  self : BundledBootstrapPlan,
) -> Result[Array[@runtime.NativeExecutableOperation], String] {
  bundled_native_executable_operations(self.startup_operations())
}

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
pub fn BundledNativeRunPlan::startup_executable_operations(
  self : BundledNativeRunPlan,
) -> Result[Array[@runtime.NativeExecutableOperation], String] {
  self.bootstrap().startup_executable_operations()
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
pub fn BundledNativeLifecycleStep::executable_operations(
  self : BundledNativeLifecycleStep,
) -> Array[@runtime.NativeExecutableOperation] {
  self.executable_operations.copy()
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
              match bundled_native_executable_operations(operation_strings) {
                Ok(executable_operations) =>
                  Ok({
                    event,
                    executable_operations,
                    evaluation_scripts: bundled_native_evaluation_scripts(
                      operation_strings,
                    ),
                    navigations: bundled_native_navigations(operation_strings),
                  })
                Err(problem) => Err(problem)
              }
            }
            Err(problem) => Err(problem)
          }
        _ => Err("bundled native lifecycle operation is malformed")
      }
    _ => Err("bundled native lifecycle operation must be an object")
  }
}

///|
fn bundled_native_executable_operations(
  operations : Array[String],
) -> Result[Array[@runtime.NativeExecutableOperation], String] {
  let executable : Array[@runtime.NativeExecutableOperation] = []
  for operation in operations {
    match bundled_native_executable_operation(operation) {
      Ok(item) => executable.push(item)
      Err(problem) => return Err(problem)
    }
  }
  Ok(executable)
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
fn bundled_native_executable_operation(
  operation : String,
) -> Result[@runtime.NativeExecutableOperation, String] {
  try @json.parse(operation) catch {
    error => Err("invalid bundled native operation: \{error}")
  } noraise {
    Object(object) =>
      match optional_string(object, "kind").unwrap_or("") {
        "start-service" =>
          match object.get("service") {
            Some(service_json) =>
              match bundled_service_from_json(service_json) {
                Ok(service) =>
                  Ok(@runtime.NativeExecutableOperation::start_service(service))
                Err(problem) => Err(problem)
              }
            None => Err("bundled start-service operation requires service")
          }
        "dispatch-event" =>
          match bundled_native_evaluation_script(operation) {
            Some(script) =>
              Ok(@runtime.NativeExecutableOperation::evaluate_script(script))
            None => Err("bundled dispatch-event operation requires dispatch")
          }
        "evaluate-script" =>
          Ok(
            @runtime.NativeExecutableOperation::evaluate_script(
              @runtime.NativeEvaluationScript::new(
                window_label=optional_string(object, "windowLabel").unwrap_or(
                  "",
                ),
                script=optional_string(object, "script").unwrap_or(""),
              ),
            ),
          )
        "run-effect" =>
          Ok(
            @runtime.NativeExecutableOperation::run_effect(
              optional_string(object, "name").unwrap_or(""),
            ),
          )
        "navigate-window" =>
          Ok(
            @runtime.NativeExecutableOperation::navigate(
              @runtime.NativeNavigation::new(
                window_label=match optional_string(object, "label") {
                  Some(label) => label
                  None => optional_string(object, "windowLabel").unwrap_or("")
                },
                url=optional_string(object, "url").unwrap_or(""),
              ),
            ),
          )
        "" => Err("bundled native operation kind is required")
        kind => Err("unsupported bundled native operation kind: \{kind}")
      }
    _ => Err("bundled native operation must be an object")
  }
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
