///|
pub struct UpdateArtifactTrust {
  path : String
  sha256 : String
  signature : String?
} derive(Debug, Eq)

///|
pub struct UpdateManifestArtifact {
  target : BundleTarget
  kind : BundleArtifactKind
  path : String
  url : String
  sha256 : String
  signature : String?
} derive(Debug, Eq)

///|
pub struct UpdateManifest {
  identifier : String
  product_name : String
  version : String
  channel : String
  public_key : String?
  artifacts : Array[UpdateManifestArtifact]
} derive(Debug, Eq)

///|
pub struct UpdateTrustReport {
  trusted : Bool
  signature_required : Bool
  artifact_count : Int
  signed_artifacts : Int
  problems : Array[String]
} derive(Debug, Eq)

///|
pub fn UpdateArtifactTrust::new(
  path~ : String,
  sha256~ : String,
  signature? : String,
) -> UpdateArtifactTrust {
  { path, sha256, signature }
}

///|
pub fn UpdateArtifactTrust::path(self : UpdateArtifactTrust) -> String {
  self.path
}

///|
pub fn UpdateArtifactTrust::sha256(self : UpdateArtifactTrust) -> String {
  self.sha256
}

///|
pub fn UpdateArtifactTrust::signature(self : UpdateArtifactTrust) -> String? {
  self.signature
}

///|
pub fn UpdateArtifactTrust::validate(
  self : UpdateArtifactTrust,
) -> Array[String] {
  let problems : Array[String] = []
  if self.path == "" {
    problems.push("update artifact trust path is required")
  }
  if !update_sha256_valid(self.sha256) {
    problems.push(
      "update artifact sha256 must be 64 lowercase hex characters: \{self.path}",
    )
  }
  if self.signature is Some("") {
    problems.push("update artifact signature must not be empty: \{self.path}")
  }
  problems
}

///|
pub fn UpdateManifestArtifact::new(
  target~ : BundleTarget,
  kind~ : BundleArtifactKind,
  path~ : String,
  url~ : String,
  sha256~ : String,
  signature? : String,
) -> UpdateManifestArtifact {
  { target, kind, path, url, sha256, signature }
}

///|
pub fn UpdateManifestArtifact::target(
  self : UpdateManifestArtifact,
) -> BundleTarget {
  self.target
}

///|
pub fn UpdateManifestArtifact::kind(
  self : UpdateManifestArtifact,
) -> BundleArtifactKind {
  self.kind
}

///|
pub fn UpdateManifestArtifact::path(self : UpdateManifestArtifact) -> String {
  self.path
}

///|
pub fn UpdateManifestArtifact::url(self : UpdateManifestArtifact) -> String {
  self.url
}

///|
pub fn UpdateManifestArtifact::sha256(self : UpdateManifestArtifact) -> String {
  self.sha256
}

///|
pub fn UpdateManifestArtifact::signature(
  self : UpdateManifestArtifact,
) -> String? {
  self.signature
}

///|
pub fn UpdateManifestArtifact::validate(
  self : UpdateManifestArtifact,
  signature_required? : Bool = false,
) -> Array[String] {
  let problems : Array[String] = []
  if self.path == "" {
    problems.push("update artifact path is required")
  }
  if self.url == "" {
    problems.push("update artifact url is required: \{self.path}")
  } else if !self.url.has_prefix("https://") {
    problems.push("update artifact url must use https: \{self.path}")
  }
  if !update_sha256_valid(self.sha256) {
    problems.push(
      "update artifact sha256 must be 64 lowercase hex characters: \{self.path}",
    )
  }
  match self.signature {
    Some("") =>
      problems.push("update artifact signature must not be empty: \{self.path}")
    Some(_) => ()
    None =>
      if signature_required {
        problems.push("update artifact signature is required: \{self.path}")
      }
  }
  problems
}

///|
pub fn UpdateManifestArtifact::to_json(self : UpdateManifestArtifact) -> String {
  [
    "{",
    "\"target\":\{self.target.name().json_string()},",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"path\":\{self.path.json_string()},",
    "\"url\":\{self.url.json_string()},",
    "\"sha256\":\{self.sha256.json_string()},",
    "\"signature\":\{optional_update_json_string(self.signature)}",
    "}",
  ].join("")
}

