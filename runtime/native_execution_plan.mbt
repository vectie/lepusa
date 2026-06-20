///|
pub struct NativeExecutionPlan {
  startup_operations : Array[NativeExecutableOperation]
  lifecycle_steps : Array[NativeExecutionStep]
} derive(Debug, Eq)

///|
pub struct NativeExecutionStep {
  event_json : String
  operations : Array[NativeExecutableOperation]
} derive(Debug, Eq)

///|
pub fn NativeExecutionPlan::new(
  startup_operations~ : Array[NativeExecutableOperation],
  lifecycle_steps~ : Array[NativeExecutionStep],
) -> NativeExecutionPlan {
  {
    startup_operations: startup_operations.copy(),
    lifecycle_steps: lifecycle_steps.copy(),
  }
}

///|
pub fn NativeExecutionStep::new(
  event_json~ : String,
  operations~ : Array[NativeExecutableOperation],
) -> NativeExecutionStep {
  { event_json, operations: operations.copy() }
}

///|
pub fn NativeExecutionPlan::startup_operations(
  self : NativeExecutionPlan,
) -> Array[NativeExecutableOperation] {
  self.startup_operations.copy()
}

///|
pub fn NativeExecutionPlan::startup_operation_jsons(
  self : NativeExecutionPlan,
) -> Array[String] {
  self.startup_operations.map(fn(operation) { operation.to_json() })
}

///|
pub fn NativeExecutionPlan::startup_evaluation_scripts(
  self : NativeExecutionPlan,
) -> Array[NativeEvaluationScript] {
  native_executable_evaluation_scripts(self.startup_operations)
}

///|
pub fn NativeExecutionPlan::startup_navigations(
  self : NativeExecutionPlan,
) -> Array[NativeNavigation] {
  native_executable_navigations(self.startup_operations)
}

///|
pub fn NativeExecutionPlan::startup_initialization_script(
  self : NativeExecutionPlan,
  window_label : String,
) -> String {
  self
  .startup_evaluation_scripts()
  .filter(fn(script) { script.window_label() == window_label })
  .map(fn(script) { script.script() })
  .join("\n")
}

///|
pub fn NativeExecutionPlan::lifecycle_steps(
  self : NativeExecutionPlan,
) -> Array[NativeExecutionStep] {
  self.lifecycle_steps.copy()
}

///|
pub fn NativeExecutionPlan::lifecycle_step_by_event_json(
  self : NativeExecutionPlan,
  event_json : String,
) -> NativeExecutionStep? {
  for step in self.lifecycle_steps {
    if step.event_json() == event_json {
      return Some(step)
    }
  }
  None
}

///|
pub fn NativeExecutionPlan::app_will_exit_step(
  self : NativeExecutionPlan,
) -> NativeExecutionStep? {
  self.lifecycle_step_by_event_json(
    @lepusa.LifecycleEvent::app_will_exit().to_json(),
  )
}

///|
pub fn NativeExecutionPlan::to_json(self : NativeExecutionPlan) -> String {
  [
    "{",
    "\"startupOperations\":[\{self.startup_operation_jsons().join(",")}],",
    "\"lifecycleSteps\":[\{self.lifecycle_steps.map(fn(step) { step.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn NativeExecutionStep::event_json(self : NativeExecutionStep) -> String {
  self.event_json
}

///|
pub fn NativeExecutionStep::operations(
  self : NativeExecutionStep,
) -> Array[NativeExecutableOperation] {
  self.operations.copy()
}

///|
pub fn NativeExecutionStep::operation_jsons(
  self : NativeExecutionStep,
) -> Array[String] {
  self.operations.map(fn(operation) { operation.to_json() })
}

///|
pub fn NativeExecutionStep::to_json(self : NativeExecutionStep) -> String {
  [
    "{",
    "\"event\":\{self.event_json},",
    "\"operations\":[\{self.operation_jsons().join(",")}]",
    "}",
  ].join("")
}

///|
pub fn NativeRunnerPlan::execution_plan(
  self : NativeRunnerPlan,
) -> NativeExecutionPlan {
  NativeExecutionPlan::new(
    startup_operations=self.startup_executable_operations(),
    lifecycle_steps=self
      .lifecycle_steps()
      .map(fn(step) {
        NativeExecutionStep::new(
          event_json=step.event().to_json(),
          operations=step.executable_operations(),
        )
      }),
  )
}

///|
pub fn NativePreparedRunPlan::execution_plan(
  self : NativePreparedRunPlan,
) -> NativeExecutionPlan {
  self.runner().execution_plan()
}
