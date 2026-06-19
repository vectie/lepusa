///|
pub(all) enum BundleTarget {
  MacOS
  Windows
  Linux
} derive(Debug, Eq)

///|
pub struct AppMetadata {
  identifier : String
  product_name : String
  version : String
} derive(Debug, Eq)

///|
pub fn AppMetadata::new(
  identifier~ : String,
  product_name~ : String,
  version~ : String,
) -> AppMetadata {
  { identifier, product_name, version }
}

///|
pub fn AppMetadata::validate(self : AppMetadata) -> Array[String] {
  let problems : Array[String] = []
  if self.identifier == "" {
    problems.push("app identifier is required")
  }
  if self.product_name == "" {
    problems.push("app product name is required")
  }
  if self.version == "" {
    problems.push("app version is required")
  }
  problems
}

///|
pub fn AppMetadata::executable_name(self : AppMetadata) -> String {
  self.product_name.replace_all(old=" ", new="-").to_lower()
}

///|
pub fn AppMetadata::identifier(self : AppMetadata) -> String {
  self.identifier
}

///|
pub fn AppMetadata::product_name(self : AppMetadata) -> String {
  self.product_name
}

///|
pub fn AppMetadata::version(self : AppMetadata) -> String {
  self.version
}

///|
pub struct BundleConfig {
  metadata : AppMetadata
  target : BundleTarget
  icon_path : String?
} derive(Debug, Eq)

///|
pub fn BundleConfig::new(
  metadata : AppMetadata,
  target? : BundleTarget = MacOS,
  icon_path? : String,
) -> BundleConfig {
  { metadata, target, icon_path }
}

///|
pub fn BundleConfig::validate(self : BundleConfig) -> Array[String] {
  self.metadata.validate()
}

///|
pub struct BundlePlan {
  metadata : AppMetadata
  target : BundleTarget
  runtime : RuntimePlan
  executable_name : String
  bundle_name : String
  icon_path : String?
} derive(Debug, Eq)

///|
pub fn BundlePlan::bundle_name(self : BundlePlan) -> String {
  self.bundle_name
}

///|
pub fn BundleTarget::name(self : BundleTarget) -> String {
  match self {
    MacOS => "macos"
    Windows => "windows"
    Linux => "linux"
  }
}

///|
pub fn BundlePlan::target(self : BundlePlan) -> BundleTarget {
  self.target
}

///|
pub fn BundlePlan::identifier(self : BundlePlan) -> String {
  self.metadata.identifier()
}

///|
pub fn BundlePlan::executable_name(self : BundlePlan) -> String {
  self.executable_name
}

///|
pub fn BundleConfig::plan(
  self : BundleConfig,
  runtime : RuntimePlan,
) -> Result[BundlePlan, Array[String]] {
  let problems = self.validate()
  if problems.is_empty() {
    let executable_name = self.metadata.executable_name()
    let extension = match self.target {
      MacOS => ".app"
      Windows => ".exe"
      Linux => ""
    }
    Ok({
      metadata: self.metadata,
      target: self.target,
      runtime,
      executable_name,
      bundle_name: executable_name + extension,
      icon_path: self.icon_path,
    })
  } else {
    Err(problems)
  }
}
