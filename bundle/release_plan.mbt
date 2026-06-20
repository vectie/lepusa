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
pub fn BundleReleasePlan::summary(self : BundleReleasePlan) -> String {
  let manifest = self.manifest()
  let lines : Array[String] = [
    "Lepusa release plan",
    "manifest: \{manifest.path()}",
    "identifier: \{manifest.identifier()}",
    "product: \{manifest.product_name()}",
    "target: \{manifest.target()}",
    "steps: \{self.steps.length()}",
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
    "\"steps\":[\{self.steps.map(fn(step) { step.to_json() }).join(",")}]",
    "}",
  ].join("")
}
