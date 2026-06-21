///|
pub fn UpdateManifest::parse(
  text : String,
) -> Result[UpdateManifest, Array[String]] {
  let json = @json.parse(text) catch {
    error => return Err(["invalid update manifest json: \{error}"])
  }
  match json {
    Object(object) => update_manifest_from_json_object(object)
    _ => Err(["update manifest must be a json object"])
  }
}

///|
fn update_manifest_from_json_object(
  object : Map[String, Json],
) -> Result[UpdateManifest, Array[String]] {
  let problems : Array[String] = []
  update_manifest_schema_version(object, problems)
  let identifier = update_manifest_string(object, "identifier", problems)
  let product_name = update_manifest_string(object, "productName", problems)
  let version = update_manifest_string(object, "version", problems)
  let channel = update_manifest_string(object, "channel", problems)
  let public_key = update_manifest_optional_string(
    object, "publicKey", problems,
  )
  let artifacts = update_manifest_artifacts(object, problems)
  let manifest = UpdateManifest::new(
    identifier~,
    product_name~,
    version~,
    channel~,
    public_key?,
    artifacts~,
  )
  for problem in manifest.validate() {
    if !problems.contains(problem) {
      problems.push(problem)
    }
  }
  if problems.is_empty() {
    Ok(manifest)
  } else {
    Err(problems)
  }
}

///|
fn update_manifest_schema_version(
  object : Map[String, Json],
  problems : Array[String],
) -> Unit {
  match object.get("schemaVersion") {
    Some(Number(value, ..)) =>
      if value.to_int() != 1 {
        problems.push("update schemaVersion must be 1")
      }
    Some(_) => problems.push("update schemaVersion number is required")
    None => problems.push("update schemaVersion number is required")
  }
}

///|
fn update_manifest_string(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> String {
  match object.get(key) {
    Some(String(value)) => {
      if value == "" {
        problems.push("update \{key} must not be empty")
      }
      value
    }
    _ => {
      problems.push("update \{key} string is required")
      ""
    }
  }
}

///|
fn update_manifest_optional_string(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    Some(Null) => None
    Some(_) => {
      problems.push("update \{key} must be a string or null")
      None
    }
    None => None
  }
}

///|
fn update_manifest_artifacts(
  object : Map[String, Json],
  problems : Array[String],
) -> Array[UpdateManifestArtifact] {
  match object.get("artifacts") {
    Some(Array(items)) => {
      let artifacts : Array[UpdateManifestArtifact] = []
      for index, item in items {
        match item {
          Object(artifact) =>
            match update_manifest_artifact(artifact, index, problems) {
              Some(value) => artifacts.push(value)
              None => ()
            }
          _ => problems.push("update artifact must be a json object: \{index}")
        }
      }
      artifacts
    }
    _ => {
      problems.push("update artifacts array is required")
      []
    }
  }
}

///|
fn update_manifest_artifact(
  object : Map[String, Json],
  index : Int,
  problems : Array[String],
) -> UpdateManifestArtifact? {
  let target = update_manifest_target(
    update_manifest_string(object, "target", problems),
    index,
    problems,
  )
  let kind = update_manifest_artifact_kind(
    update_manifest_string(object, "kind", problems),
    index,
    problems,
  )
  let path = update_manifest_string(object, "path", problems)
  let url = update_manifest_string(object, "url", problems)
  let sha256 = update_manifest_string(object, "sha256", problems)
  let signature = update_manifest_optional_string(object, "signature", problems)
  match (target, kind) {
    (Some(target), Some(kind)) =>
      Some(
        UpdateManifestArtifact::new(
          target~,
          kind~,
          path~,
          url~,
          sha256~,
          signature?,
        ),
      )
    _ => None
  }
}

///|
fn update_manifest_target(
  value : String,
  index : Int,
  problems : Array[String],
) -> BundleTarget? {
  match value {
    "macos" => Some(MacOS)
    "windows" => Some(Windows)
    "linux" => Some(Linux)
    "" => None
    _ => {
      problems.push("update artifact target is invalid at \{index}: \{value}")
      None
    }
  }
}

///|
fn update_manifest_artifact_kind(
  value : String,
  index : Int,
  problems : Array[String],
) -> BundleArtifactKind? {
  match value {
    "app-bundle" => Some(AppBundleArtifact)
    "disk-image" => Some(DiskImageArtifact)
    "executable" => Some(ExecutableArtifact)
    "installer" => Some(InstallerArtifact)
    "portable-directory" => Some(PortableDirectoryArtifact)
    "desktop-entry" => Some(DesktopEntryArtifact)
    "" => None
    _ => {
      problems.push("update artifact kind is invalid at \{index}: \{value}")
      None
    }
  }
}
