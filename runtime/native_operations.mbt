///|
pub struct NativeEvaluationScript {
  window_label : String
  script : String
} derive(Debug, Eq)

///|
pub struct NativeNavigation {
  window_label : String
  url : String
} derive(Debug, Eq)

///|
pub fn NativeEvaluationScript::new(
  window_label~ : String,
  script~ : String,
) -> NativeEvaluationScript {
  { window_label, script }
}

///|
pub fn NativeNavigation::new(
  window_label~ : String,
  url~ : String,
) -> NativeNavigation {
  { window_label, url }
}

///|
pub fn NativeEvaluationScript::window_label(
  self : NativeEvaluationScript,
) -> String {
  self.window_label
}

///|
pub fn NativeEvaluationScript::script(self : NativeEvaluationScript) -> String {
  self.script
}

///|
pub fn NativeEvaluationScript::to_json(self : NativeEvaluationScript) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"script\":\{self.script.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeNavigation::window_label(self : NativeNavigation) -> String {
  self.window_label
}

///|
pub fn NativeNavigation::url(self : NativeNavigation) -> String {
  self.url
}

///|
pub fn NativeNavigation::to_json(self : NativeNavigation) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"url\":\{self.url.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeOperation::kind(self : NativeOperation) -> String {
  match self {
    NativeStartService(_) => "start-service"
    NativeDispatchEvent(_) => "evaluate-script"
    NativeRunEffect(_) => "run-effect"
    NativeNavigateWindow(_, _) => "navigate-window"
  }
}

///|
pub fn NativeOperation::service(
  self : NativeOperation,
) -> @lepusa.LocalService? {
  match self {
    NativeStartService(service) => Some(service)
    _ => None
  }
}

///|
pub fn NativeOperation::evaluation_script(
  self : NativeOperation,
) -> NativeEvaluationScript? {
  match self {
    NativeDispatchEvent(dispatch) =>
      Some(
        NativeEvaluationScript::new(
          window_label=dispatch.window_label(),
          script=dispatch.script(),
        ),
      )
    _ => None
  }
}

///|
pub fn NativeOperation::effect_name(self : NativeOperation) -> String? {
  match self {
    NativeRunEffect(name) => Some(name)
    _ => None
  }
}

///|
pub fn NativeOperation::navigation(self : NativeOperation) -> NativeNavigation? {
  match self {
    NativeNavigateWindow(window_label, url) =>
      Some(NativeNavigation::new(window_label~, url~))
    _ => None
  }
}

///|
pub fn NativeOperation::window_label(self : NativeOperation) -> String? {
  match self.evaluation_script() {
    Some(script) => Some(script.window_label())
    None =>
      match self.navigation() {
        Some(navigation) => Some(navigation.window_label())
        None => None
      }
  }
}

///|
pub fn NativeRunnerPlan::startup_evaluation_scripts(
  self : NativeRunnerPlan,
) -> Array[NativeEvaluationScript] {
  native_evaluation_scripts(self.startup_operations())
}

///|
pub fn NativeRunnerPlan::startup_navigations(
  self : NativeRunnerPlan,
) -> Array[NativeNavigation] {
  native_navigations(self.startup_operations())
}

///|
pub fn NativeRunnerStep::evaluation_scripts(
  self : NativeRunnerStep,
) -> Array[NativeEvaluationScript] {
  native_evaluation_scripts(self.operations())
}

///|
pub fn NativeRunnerStep::navigations(
  self : NativeRunnerStep,
) -> Array[NativeNavigation] {
  native_navigations(self.operations())
}

///|
fn native_evaluation_scripts(
  operations : Array[NativeOperation],
) -> Array[NativeEvaluationScript] {
  let scripts : Array[NativeEvaluationScript] = []
  for operation in operations {
    match operation.evaluation_script() {
      Some(script) => scripts.push(script)
      None => ()
    }
  }
  scripts
}

///|
fn native_navigations(
  operations : Array[NativeOperation],
) -> Array[NativeNavigation] {
  let navigations : Array[NativeNavigation] = []
  for operation in operations {
    match operation.navigation() {
      Some(navigation) => navigations.push(navigation)
      None => ()
    }
  }
  navigations
}
