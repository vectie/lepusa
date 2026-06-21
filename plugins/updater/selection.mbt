///|
pub(all) enum UpdaterDecisionKind {
  UpdateSelected
  NoUpdate
  UpdateRejected
} derive(Debug, Eq)

///|
pub struct UpdaterDecision {
  kind : UpdaterDecisionKind
  current_version : String
  candidate_version : String?
  target : @lepusa.BundleTarget
  artifact_count : Int
  trust : @lepusa.UpdateTrustReport
  reason : String
} derive(Debug, Eq)

///|
priv struct ParsedUpdateVersion {
  major : Int
  minor : Int
  patch : Int
  prerelease : String?
}

///|
pub fn UpdaterPolicy::select_update(
  self : UpdaterPolicy,
  manifest : @lepusa.UpdateManifest,
  current_version~ : String,
  target~ : @lepusa.BundleTarget,
) -> UpdaterDecision {
  let trust = manifest.trust_report()
  let artifacts = manifest
    .artifacts()
    .filter(fn(artifact) { artifact.target() == target })
  let candidate_version = manifest.version()
  match first_problem(self.validate()) {
    Some(problem) =>
      return UpdaterDecision::new(
        kind=UpdateRejected,
        current_version~,
        candidate_version~,
        target~,
        artifact_count=artifacts.length(),
        trust~,
        reason=problem,
      )
    None => ()
  }
  if manifest.channel() != self.channel() {
    return UpdaterDecision::new(
      kind=UpdateRejected,
      current_version~,
      candidate_version~,
      target~,
      artifact_count=artifacts.length(),
      trust~,
      reason="update channel does not match policy: \{manifest.channel()}",
    )
  }
  if !trust.trusted() {
    return UpdaterDecision::new(
      kind=UpdateRejected,
      current_version~,
      candidate_version~,
      target~,
      artifact_count=artifacts.length(),
      trust~,
      reason=trust.problems().join("; "),
    )
  }
  if artifacts.is_empty() {
    return UpdaterDecision::new(
      kind=UpdateRejected,
      current_version~,
      candidate_version~,
      target~,
      artifact_count=0,
      trust~,
      reason="update manifest has no artifact for target: \{target.name()}",
    )
  }
  if !self.allow_prerelease() && update_version_prerelease(candidate_version) {
    return UpdaterDecision::new(
      kind=NoUpdate,
      current_version~,
      candidate_version~,
      target~,
      artifact_count=artifacts.length(),
      trust~,
      reason="update candidate is prerelease and policy disallows prerelease",
    )
  }
  match update_version_compare(candidate_version, current_version) {
    Some(order) =>
      if order > 0 {
        UpdaterDecision::new(
          kind=UpdateSelected,
          current_version~,
          candidate_version~,
          target~,
          artifact_count=artifacts.length(),
          trust~,
          reason="update candidate is newer than current version",
        )
      } else {
        UpdaterDecision::new(
          kind=NoUpdate,
          current_version~,
          candidate_version~,
          target~,
          artifact_count=artifacts.length(),
          trust~,
          reason="update candidate is not newer than current version",
        )
      }
    None =>
      UpdaterDecision::new(
        kind=UpdateRejected,
        current_version~,
        candidate_version~,
        target~,
        artifact_count=artifacts.length(),
        trust~,
        reason="update version comparison requires numeric major.minor.patch versions",
      )
  }
}

///|
pub fn UpdaterDecision::new(
  kind~ : UpdaterDecisionKind,
  current_version~ : String,
  candidate_version? : String,
  target~ : @lepusa.BundleTarget,
  artifact_count~ : Int,
  trust~ : @lepusa.UpdateTrustReport,
  reason~ : String,
) -> UpdaterDecision {
  {
    kind,
    current_version,
    candidate_version,
    target,
    artifact_count,
    trust,
    reason,
  }
}

///|
pub fn UpdaterDecisionKind::name(self : UpdaterDecisionKind) -> String {
  match self {
    UpdateSelected => "update-selected"
    NoUpdate => "no-update"
    UpdateRejected => "update-rejected"
  }
}

