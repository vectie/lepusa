///|
pub(all) enum DeploymentExecutionStatus {
  DeploymentStepCompleted(String)
  DeploymentStepSkipped(String)
  DeploymentStepFailed(String)
  DeploymentStepRolledBack(String)
} derive(Debug, Eq)

///|
pub struct DeploymentStepOutcome {
  step : DeploymentStep
  status : DeploymentExecutionStatus
} derive(Debug, Eq)

///|
pub struct DeploymentExecutionReport {
  plan : DeploymentPlan
  dry_run : Bool
  committed : Bool
  rolled_back : Bool
  outcomes : Array[DeploymentStepOutcome]
} derive(Debug, Eq)

///|
pub fn DeploymentStepOutcome::new(
  step~ : DeploymentStep,
  status~ : DeploymentExecutionStatus,
) -> DeploymentStepOutcome {
  { step, status }
}

///|
pub fn DeploymentExecutionStatus::name(
  self : DeploymentExecutionStatus,
) -> String {
  match self {
    DeploymentStepCompleted(_) => "completed"
    DeploymentStepSkipped(_) => "skipped"
    DeploymentStepFailed(_) => "failed"
    DeploymentStepRolledBack(_) => "rolled-back"
  }
}

///|
pub fn DeploymentExecutionStatus::message(
  self : DeploymentExecutionStatus,
) -> String {
  match self {
    DeploymentStepCompleted(message)
    | DeploymentStepSkipped(message)
    | DeploymentStepFailed(message)
    | DeploymentStepRolledBack(message) => message
  }
}

///|
pub fn DeploymentExecutionStatus::ok(self : DeploymentExecutionStatus) -> Bool {
  !(self is DeploymentStepFailed(_))
}

///|
pub fn DeploymentStepOutcome::step(
  self : DeploymentStepOutcome,
) -> DeploymentStep {
  self.step
}

///|
pub fn DeploymentStepOutcome::status(
  self : DeploymentStepOutcome,
) -> DeploymentExecutionStatus {
  self.status
}

///|
pub fn DeploymentStepOutcome::to_json(self : DeploymentStepOutcome) -> String {
  [
    "{",
    "\"step\":\{self.step.to_json()},",
    "\"status\":\{self.status.name().json_string()},",
    "\"message\":\{self.status.message().json_string()}",
    "}",
  ].join("")
}

///|
pub fn DeploymentPlan::dry_run(
  self : DeploymentPlan,
  fail_at? : DeploymentStepKind,
  allow_restart? : Bool = false,
) -> DeploymentExecutionReport {
  deployment_execute_dry_run(self, fail_at~, allow_restart~)
}

///|
pub fn DeploymentExecutionReport::plan(
  self : DeploymentExecutionReport,
) -> DeploymentPlan {
  self.plan
}

///|
pub fn DeploymentExecutionReport::dry_run(
  self : DeploymentExecutionReport,
) -> Bool {
  self.dry_run
}

///|
pub fn DeploymentExecutionReport::committed(
  self : DeploymentExecutionReport,
) -> Bool {
  self.committed
}

///|
pub fn DeploymentExecutionReport::rolled_back(
  self : DeploymentExecutionReport,
) -> Bool {
  self.rolled_back
}

///|
pub fn DeploymentExecutionReport::outcomes(
  self : DeploymentExecutionReport,
) -> Array[DeploymentStepOutcome] {
  self.outcomes.copy()
}

///|
pub fn DeploymentExecutionReport::ok(self : DeploymentExecutionReport) -> Bool {
  self.committed && self.failed_count() == 0
}

///|
pub fn DeploymentExecutionReport::completed_count(
  self : DeploymentExecutionReport,
) -> Int {
  deployment_outcome_count(self.outcomes, "completed")
}

///|
pub fn DeploymentExecutionReport::skipped_count(
  self : DeploymentExecutionReport,
) -> Int {
  deployment_outcome_count(self.outcomes, "skipped")
}

///|
pub fn DeploymentExecutionReport::failed_count(
  self : DeploymentExecutionReport,
) -> Int {
  deployment_outcome_count(self.outcomes, "failed")
}

///|
pub fn DeploymentExecutionReport::rolled_back_count(
  self : DeploymentExecutionReport,
) -> Int {
  deployment_outcome_count(self.outcomes, "rolled-back")
}

