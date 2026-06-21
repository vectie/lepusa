///|
pub(all) enum DeploymentMode {
  FreshInstall
  UpdateInstall
} derive(Debug, Eq)

///|
pub(all) enum DeploymentStepKind {
  ValidateUpdateManifest
  DownloadUpdateArtifact
  VerifyArtifactChecksum
  VerifyArtifactSignature
  StageUpdateArtifact
  BackupCurrentInstall
  InstallUpdateArtifact
  RollbackUpdateArtifact
  RestartApplication
} derive(Debug, Eq)

///|
pub struct DeploymentStep {
  kind : DeploymentStepKind
  artifact_path : String?
  source : String?
  destination : String?
  required : Bool
  description : String
} derive(Debug, Eq)

///|
pub struct DeploymentPlan {
  target : @lepusa.BundleTarget
  mode : DeploymentMode
  identifier : String
  product_name : String
  version : String
  channel : String
  install_root : String
  staging_root : String
  trust : @lepusa.UpdateTrustReport
  steps : Array[DeploymentStep]
} derive(Debug, Eq)

///|
pub fn DeploymentStep::new(
  kind~ : DeploymentStepKind,
  artifact_path? : String,
  source? : String,
  destination? : String,
  required? : Bool = true,
  description~ : String,
) -> DeploymentStep {
  { kind, artifact_path, source, destination, required, description }
}

///|
pub fn DeploymentStepKind::name(self : DeploymentStepKind) -> String {
  match self {
    ValidateUpdateManifest => "validate-update-manifest"
    DownloadUpdateArtifact => "download-update-artifact"
    VerifyArtifactChecksum => "verify-artifact-checksum"
    VerifyArtifactSignature => "verify-artifact-signature"
    StageUpdateArtifact => "stage-update-artifact"
    BackupCurrentInstall => "backup-current-install"
    InstallUpdateArtifact => "install-update-artifact"
    RollbackUpdateArtifact => "rollback-update-artifact"
    RestartApplication => "restart-application"
  }
}

///|
pub fn DeploymentMode::name(self : DeploymentMode) -> String {
  match self {
    FreshInstall => "fresh-install"
    UpdateInstall => "update-install"
  }
}

///|
pub fn DeploymentStep::kind(self : DeploymentStep) -> DeploymentStepKind {
  self.kind
}

///|
pub fn DeploymentStep::artifact_path(self : DeploymentStep) -> String? {
  self.artifact_path
}

///|
pub fn DeploymentStep::source(self : DeploymentStep) -> String? {
  self.source
}

///|
pub fn DeploymentStep::destination(self : DeploymentStep) -> String? {
  self.destination
}

///|
pub fn DeploymentStep::required(self : DeploymentStep) -> Bool {
  self.required
}

///|
pub fn DeploymentStep::description(self : DeploymentStep) -> String {
  self.description
}

///|
pub fn DeploymentStep::to_json(self : DeploymentStep) -> String {
  [
    "{",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"artifactPath\":\{optional_deployment_json_string(self.artifact_path)},",
    "\"source\":\{optional_deployment_json_string(self.source)},",
    "\"destination\":\{optional_deployment_json_string(self.destination)},",
    "\"required\":\{self.required.json_bool()},",
    "\"description\":\{self.description.json_string()}",
    "}",
  ].join("")
}

///|
pub fn DeploymentPlan::from_update_manifest(
  manifest : @lepusa.UpdateManifest,
  target~ : @lepusa.BundleTarget,
  install_root~ : String,
  staging_root~ : String,
  current_version? : String,
  require_signature? : Bool = true,
) -> Result[DeploymentPlan, Array[String]] {
  let problems = deployment_config_problems(
    install_root, staging_root, current_version,
  )
  for problem in manifest.validate() {
    problems.push(problem)
  }
  let trust = manifest.trust_report()
  if require_signature && !trust.trusted() {
    for problem in trust.problems() {
      if !problems.contains(problem) {
        problems.push(problem)
      }
    }
  }
  let artifacts = manifest
    .artifacts()
    .filter(fn(artifact) { artifact.target() == target })
  if artifacts.is_empty() {
    problems.push(
      "deployment update manifest has no artifacts for target: \{target.name()}",
    )
  }
  if problems.is_empty() {
    let mode = if current_version is Some(_) {
      UpdateInstall
    } else {
      FreshInstall
    }
    Ok({
      target,
      mode,
      identifier: manifest.identifier(),
      product_name: manifest.product_name(),
      version: manifest.version(),
      channel: manifest.channel(),
      install_root,
      staging_root,
      trust,
      steps: deployment_steps(
        artifacts,
        install_root,
        staging_root,
        mode~,
        require_signature~,
      ),
    })
  } else {
    Err(problems)
  }
}