///|
pub fn UpdaterDecision::kind(self : UpdaterDecision) -> UpdaterDecisionKind {
  self.kind
}

///|
pub fn UpdaterDecision::update_available(self : UpdaterDecision) -> Bool {
  self.kind is UpdateSelected
}

///|
pub fn UpdaterDecision::current_version(self : UpdaterDecision) -> String {
  self.current_version
}

///|
pub fn UpdaterDecision::candidate_version(self : UpdaterDecision) -> String? {
  self.candidate_version
}

///|
pub fn UpdaterDecision::target(self : UpdaterDecision) -> @lepusa.BundleTarget {
  self.target
}

///|
pub fn UpdaterDecision::artifact_count(self : UpdaterDecision) -> Int {
  self.artifact_count
}

///|
pub fn UpdaterDecision::trust(
  self : UpdaterDecision,
) -> @lepusa.UpdateTrustReport {
  self.trust
}

///|
pub fn UpdaterDecision::reason(self : UpdaterDecision) -> String {
  self.reason
}

///|
pub fn UpdaterDecision::to_json(self : UpdaterDecision) -> String {
  [
    "{",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"updateAvailable\":\{self.update_available().json_bool()},",
    "\"currentVersion\":\{self.current_version.json_string()},",
    "\"candidateVersion\":\{updater_optional_json_string(self.candidate_version)},",
    "\"target\":\{self.target.name().json_string()},",
    "\"artifactCount\":\{self.artifact_count},",
    "\"trust\":\{self.trust.to_json()},",
    "\"reason\":\{self.reason.json_string()}",
    "}",
  ].join("")
}

///|
fn update_version_compare(candidate : String, current : String) -> Int? {
  match (update_version_parse(candidate), update_version_parse(current)) {
    (Some(candidate), Some(current)) =>
      Some(compare_update_versions(candidate, current))
    _ => None
  }
}

///|
fn compare_update_versions(
  candidate : ParsedUpdateVersion,
  current : ParsedUpdateVersion,
) -> Int {
  if candidate.major != current.major {
    candidate.major - current.major
  } else if candidate.minor != current.minor {
    candidate.minor - current.minor
  } else if candidate.patch != current.patch {
    candidate.patch - current.patch
  } else {
    match (candidate.prerelease, current.prerelease) {
      (None, Some(_)) => 1
      (Some(_), None) => -1
      (Some(candidate), Some(current)) => candidate.lexical_compare(current)
      (None, None) => 0
    }
  }
}

///|
fn update_version_parse(value : String) -> ParsedUpdateVersion? {
  let (core, prerelease) = update_version_parts(value)
  let segments : Array[String] = []
  for segment in core.split(".") {
    segments.push(segment.to_owned())
  }
  if segments.length() != 3 {
    return None
  }
  match
    (
      update_version_segment(segments[0]),
      update_version_segment(segments[1]),
      update_version_segment(segments[2]),
    ) {
    (Some(major), Some(minor), Some(patch)) =>
      Some({ major, minor, patch, prerelease })
    _ => None
  }
}

///|
fn update_version_parts(value : String) -> (String, String?) {
  match value.find("-") {
    Some(index) => {
      let core = value[:index].to_owned()
      let prerelease = value[index + 1:].to_owned()
      (core, Some(prerelease))
    }
    None => (value, None)
  }
}

///|
fn update_version_prerelease(value : String) -> Bool {
  value.find("-") is Some(_)
}

///|
fn update_version_segment(value : String) -> Int? {
  if value == "" {
    return None
  }
  let mut number = 0
  for digit in value {
    match update_version_digit(digit) {
      Some(value) => number = number * 10 + value
      None => return None
    }
  }
  Some(number)
}

///|
fn update_version_digit(digit : Char) -> Int? {
  match digit {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    _ => None
  }
}

///|
fn updater_optional_json_string(value : String?) -> String {
  match value {
    Some(text) => text.json_string()
    None => "null"
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
