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
  runtime_dependency_sources : Array[BundleRuntimeDependencySource]
  signing : SigningConfig
} derive(Debug, Eq)

///|
pub fn BundleConfig::new(
  metadata : AppMetadata,
  target? : BundleTarget = MacOS,
  icon_path? : String,
  runtime_dependency_sources? : Array[BundleRuntimeDependencySource] = [],
  signing? : SigningConfig = SigningConfig::new(),
) -> BundleConfig {
  { metadata, target, icon_path, runtime_dependency_sources, signing }
}

///|
pub fn BundleConfig::validate(self : BundleConfig) -> Array[String] {
  let problems = self.metadata.validate()
  validate_runtime_dependency_sources(self.runtime_dependency_sources, problems)
  for problem in self.signing.validate() {
    problems.push(problem)
  }
  problems
}

///|
pub struct BundleRuntimeDependencySource {
  name : String
  source_path : String
} derive(Debug, Eq)

///|
pub fn BundleRuntimeDependencySource::new(
  name~ : String,
  source_path~ : String,
) -> BundleRuntimeDependencySource {
  { name, source_path }
}

///|
pub fn BundleRuntimeDependencySource::name(
  self : BundleRuntimeDependencySource,
) -> String {
  self.name
}

///|
pub fn BundleRuntimeDependencySource::source_path(
  self : BundleRuntimeDependencySource,
) -> String {
  self.source_path
}

///|
fn validate_runtime_dependency_sources(
  sources : Array[BundleRuntimeDependencySource],
  problems : Array[String],
) -> Unit {
  let names : Array[String] = []
  for source in sources {
    if source.name() == "" {
      problems.push("runtime dependency source name must not be empty")
    } else if names.contains(source.name()) {
      problems.push(
        "runtime dependency source must be unique: \{source.name()}",
      )
    } else {
      names.push(source.name())
    }
    if source.source_path() == "" {
      problems.push("runtime dependency source path must not be empty")
    }
  }
}

///|
pub struct BundlePlan {
  metadata : AppMetadata
  target : BundleTarget
  runtime : RuntimePlan
  registered_routes : Array[String]
  executable_name : String
  bundle_name : String
  icon_path : String?
  runtime_dependency_sources : Array[BundleRuntimeDependencySource]
  signing : SigningConfig
} derive(Debug, Eq)

///|
pub(all) enum BundleResourceKind {
  IconResource
  AssetResource
} derive(Debug, Eq)

///|
pub struct BundleResource {
  kind : BundleResourceKind
  source_path : String
  path : String
} derive(Debug, Eq)

///|
pub struct BundleFile {
  path : String
  content : String
  executable : Bool
} derive(Debug, Eq)

///|
pub fn BundleFile::new(
  path~ : String,
  content~ : String,
  executable? : Bool = false,
) -> BundleFile {
  { path, content, executable }
}

///|
pub fn BundleResource::new(
  kind~ : BundleResourceKind,
  source_path~ : String,
  path~ : String,
) -> BundleResource {
  { kind, source_path, path }
}

///|
pub fn BundleResource::kind(self : BundleResource) -> BundleResourceKind {
  self.kind
}

///|
pub fn BundleResource::source_path(self : BundleResource) -> String {
  self.source_path
}

///|
pub fn BundleResource::path(self : BundleResource) -> String {
  self.path
}

///|
pub fn BundleResourceKind::name(self : BundleResourceKind) -> String {
  match self {
    IconResource => "icon"
    AssetResource => "asset"
  }
}

///|
pub fn BundleResource::to_json(self : BundleResource) -> String {
  [
    "{",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"sourcePath\":\{self.source_path.json_string()},",
    "\"path\":\{self.path.json_string()}",
    "}",
  ].join("")
}

///|
pub fn BundleFile::path(self : BundleFile) -> String {
  self.path
}

///|
pub fn BundleFile::content(self : BundleFile) -> String {
  self.content
}