///|
pub fn DeploymentPlan::target(self : DeploymentPlan) -> @lepusa.BundleTarget {
  self.target
}

///|
pub fn DeploymentPlan::mode(self : DeploymentPlan) -> DeploymentMode {
  self.mode
}

///|
pub fn DeploymentPlan::identifier(self : DeploymentPlan) -> String {
  self.identifier
}

///|
pub fn DeploymentPlan::product_name(self : DeploymentPlan) -> String {
  self.product_name
}

///|
pub fn DeploymentPlan::version(self : DeploymentPlan) -> String {
  self.version
}

///|
pub fn DeploymentPlan::channel(self : DeploymentPlan) -> String {
  self.channel
}

///|
pub fn DeploymentPlan::install_root(self : DeploymentPlan) -> String {
  self.install_root
}

///|
pub fn DeploymentPlan::staging_root(self : DeploymentPlan) -> String {
  self.staging_root
}

///|
pub fn DeploymentPlan::trust(
  self : DeploymentPlan,
) -> @lepusa.UpdateTrustReport {
  self.trust
}

///|
pub fn DeploymentPlan::steps(self : DeploymentPlan) -> Array[DeploymentStep] {
  self.steps.copy()
}

///|
pub fn DeploymentPlan::steps_by_kind(
  self : DeploymentPlan,
  kind : DeploymentStepKind,
) -> Array[DeploymentStep] {
  self.steps.filter(fn(step) { step.kind() == kind })
}

///|
pub fn DeploymentPlan::required_steps(
  self : DeploymentPlan,
) -> Array[DeploymentStep] {
  self.steps.filter(fn(step) { step.required() })
}

///|
pub fn DeploymentPlan::rollback_steps(
  self : DeploymentPlan,
) -> Array[DeploymentStep] {
  self.steps_by_kind(RollbackUpdateArtifact)
}

///|
pub fn DeploymentPlan::ready(self : DeploymentPlan) -> Bool {
  self.trust.trusted() && !self.steps.is_empty()
}

///|
pub fn DeploymentPlan::summary(self : DeploymentPlan) -> String {
  let lines : Array[String] = [
    "Lepusa deployment plan",
    "identifier: \{self.identifier}",
    "product: \{self.product_name}",
    "target: \{self.target.name()}",
    "mode: \{self.mode.name()}",
    "version: \{self.version}",
    "channel: \{self.channel}",
    "install-root: \{self.install_root}",
    "staging-root: \{self.staging_root}",
    "trusted: \{self.trust.trusted()}",
    "steps: \{self.steps.length()}",
    "required-steps: \{self.required_steps().length()}",
    "rollback-steps: \{self.rollback_steps().length()}",
  ]
  for step in self.steps {
    lines.push(
      "step: \{step.kind().name()} required=\{step.required()} artifact=\{optional_deployment_text(step.artifact_path())}",
    )
  }
  lines.join("\n") + "\n"
}