///|
pub fn UpdateManifest::new(
  identifier~ : String,
  product_name~ : String,
  version~ : String,
  channel? : String = "stable",
  public_key? : String,
  artifacts~ : Array[UpdateManifestArtifact],
) -> UpdateManifest {
  { identifier, product_name, version, channel, public_key, artifacts }
}

///|
pub fn UpdateManifest::identifier(self : UpdateManifest) -> String {
  self.identifier
}

///|
pub fn UpdateManifest::product_name(self : UpdateManifest) -> String {
  self.product_name
}

///|
pub fn UpdateManifest::version(self : UpdateManifest) -> String {
  self.version
}

///|
pub fn UpdateManifest::channel(self : UpdateManifest) -> String {
  self.channel
}

///|
pub fn UpdateManifest::public_key(self : UpdateManifest) -> String? {
  self.public_key
}

///|
pub fn UpdateManifest::artifacts(
  self : UpdateManifest,
) -> Array[UpdateManifestArtifact] {
  self.artifacts.copy()
}

///|
pub fn UpdateManifest::validate(self : UpdateManifest) -> Array[String] {
  let problems : Array[String] = []
  if self.identifier == "" {
    problems.push("update identifier is required")
  }
  if self.product_name == "" {
    problems.push("update product name is required")
  }
  if self.version == "" {
    problems.push("update version is required")
  }
  if !update_channel_valid(self.channel) {
    problems.push("update channel is invalid: \{self.channel}")
  }
  if self.public_key is Some("") {
    problems.push("update public key must not be empty")
  }
  if self.artifacts.is_empty() {
    problems.push("update artifacts must not be empty")
  }
  let signature_required = self.public_key is Some(_)
  for artifact in self.artifacts {
    for problem in artifact.validate(signature_required~) {
      problems.push(problem)
    }
  }
  problems
}

///|
pub fn UpdateManifest::trust_report(self : UpdateManifest) -> UpdateTrustReport {
  let problems = self.validate()
  let signature_required = self.public_key is Some(_)
  let mut signed_artifacts = 0
  for artifact in self.artifacts {
    if artifact.signature() is Some(_) {
      signed_artifacts += 1
    }
  }
  if !signature_required {
    problems.push("update public key is required for trusted native updates")
  }
  {
    trusted: problems.is_empty(),
    signature_required,
    artifact_count: self.artifacts.length(),
    signed_artifacts,
    problems,
  }
}