///|
pub fn BundleFile::executable(self : BundleFile) -> Bool {
  self.executable
}

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
pub fn BundlePlan::registered_routes(self : BundlePlan) -> Array[String] {
  self.registered_routes.copy()
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
pub fn BundlePlan::runtime_executable_name(self : BundlePlan) -> String {
  match self.target {
    Windows => "lepusa-runtime.exe"
    _ => "lepusa-runtime"
  }
}

///|
pub fn BundlePlan::runtime_executable_path(self : BundlePlan) -> String {
  match self.target {
    MacOS =>
      "\{self.bundle_name()}/Contents/MacOS/\{self.runtime_executable_name()}"
    Windows => "\{self.executable_name()}/\{self.runtime_executable_name()}"
    Linux => "\{self.executable_name()}/\{self.runtime_executable_name()}"
  }
}

///|
pub fn BundlePlan::icon_path(self : BundlePlan) -> String? {
  self.icon_path
}

///|
pub fn BundlePlan::runtime_dependency_sources(
  self : BundlePlan,
) -> Array[BundleRuntimeDependencySource] {
  self.runtime_dependency_sources.copy()
}

///|
pub fn BundlePlan::resources(self : BundlePlan) -> Array[BundleResource] {
  let resources = self.asset_resources()
  match self.icon_path {
    Some(source_path) =>
      resources.push(
        BundleResource::new(
          kind=IconResource,
          source_path~,
          path=self.icon_resource_path(),
        ),
      )
    None => ()
  }
  resources
}

///|
fn BundlePlan::asset_resources(self : BundlePlan) -> Array[BundleResource] {
  let resources : Array[BundleResource] = []
  for window in self.runtime.windows() {
    for mapping in window.source().protocol_mappings() {
      if mapping.root().has_prefix("package:") {
        resources.push(
          BundleResource::new(
            kind=AssetResource,
            source_path=mapping.root()[8:].to_owned(),
            path=self.packaged_asset_resource_path(window.label()),
          ),
        )
      }
    }
  }
  resources
}

///|
pub fn BundlePlan::files(
  self : BundlePlan,
) -> Result[Array[BundleFile], Array[String]] {
  match self.runtime_manifest_file_json() {
    Ok(runtime_manifest_file) => {
      let files : Array[BundleFile] = []
      for file in self.platform_files() {
        files.push(file)
      }
      files.push(
        BundleFile::new(
          path=self.shared_path("lepusa/runtime.json"),
          content=runtime_manifest_file,
        ),
      )
      files.push(
        BundleFile::new(
          path=self.shared_path("lepusa/distribution.json"),
          content=self.distribution_manifest_json(),
        ),
      )
      Ok(files)
    }
    Err(problems) => Err(problems)
  }
}

///|
fn BundlePlan::shared_path(self : BundlePlan, path : String) -> String {
  match self.target {
    MacOS => "\{self.bundle_name}/Contents/Resources/\{path}"
    Windows => "\{self.executable_name}/\{path}"
    Linux => "\{self.executable_name}/\{path}"
  }
}

///|
fn BundlePlan::icon_resource_path(self : BundlePlan) -> String {
  match self.target {
    MacOS => "\{self.bundle_name}/Contents/Resources/AppIcon.icns"
    Windows => "\{self.executable_name}/app.ico"
    Linux => "\{self.executable_name}/\{self.executable_name}.png"
  }
}

///|
pub fn BundlePlan::runtime_manifest(
  self : BundlePlan,
) -> Result[RuntimeLaunchManifest, Array[String]] {
  match
    self.runtime.launch_manifest(
      registered_routes=self.registered_routes,
      restrict_registered=true,
    ) {
    Ok(manifest) => Ok(with_bundle_packaged_roots(manifest))
    Err(problems) => Err(problems)
  }
}

///|
pub fn BundlePlan::runtime_manifest_json(
  self : BundlePlan,
) -> Result[String, Array[String]] {
  match self.runtime_manifest() {
    Ok(runtime_manifest) => Ok(runtime_manifest.to_json())
    Err(problems) => Err(problems)
  }
}

///|
pub fn BundlePlan::distribution_manifest_json(self : BundlePlan) -> String {
  [
    "{",
    "\"identifier\":\{self.identifier().json_string()},",
    "\"productName\":\{self.metadata.product_name().json_string()},",
    "\"version\":\{self.metadata.version().json_string()},",
    "\"target\":\{self.target.name().json_string()},",
    "\"executable\":\{self.executable_name().json_string()},",
    "\"bundle\":\{self.bundle_name().json_string()},",
    "\"runtimeExecutable\":\{self.runtime_executable_path().json_string()},",
    "\"artifacts\":[\{self.artifacts().map(fn(artifact) { artifact.to_json() }).join(",")}],",
    "\"resources\":[\{self.resources().map(fn(resource) { resource.to_json() }).join(",")}],",
    "\"runtimeDependencies\":[\{self.runtime_dependencies().map(fn(dependency) { dependency.to_json() }).join(",")}],",
    "\"signing\":\{self.signing.to_json()},",
    "\"signingPrerequisites\":[\{self.signing_prerequisites().map(fn(item) { item.to_json() }).join(",")}],",
    "\"signingSteps\":[\{self.signing_steps().map(fn(step) { step.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn with_bundle_packaged_roots(
  manifest : RuntimeLaunchManifest,
) -> RuntimeLaunchManifest {
  let protocol_mappings : Array[RuntimeProtocolBinding] = []
  for binding in manifest.protocol_mappings {
    if binding.root.has_prefix("package:") {
      protocol_mappings.push({
        ..binding,
        root: "package:\{packaged_asset_runtime_root(binding.window_label)}",
      })
    } else {
      protocol_mappings.push(binding)
    }
  }
  { ..manifest, protocol_mappings, }
}

///|
fn packaged_asset_runtime_root(window_label : String) -> String {
  "lepusa/assets/\{window_label.to_asset_segment()}"
}

///|
fn BundlePlan::packaged_asset_resource_path(
  self : BundlePlan,
  window_label : String,
) -> String {
  self.shared_path(packaged_asset_runtime_root(window_label))
}

///|
fn BundlePlan::runtime_manifest_file_json(
  self : BundlePlan,
) -> Result[String, Array[String]] {
  match self.runtime_manifest_json() {
    Ok(runtime_manifest) =>
      Ok(
        [
          "{",
          "\"identifier\":\{self.identifier().json_string()},",
          "\"productName\":\{self.metadata.product_name().json_string()},",
          "\"version\":\{self.metadata.version().json_string()},",
          "\"target\":\{self.target.name().json_string()},",
          "\"artifacts\":[\{self.artifacts().map(fn(artifact) { artifact.to_json() }).join(",")}],",
          "\"resources\":[\{self.resources().map(fn(resource) { resource.to_json() }).join(",")}],",
          "\"runtimeDependencies\":[\{self.runtime_dependencies().map(fn(dependency) { dependency.to_json() }).join(",")}],",
          "\"signing\":\{self.signing.to_json()},",
          "\"signingPrerequisites\":[\{self.signing_prerequisites().map(fn(item) { item.to_json() }).join(",")}],",
          "\"signingSteps\":[\{self.signing_steps().map(fn(step) { step.to_json() }).join(",")}],",
          "\"runtime\":\{runtime_manifest}",
          "}",
        ].join(""),
      )
    Err(problems) => Err(problems)
  }
}

///|
pub fn BundleConfig::plan(
  self : BundleConfig,
  runtime : RuntimePlan,
  registered_routes? : Array[String] = [],
) -> Result[BundlePlan, Array[String]] {
  let problems = self.validate()
  if problems.is_empty() {
    let executable_name = self.metadata.executable_name()
    let extension = match self.target {
      MacOS => ".app"
      Windows => ".cmd"
      Linux => ""
    }
    Ok({
      metadata: self.metadata,
      target: self.target,
      runtime,
      registered_routes: registered_routes.copy(),
      executable_name,
      bundle_name: executable_name + extension,
      icon_path: self.icon_path,
      runtime_dependency_sources: self.runtime_dependency_sources.copy(),
      signing: self.signing,
    })
  } else {
    Err(problems)
  }
}

///|