///|
pub fn DeploymentPlan::to_json(self : DeploymentPlan) -> String {
  [
    "{",
    "\"identifier\":\{self.identifier.json_string()},",
    "\"productName\":\{self.product_name.json_string()},",
    "\"target\":\{self.target.name().json_string()},",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"version\":\{self.version.json_string()},",
    "\"channel\":\{self.channel.json_string()},",
    "\"installRoot\":\{self.install_root.json_string()},",
    "\"stagingRoot\":\{self.staging_root.json_string()},",
    "\"ready\":\{self.ready().json_bool()},",
    "\"trust\":\{self.trust.to_json()},",
    "\"steps\":[\{self.steps.map(fn(step) { step.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn deployment_steps(
  artifacts : Array[@lepusa.UpdateManifestArtifact],
  install_root : String,
  staging_root : String,
  mode~ : DeploymentMode,
  require_signature~ : Bool,
) -> Array[DeploymentStep] {
  let steps = [
    DeploymentStep::new(
      kind=ValidateUpdateManifest,
      description="Validate update metadata, selected target artifacts, checksums, and trust requirements",
    ),
  ]
  for artifact in artifacts {
    let cache_path = deployment_join(
      staging_root,
      "download/\{artifact.path()}",
    )
    let staged_path = deployment_join(
      staging_root,
      "verified/\{artifact.path()}",
    )
    steps.push(
      DeploymentStep::new(
        kind=DownloadUpdateArtifact,
        artifact_path=artifact.path(),
        source=artifact.url(),
        destination=cache_path,
        description="Download update artifact into the deployment staging area",
      ),
    )
    steps.push(
      DeploymentStep::new(
        kind=VerifyArtifactChecksum,
        artifact_path=artifact.path(),
        source=cache_path,
        description="Verify the staged artifact SHA-256 digest before installation",
      ),
    )
    if require_signature || artifact.signature() is Some(_) {
      steps.push(
        DeploymentStep::new(
          kind=VerifyArtifactSignature,
          artifact_path=artifact.path(),
          source=cache_path,
          description="Verify the artifact signature against the update public key",
        ),
      )
    }
    steps.push(
      DeploymentStep::new(
        kind=StageUpdateArtifact,
        artifact_path=artifact.path(),
        source=cache_path,
        destination=staged_path,
        description="Move the verified artifact into the install-ready staging area",
      ),
    )
  }
  if mode is UpdateInstall {
    steps.push(
      DeploymentStep::new(
        kind=BackupCurrentInstall,
        source=install_root,
        destination=deployment_join(staging_root, "backup"),
        description="Capture the current install before replacing native artifacts",
      ),
    )
  }
  for artifact in artifacts {
    let staged_path = deployment_join(
      staging_root,
      "verified/\{artifact.path()}",
    )
    let install_path = deployment_join(install_root, artifact.path())
    steps.push(
      DeploymentStep::new(
        kind=InstallUpdateArtifact,
        artifact_path=artifact.path(),
        source=staged_path,
        destination=install_path,
        description="Install the verified artifact into the native application root",
      ),
    )
    steps.push(
      DeploymentStep::new(
        kind=RollbackUpdateArtifact,
        artifact_path=artifact.path(),
        source=deployment_join(staging_root, "backup/\{artifact.path()}"),
        destination=install_path,
        required=false,
        description="Restore the previous artifact if installation fails after replacement",
      ),
    )
  }
  steps.push(
    DeploymentStep::new(
      kind=RestartApplication,
      required=false,
      description="Restart the application after the transaction commits",
    ),
  )
  steps
}

///|
fn deployment_config_problems(
  install_root : String,
  staging_root : String,
  current_version : String?,
) -> Array[String] {
  let problems : Array[String] = []
  if install_root == "" {
    problems.push("deployment install root is required")
  }
  if staging_root == "" {
    problems.push("deployment staging root is required")
  }
  if install_root != "" && install_root == staging_root {
    problems.push("deployment install root and staging root must be different")
  }
  if current_version is Some("") {
    problems.push("deployment current version must not be empty")
  }
  problems
}

///|
fn deployment_join(root : String, path : String) -> String {
  if root.has_suffix("/") {
    root + path
  } else {
    root + "/" + path
  }
}

///|
fn optional_deployment_json_string(value : String?) -> String {
  match value {
    Some(text) => text.json_string()
    None => "null"
  }
}

///|
fn optional_deployment_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => "-"
  }
}

///|
fn String::json_string(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}

///|
fn Bool::json_bool(self : Bool) -> String {
  if self {
    "true"
  } else {
    "false"
  }
}