///|
pub fn UpdateManifest::to_json(self : UpdateManifest) -> String {
  [
    "{",
    "\"schemaVersion\":1,",
    "\"identifier\":\{self.identifier.json_string()},",
    "\"productName\":\{self.product_name.json_string()},",
    "\"version\":\{self.version.json_string()},",
    "\"channel\":\{self.channel.json_string()},",
    "\"publicKey\":\{optional_update_json_string(self.public_key)},",
    "\"artifacts\":[\{self.artifacts.map(fn(artifact) { artifact.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn UpdateTrustReport::trusted(self : UpdateTrustReport) -> Bool {
  self.trusted
}

///|
pub fn UpdateTrustReport::signature_required(self : UpdateTrustReport) -> Bool {
  self.signature_required
}

///|
pub fn UpdateTrustReport::artifact_count(self : UpdateTrustReport) -> Int {
  self.artifact_count
}

///|
pub fn UpdateTrustReport::signed_artifacts(self : UpdateTrustReport) -> Int {
  self.signed_artifacts
}

///|
pub fn UpdateTrustReport::problems(self : UpdateTrustReport) -> Array[String] {
  self.problems.copy()
}

///|
pub fn UpdateTrustReport::to_json(self : UpdateTrustReport) -> String {
  [
    "{",
    "\"trusted\":\{self.trusted.json_bool()},",
    "\"signatureRequired\":\{self.signature_required.json_bool()},",
    "\"artifactCount\":\{self.artifact_count},",
    "\"signedArtifacts\":\{self.signed_artifacts},",
    "\"problems\":[\{self.problems.map(fn(problem) { problem.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn BundlePlan::update_manifest(
  self : BundlePlan,
  base_url~ : String,
  channel? : String = "stable",
  public_key? : String,
  artifact_trust? : Array[UpdateArtifactTrust] = [],
) -> Result[UpdateManifest, Array[String]] {
  let problems : Array[String] = []
  if base_url == "" {
    problems.push("update base url is required")
  } else if !base_url.has_prefix("https://") {
    problems.push("update base url must use https")
  }
  let artifact_paths = self.artifacts().map(fn(artifact) { artifact.path() })
  let trust_paths : Array[String] = []
  for trust in artifact_trust {
    for problem in trust.validate() {
      problems.push(problem)
    }
    if trust.path() != "" && trust_paths.contains(trust.path()) {
      problems.push(
        "update artifact trust path must be unique: \{trust.path()}",
      )
    } else {
      trust_paths.push(trust.path())
    }
    if trust.path() != "" && !artifact_paths.contains(trust.path()) {
      problems.push(
        "update artifact trust path is not a bundle artifact: \{trust.path()}",
      )
    }
  }
  let update_artifacts : Array[UpdateManifestArtifact] = []
  for artifact in self.artifacts() {
    match update_trust_for_path(artifact_trust, artifact.path()) {
      Some(trust) =>
        update_artifacts.push(
          UpdateManifestArtifact::new(
            target=self.target(),
            kind=artifact.kind(),
            path=artifact.path(),
            url=update_artifact_url(base_url, artifact.path()),
            sha256=trust.sha256(),
            signature?=trust.signature(),
          ),
        )
      None =>
        problems.push("update artifact trust is missing: \{artifact.path()}")
    }
  }
  let manifest = UpdateManifest::new(
    identifier=self.identifier(),
    product_name=self.metadata.product_name(),
    version=self.metadata.version(),
    channel~,
    public_key?,
    artifacts=update_artifacts,
  )
  for problem in manifest.validate() {
    problems.push(problem)
  }
  if problems.is_empty() {
    Ok(manifest)
  } else {
    Err(problems)
  }
}

///|
pub fn BundlePlan::update_manifest_json(
  self : BundlePlan,
  base_url~ : String,
  channel? : String = "stable",
  public_key? : String,
  artifact_trust? : Array[UpdateArtifactTrust] = [],
) -> Result[String, Array[String]] {
  match
    self.update_manifest(base_url~, channel~, public_key?, artifact_trust~) {
    Ok(manifest) => Ok(manifest.to_json())
    Err(problems) => Err(problems)
  }
}

///|
fn update_trust_for_path(
  trusts : Array[UpdateArtifactTrust],
  path : String,
) -> UpdateArtifactTrust? {
  for trust in trusts {
    if trust.path() == path {
      return Some(trust)
    }
  }
  None
}

///|
fn update_artifact_url(base_url : String, path : String) -> String {
  if base_url.has_suffix("/") {
    base_url + path
  } else {
    base_url + "/" + path
  }
}

///|
fn update_sha256_valid(value : String) -> Bool {
  value.length() == 64 &&
  value
  .to_lower()
  .replace_all(old="0", new="")
  .replace_all(old="1", new="")
  .replace_all(old="2", new="")
  .replace_all(old="3", new="")
  .replace_all(old="4", new="")
  .replace_all(old="5", new="")
  .replace_all(old="6", new="")
  .replace_all(old="7", new="")
  .replace_all(old="8", new="")
  .replace_all(old="9", new="")
  .replace_all(old="a", new="")
  .replace_all(old="b", new="")
  .replace_all(old="c", new="")
  .replace_all(old="d", new="")
  .replace_all(old="e", new="")
  .replace_all(old="f", new="")
  .is_empty()
}

///|
fn update_channel_valid(channel : String) -> Bool {
  channel == "stable" ||
  channel == "beta" ||
  channel == "nightly" ||
  channel == "dev"
}

///|
fn optional_update_json_string(value : String?) -> String {
  match value {
    Some(text) => text.json_string()
    None => "null"
  }
}
