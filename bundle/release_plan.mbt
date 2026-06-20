///|
pub(all) enum BundleReleaseStepKind {
  ValidateRuntimeDependencies
  StageResources
  ValidateSigningPrerequisites
  RunSigningSteps
  CollectArtifacts
} derive(Debug, Eq)

///|
pub struct BundleReleaseStep {
  kind : BundleReleaseStepKind
  name : String
  required : Bool
  items : Array[BundleDistributionEntry]
} derive(Debug, Eq)

///|
pub struct BundleReleasePlan {
  manifest : BundleDistributionManifest
  steps : Array[BundleReleaseStep]
} derive(Debug, Eq)

///|
pub fn BundleReleaseStep::new(
  kind~ : BundleReleaseStepKind,
  name~ : String,
  required? : Bool = true,
  items? : Array[BundleDistributionEntry] = [],
) -> BundleReleaseStep {
  { kind, name, required, items }
}

///|
pub fn BundleReleaseStepKind::name(self : BundleReleaseStepKind) -> String {
  match self {
    ValidateRuntimeDependencies => "validate-runtime-dependencies"
    StageResources => "stage-resources"
    ValidateSigningPrerequisites => "validate-signing-prerequisites"
    RunSigningSteps => "run-signing-steps"
    CollectArtifacts => "collect-artifacts"
  }
}

///|
pub fn BundleReleaseStep::kind(
  self : BundleReleaseStep,
) -> BundleReleaseStepKind {
  self.kind
}

///|
pub fn BundleReleaseStep::name(self : BundleReleaseStep) -> String {
  self.name
}

///|
pub fn BundleReleaseStep::required(self : BundleReleaseStep) -> Bool {
  self.required
}

///|
pub fn BundleReleaseStep::items(
  self : BundleReleaseStep,
) -> Array[BundleDistributionEntry] {
  self.items.copy()
}

///|
pub fn BundleReleaseStep::item_count(self : BundleReleaseStep) -> Int {
  self.items.length()
}

///|
pub fn BundleReleaseStep::to_json(self : BundleReleaseStep) -> String {
  [
    "{",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"name\":\{self.name.json_string()},",
    "\"required\":\{self.required.json_bool()},",
    "\"itemCount\":\{self.item_count()},",
    "\"items\":[\{self.items.map(fn(item) { item.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn BundleDistributionManifest::release_plan(
  self : BundleDistributionManifest,
) -> BundleReleasePlan {
  {
    manifest: self,
    steps: [
      BundleReleaseStep::new(
        kind=ValidateRuntimeDependencies,
        name="Validate runtime dependencies",
        items=self.runtime_dependency_entries(),
      ),
      BundleReleaseStep::new(
        kind=StageResources,
        name="Stage bundle resources",
        required=false,
        items=self.resource_entries(),
      ),
      BundleReleaseStep::new(
        kind=ValidateSigningPrerequisites,
        name="Validate signing prerequisites",
        items=self.signing_prerequisite_entries(),
      ),
      BundleReleaseStep::new(
        kind=RunSigningSteps,
        name="Run signing steps",
        required=self.signing_configured(),
        items=self.signing_step_entries(),
      ),
      BundleReleaseStep::new(
        kind=CollectArtifacts,
        name="Collect release artifacts",
        items=self.artifact_entries(),
      ),
    ],
  }
}

///|
pub fn BundleReleasePlan::manifest(
  self : BundleReleasePlan,
) -> BundleDistributionManifest {
  self.manifest
}

///|
pub fn BundleReleasePlan::steps(
  self : BundleReleasePlan,
) -> Array[BundleReleaseStep] {
  self.steps.copy()
}

///|
pub fn BundleReleasePlan::required_steps(
  self : BundleReleasePlan,
) -> Array[BundleReleaseStep] {
  let steps : Array[BundleReleaseStep] = []
  for step in self.steps {
    if step.required() {
      steps.push(step)
    }
  }
  steps
}

///|
pub fn BundleReleasePlan::optional_steps(
  self : BundleReleasePlan,
) -> Array[BundleReleaseStep] {
  let steps : Array[BundleReleaseStep] = []
  for step in self.steps {
    if !step.required() {
      steps.push(step)
    }
  }
  steps
}

///|
pub fn BundleReleasePlan::required_step_count(self : BundleReleasePlan) -> Int {
  self.required_steps().length()
}

///|
pub fn BundleReleasePlan::optional_step_count(self : BundleReleasePlan) -> Int {
  self.optional_steps().length()
}

///|
pub fn BundleReleasePlan::required_item_count(self : BundleReleasePlan) -> Int {
  let mut count = 0
  for step in self.steps {
    if step.required() {
      count += step.item_count()
    }
  }
  count
}

///|
pub fn BundleReleasePlan::optional_item_count(self : BundleReleasePlan) -> Int {
  let mut count = 0
  for step in self.steps {
    if !step.required() {
      count += step.item_count()
    }
  }
  count
}

///|
pub fn BundleReleasePlan::missing_required_steps(
  self : BundleReleasePlan,
) -> Array[BundleReleaseStep] {
  let steps : Array[BundleReleaseStep] = []
  for step in self.steps {
    if step.required() && step.item_count() == 0 {
      steps.push(step)
    }
  }
  steps
}

///|
pub fn BundleReleasePlan::ready(self : BundleReleasePlan) -> Bool {
  self.missing_required_steps().is_empty()
}

///|
pub fn BundleReleasePlan::readiness_message(self : BundleReleasePlan) -> String {
  let missing = self.missing_required_steps()
  if missing.is_empty() {
    "required release steps have data"
  } else {
    "missing required release data: \{missing.map(fn(step) { step.kind().name() }).join(", ")}"
  }
}

///|
pub fn BundleReleasePlan::summary(self : BundleReleasePlan) -> String {
  let manifest = self.manifest()
  let lines : Array[String] = [
    "Lepusa release plan",
    "manifest: \{manifest.path()}",
    "identifier: \{manifest.identifier()}",
    "product: \{manifest.product_name()}",
    "target: \{manifest.target()}",
    "steps: \{self.steps.length()}",
    "required-steps: \{self.required_step_count()}",
    "optional-steps: \{self.optional_step_count()}",
    "required-items: \{self.required_item_count()}",
    "optional-items: \{self.optional_item_count()}",
    "ready: \{self.ready()}",
    "readiness: \{self.readiness_message()}",
  ]
  for step in self.steps {
    lines.push(
      "step: \{step.kind().name()} required=\{step.required()} items=\{step.item_count()}",
    )
  }
  lines.join("\n") + "\n"
}

///|
pub fn BundleReleasePlan::to_json(self : BundleReleasePlan) -> String {
  [
    "{",
    "\"manifest\":\{self.manifest().to_json()},",
    "\"ready\":\{self.ready().json_bool()},",
    "\"readiness\":\{self.readiness_message().json_string()},",
    "\"requiredStepCount\":\{self.required_step_count()},",
    "\"optionalStepCount\":\{self.optional_step_count()},",
    "\"requiredItemCount\":\{self.required_item_count()},",
    "\"optionalItemCount\":\{self.optional_item_count()},",
    "\"missingRequiredSteps\":[\{self.missing_required_steps().map(fn(step) { step.to_json() }).join(",")}],",
    "\"steps\":[\{self.steps.map(fn(step) { step.to_json() }).join(",")}]",
    "}",
  ].join("")
}