///|
pub fn DeploymentExecutionReport::first_failure_message(
  self : DeploymentExecutionReport,
) -> String? {
  for outcome in self.outcomes {
    match outcome.status() {
      DeploymentStepFailed(message) => return Some(message)
      _ => ()
    }
  }
  None
}

///|
pub fn DeploymentExecutionReport::summary(
  self : DeploymentExecutionReport,
) -> String {
  let lines : Array[String] = [
    "Lepusa deployment execution",
    "identifier: \{self.plan.identifier()}",
    "target: \{self.plan.target().name()}",
    "mode: \{self.plan.mode().name()}",
    "dry-run: \{self.dry_run}",
    "committed: \{self.committed}",
    "rolled-back: \{self.rolled_back}",
    "outcomes: \{self.outcomes.length()}",
    "completed: \{self.completed_count()}",
    "skipped: \{self.skipped_count()}",
    "failed: \{self.failed_count()}",
    "rollback-outcomes: \{self.rolled_back_count()}",
  ]
  for outcome in self.outcomes {
    lines.push(
      "step: \{outcome.step().kind().name()} status=\{outcome.status().name()} message=\{outcome.status().message()}",
    )
  }
  lines.join("\n") + "\n"
}

///|
pub fn DeploymentExecutionReport::to_json(
  self : DeploymentExecutionReport,
) -> String {
  [
    "{",
    "\"dryRun\":\{self.dry_run.json_bool()},",
    "\"committed\":\{self.committed.json_bool()},",
    "\"rolledBack\":\{self.rolled_back.json_bool()},",
    "\"completed\":\{self.completed_count()},",
    "\"skipped\":\{self.skipped_count()},",
    "\"failed\":\{self.failed_count()},",
    "\"rollbackOutcomes\":\{self.rolled_back_count()},",
    "\"firstFailure\":\{optional_deployment_json_string(self.first_failure_message())},",
    "\"plan\":\{self.plan.to_json()},",
    "\"outcomes\":[\{self.outcomes.map(fn(outcome) { outcome.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn deployment_execute_dry_run(
  plan : DeploymentPlan,
  fail_at~ : DeploymentStepKind?,
  allow_restart~ : Bool,
) -> DeploymentExecutionReport {
  let outcomes : Array[DeploymentStepOutcome] = []
  let installed : Array[String] = []
  let mut failed = false
  for step in plan.steps() {
    if failed {
      break
    }
    if step.kind() is RollbackUpdateArtifact {
      outcomes.push(
        DeploymentStepOutcome::new(
          step~,
          status=DeploymentStepSkipped(
            "rollback reserved until a failed install transaction",
          ),
        ),
      )
    } else if step.kind() is RestartApplication && !allow_restart {
      outcomes.push(
        DeploymentStepOutcome::new(
          step~,
          status=DeploymentStepSkipped(
            "restart is delegated to the native app host",
          ),
        ),
      )
    } else if deployment_should_fail(step, fail_at) {
      failed = true
      outcomes.push(
        DeploymentStepOutcome::new(
          step~,
          status=DeploymentStepFailed(
            "dry-run injected failure at \{step.kind().name()}",
          ),
        ),
      )
    } else {
      outcomes.push(
        DeploymentStepOutcome::new(
          step~,
          status=DeploymentStepCompleted(
            "dry-run completed \{step.kind().name()}",
          ),
        ),
      )
      if step.kind() is InstallUpdateArtifact {
        match step.artifact_path() {
          Some(path) => installed.push(path)
          None => ()
        }
      }
    }
  }
  if failed {
    for rollback in plan.rollback_steps() {
      match rollback.artifact_path() {
        Some(path) =>
          if installed.contains(path) {
            outcomes.push(
              DeploymentStepOutcome::new(
                step=rollback,
                status=DeploymentStepRolledBack(
                  "dry-run rollback restored \{path}",
                ),
              ),
            )
          }
        None => ()
      }
    }
  }
  let rolled_back = outcomes.any(fn(outcome) {
    outcome.status() is DeploymentStepRolledBack(_)
  })
  { plan, dry_run: true, committed: !failed, rolled_back, outcomes }
}

///|
fn deployment_should_fail(
  step : DeploymentStep,
  fail_at : DeploymentStepKind?,
) -> Bool {
  match fail_at {
    Some(kind) => step.kind() == kind
    None => false
  }
}

///|
fn deployment_outcome_count(
  outcomes : Array[DeploymentStepOutcome],
  name : String,
) -> Int {
  outcomes.filter(fn(outcome) { outcome.status().name() == name }).length()
}
