///|
pub struct BundleDistributionManifest {
  path : String
  identifier : String
  product_name : String
  version : String
  target : String
  executable : String
  bundle : String
  runtime_executable : String
  artifacts : Array[String]
  resources : Array[String]
  runtime_dependencies : Array[String]
  signing : String
  signing_prerequisites : Array[String]
  signing_steps : Array[String]
} derive(Debug, Eq)

///|
pub fn BundleDistributionManifest::parse(
  path : String,
  text : String,
) -> Result[BundleDistributionManifest, String] {
  let json = @json.parse(text) catch {
    error => return Err("invalid distribution json: \{error}")
  }
  match json {
    Object(object) => {
      let problems : Array[String] = []
      let identifier = distribution_manifest_string(
        object, "identifier", problems,
      )
      let product_name = distribution_manifest_string(
        object, "productName", problems,
      )
      let version = distribution_manifest_string(object, "version", problems)
      let target = distribution_manifest_string(object, "target", problems)
      let executable = distribution_manifest_string(
        object, "executable", problems,
      )
      let bundle = distribution_manifest_string(object, "bundle", problems)
      let runtime_executable = distribution_manifest_string(
        object, "runtimeExecutable", problems,
      )
      let artifacts = distribution_manifest_json_array(
        object, "artifacts", problems,
      )
      let resources = distribution_manifest_json_array(
        object, "resources", problems,
      )
      let runtime_dependencies = distribution_manifest_json_array(
        object, "runtimeDependencies", problems,
      )
      let signing = distribution_manifest_json_object(
        object, "signing", problems,
      )
      let signing_prerequisites = distribution_manifest_json_array(
        object, "signingPrerequisites", problems,
      )
      let signing_steps = distribution_manifest_json_array(
        object, "signingSteps", problems,
      )
      if artifacts.is_empty() {
        problems.push("distribution artifacts must not be empty")
      }
      if runtime_dependencies.is_empty() {
        problems.push("distribution runtimeDependencies must not be empty")
      }
      if problems.is_empty() {
        Ok({
          path,
          identifier,
          product_name,
          version,
          target,
          executable,
          bundle,
          runtime_executable,
          artifacts,
          resources,
          runtime_dependencies,
          signing,
          signing_prerequisites,
          signing_steps,
        })
      } else {
        Err(problems.join("; "))
      }
    }
    _ => Err("distribution manifest must be a json object")
  }
}

///|
pub fn BundleDistributionManifest::path(
  self : BundleDistributionManifest,
) -> String {
  self.path
}

///|
pub fn BundleDistributionManifest::identifier(
  self : BundleDistributionManifest,
) -> String {
  self.identifier
}

///|
pub fn BundleDistributionManifest::product_name(
  self : BundleDistributionManifest,
) -> String {
  self.product_name
}

///|
pub fn BundleDistributionManifest::version(
  self : BundleDistributionManifest,
) -> String {
  self.version
}

///|
pub fn BundleDistributionManifest::target(
  self : BundleDistributionManifest,
) -> String {
  self.target
}

///|
pub fn BundleDistributionManifest::executable(
  self : BundleDistributionManifest,
) -> String {
  self.executable
}

///|
pub fn BundleDistributionManifest::bundle(
  self : BundleDistributionManifest,
) -> String {
  self.bundle
}

///|
pub fn BundleDistributionManifest::runtime_executable(
  self : BundleDistributionManifest,
) -> String {
  self.runtime_executable
}

///|
pub fn BundleDistributionManifest::artifacts(
  self : BundleDistributionManifest,
) -> Array[String] {
  self.artifacts.copy()
}

///|
pub fn BundleDistributionManifest::resources(
  self : BundleDistributionManifest,
) -> Array[String] {
  self.resources.copy()
}

///|
pub fn BundleDistributionManifest::runtime_dependencies(
  self : BundleDistributionManifest,
) -> Array[String] {
  self.runtime_dependencies.copy()
}

///|
pub fn BundleDistributionManifest::signing(
  self : BundleDistributionManifest,
) -> String {
  self.signing
}

///|
pub fn BundleDistributionManifest::signing_configured(
  self : BundleDistributionManifest,
) -> Bool {
  self.signing != "{}"
}

///|
pub fn BundleDistributionManifest::signing_prerequisites(
  self : BundleDistributionManifest,
) -> Array[String] {
  self.signing_prerequisites.copy()
}

///|
pub fn BundleDistributionManifest::signing_steps(
  self : BundleDistributionManifest,
) -> Array[String] {
  self.signing_steps.copy()
}

///|
pub fn BundleDistributionManifest::summary(
  self : BundleDistributionManifest,
) -> String {
  "Lepusa distribution\n" +
  "manifest: \{self.path}\n" +
  "identifier: \{self.identifier}\n" +
  "product: \{self.product_name}\n" +
  "version: \{self.version}\n" +
  "target: \{self.target}\n" +
  "executable: \{self.executable}\n" +
  "bundle: \{self.bundle}\n" +
  "runtime-executable: \{self.runtime_executable}\n" +
  "artifacts: \{self.artifacts.length()}\n" +
  "resources: \{self.resources.length()}\n" +
  "runtime-dependencies: \{self.runtime_dependencies.length()}\n" +
  "signing-configured: \{self.signing_configured()}\n" +
  "signing-prerequisites: \{self.signing_prerequisites.length()}\n" +
  "signing-steps: \{self.signing_steps.length()}\n"
}

///|
pub fn BundleDistributionManifest::to_json(
  self : BundleDistributionManifest,
) -> String {
  [
    "{",
    "\"path\":\{self.path.json_string()},",
    "\"identifier\":\{self.identifier.json_string()},",
    "\"productName\":\{self.product_name.json_string()},",
    "\"version\":\{self.version.json_string()},",
    "\"target\":\{self.target.json_string()},",
    "\"executable\":\{self.executable.json_string()},",
    "\"bundle\":\{self.bundle.json_string()},",
    "\"runtimeExecutable\":\{self.runtime_executable.json_string()},",
    "\"artifacts\":[\{self.artifacts.join(",")}],",
    "\"resources\":[\{self.resources.join(",")}],",
    "\"runtimeDependencies\":[\{self.runtime_dependencies.join(",")}],",
    "\"signing\":\{self.signing},",
    "\"signingPrerequisites\":[\{self.signing_prerequisites.join(",")}],",
    "\"signingSteps\":[\{self.signing_steps.join(",")}]",
    "}",
  ].join("")
}

///|
fn distribution_manifest_string(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> String {
  match object.get(key) {
    Some(String(value)) => {
      if value == "" {
        problems.push("distribution \{key} must not be empty")
      }
      value
    }
    _ => {
      problems.push("distribution \{key} string is required")
      ""
    }
  }
}

///|
fn distribution_manifest_json_array(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> Array[String] {
  match object.get(key) {
    Some(Array(value)) => value.map(json_value_string)
    _ => {
      problems.push("distribution \{key} array is required")
      []
    }
  }
}

///|
fn distribution_manifest_json_object(
  object : Map[String, Json],
  key : String,
  problems : Array[String],
) -> String {
  match object.get(key) {
    Some(Object(value)) => json_object_string(value)
    _ => {
      problems.push("distribution \{key} object is required")
      "{}"
    }
  }
}
