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
  signing : SigningConfig
} derive(Debug, Eq)

///|
pub fn BundleConfig::new(
  metadata : AppMetadata,
  target? : BundleTarget = MacOS,
  icon_path? : String,
  signing? : SigningConfig = SigningConfig::new(),
) -> BundleConfig {
  { metadata, target, icon_path, signing }
}

///|
pub fn BundleConfig::validate(self : BundleConfig) -> Array[String] {
  let problems = self.metadata.validate()
  for problem in self.signing.validate() {
    problems.push(problem)
  }
  problems
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
pub(all) enum SigningPrerequisiteKind {
  SigningIdentity
  SigningTool
  NotarizationTool
  RuntimeDependency
  PackageValidator
} derive(Debug, Eq)

///|
pub struct SigningPrerequisite {
  kind : SigningPrerequisiteKind
  name : String
  description : String
} derive(Debug, Eq)

///|
pub struct SigningStep {
  name : String
  tool : String
  arguments : Array[String]
  description : String
} derive(Debug, Eq)

///|
pub struct SigningConfig {
  identity : String?
  team_id : String?
  entitlements_path : String?
  notarization_profile : String?
  timestamp_url : String?
} derive(Debug, Eq)

///|
pub fn SigningConfig::new(
  identity? : String,
  team_id? : String,
  entitlements_path? : String,
  notarization_profile? : String,
  timestamp_url? : String,
) -> SigningConfig {
  { identity, team_id, entitlements_path, notarization_profile, timestamp_url }
}

///|
pub fn SigningConfig::identity(self : SigningConfig) -> String? {
  self.identity
}

///|
pub fn SigningConfig::team_id(self : SigningConfig) -> String? {
  self.team_id
}

///|
pub fn SigningConfig::entitlements_path(self : SigningConfig) -> String? {
  self.entitlements_path
}

///|
pub fn SigningConfig::notarization_profile(self : SigningConfig) -> String? {
  self.notarization_profile
}

///|
pub fn SigningConfig::timestamp_url(self : SigningConfig) -> String? {
  self.timestamp_url
}

///|
pub fn SigningConfig::validate(self : SigningConfig) -> Array[String] {
  let problems : Array[String] = []
  if self.identity is Some("") {
    problems.push("signing identity must not be empty")
  }
  if self.team_id is Some("") {
    problems.push("signing team id must not be empty")
  }
  if self.entitlements_path is Some("") {
    problems.push("signing entitlements path must not be empty")
  }
  if self.notarization_profile is Some("") {
    problems.push("signing notarization profile must not be empty")
  }
  if self.timestamp_url is Some("") {
    problems.push("signing timestamp url must not be empty")
  }
  problems
}

///|
pub fn SigningConfig::configured(self : SigningConfig) -> Bool {
  self.identity is Some(_) ||
  self.team_id is Some(_) ||
  self.entitlements_path is Some(_) ||
  self.notarization_profile is Some(_) ||
  self.timestamp_url is Some(_)
}

///|
pub fn SigningConfig::to_json(self : SigningConfig) -> String {
  let fields : Array[String] = []
  match self.identity {
    Some(value) => fields.push("\"identity\":\{value.json_string()}")
    None => ()
  }
  match self.team_id {
    Some(value) => fields.push("\"teamId\":\{value.json_string()}")
    None => ()
  }
  match self.entitlements_path {
    Some(value) => fields.push("\"entitlements\":\{value.json_string()}")
    None => ()
  }
  match self.notarization_profile {
    Some(value) => fields.push("\"notarizationProfile\":\{value.json_string()}")
    None => ()
  }
  match self.timestamp_url {
    Some(value) => fields.push("\"timestampUrl\":\{value.json_string()}")
    None => ()
  }
  "{\{fields.join(",")}}"
}

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
pub fn SigningPrerequisite::new(
  kind~ : SigningPrerequisiteKind,
  name~ : String,
  description~ : String,
) -> SigningPrerequisite {
  { kind, name, description }
}

///|
pub fn SigningPrerequisite::kind(
  self : SigningPrerequisite,
) -> SigningPrerequisiteKind {
  self.kind
}

///|
pub fn SigningPrerequisite::name(self : SigningPrerequisite) -> String {
  self.name
}

///|
pub fn SigningPrerequisite::description(self : SigningPrerequisite) -> String {
  self.description
}

///|
pub fn SigningPrerequisiteKind::name(self : SigningPrerequisiteKind) -> String {
  match self {
    SigningIdentity => "signing-identity"
    SigningTool => "signing-tool"
    NotarizationTool => "notarization-tool"
    RuntimeDependency => "runtime-dependency"
    PackageValidator => "package-validator"
  }
}

///|
pub fn SigningPrerequisite::to_json(self : SigningPrerequisite) -> String {
  [
    "{",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"name\":\{self.name.json_string()},",
    "\"description\":\{self.description.json_string()}",
    "}",
  ].join("")
}

///|
pub fn SigningStep::new(
  name~ : String,
  tool~ : String,
  arguments~ : Array[String],
  description~ : String,
) -> SigningStep {
  { name, tool, arguments, description }
}

///|
pub fn SigningStep::name(self : SigningStep) -> String {
  self.name
}

///|
pub fn SigningStep::tool(self : SigningStep) -> String {
  self.tool
}

///|
pub fn SigningStep::arguments(self : SigningStep) -> Array[String] {
  self.arguments.copy()
}

///|
pub fn SigningStep::description(self : SigningStep) -> String {
  self.description
}

///|
pub fn SigningStep::to_json(self : SigningStep) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"tool\":\{self.tool.json_string()},",
    "\"arguments\":[\{self.arguments.map(fn(argument) { argument.json_string() }).join(",")}],",
    "\"description\":\{self.description.json_string()}",
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
pub fn BundlePlan::icon_path(self : BundlePlan) -> String? {
  self.icon_path
}

///|
pub fn BundlePlan::signing(self : BundlePlan) -> SigningConfig {
  self.signing
}

///|
pub fn BundlePlan::signing_steps(self : BundlePlan) -> Array[SigningStep] {
  match self.target {
    MacOS => self.macos_signing_steps()
    Windows => self.windows_signing_steps()
    Linux => self.linux_signing_steps()
  }
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
pub fn BundlePlan::signing_prerequisites(
  self : BundlePlan,
) -> Array[SigningPrerequisite] {
  match self.target {
    MacOS =>
      [
        SigningPrerequisite::new(
          kind=SigningIdentity,
          name="Developer ID Application certificate",
          description="Required to sign distributable macOS apps outside the Mac App Store",
        ),
        SigningPrerequisite::new(
          kind=SigningTool,
          name="codesign",
          description="Required to apply the app signature and hardened runtime options",
        ),
        SigningPrerequisite::new(
          kind=NotarizationTool,
          name="notarytool",
          description="Required to submit signed macOS apps for Apple notarization",
        ),
      ]
    Windows =>
      [
        SigningPrerequisite::new(
          kind=SigningIdentity,
          name="code signing certificate",
          description="Required to sign Windows executables and installers",
        ),
        SigningPrerequisite::new(
          kind=SigningTool,
          name="signtool",
          description="Required to apply Authenticode signatures",
        ),
        SigningPrerequisite::new(
          kind=RuntimeDependency,
          name="WebView2 Runtime",
          description="Required on target machines unless bundled by the installer",
        ),
      ]
    Linux => {
      let prerequisites = [
        SigningPrerequisite::new(
          kind=SigningIdentity,
          name="package signing key",
          description="Required for signed deb, rpm, or repository distribution",
        ),
        SigningPrerequisite::new(
          kind=PackageValidator,
          name="desktop-file-validate",
          description="Required to validate Linux desktop integration metadata",
        ),
      ]
      if self.signing.identity() is Some(_) {
        prerequisites.push(
          SigningPrerequisite::new(
            kind=SigningTool,
            name="gpg",
            description="Required to create detached package signatures from configured signing identity",
          ),
        )
      }
      prerequisites
    }
  }
}

///|
fn BundlePlan::macos_signing_steps(self : BundlePlan) -> Array[SigningStep] {
  let steps : Array[SigningStep] = []
  match self.signing.identity() {
    Some(identity) => {
      let arguments = [
        "--force", "--deep", "--options", "runtime", "--sign", identity,
      ]
      match self.signing.entitlements_path() {
        Some(path) => {
          arguments.push("--entitlements")
          arguments.push(path)
        }
        None => ()
      }
      arguments.push(self.bundle_name())
      steps.push(
        SigningStep::new(
          name="codesign-app",
          tool="codesign",
          arguments~,
          description="Apply a hardened-runtime signature to the macOS app bundle",
        ),
      )
    }
    None => ()
  }
  match self.signing.notarization_profile() {
    Some(profile) =>
      steps.push(
        SigningStep::new(
          name="notarize-app",
          tool="xcrun",
          arguments=[
            "notarytool",
            "submit",
            self.bundle_name(),
            "--keychain-profile",
            profile,
            "--wait",
          ],
          description="Submit the signed macOS app bundle for notarization",
        ),
      )
    None => ()
  }
  steps
}

///|
fn BundlePlan::windows_signing_steps(self : BundlePlan) -> Array[SigningStep] {
  let steps : Array[SigningStep] = []
  match self.signing.identity() {
    Some(identity) => {
      let arguments = ["sign", "/fd", "SHA256", "/n", identity]
      match self.signing.timestamp_url() {
        Some(url) => {
          arguments.push("/tr")
          arguments.push(url)
          arguments.push("/td")
          arguments.push("SHA256")
        }
        None => ()
      }
      arguments.push(self.bundle_name())
      steps.push(
        SigningStep::new(
          name="sign-executable",
          tool="signtool",
          arguments~,
          description="Apply an Authenticode signature to the Windows executable",
        ),
      )
    }
    None => ()
  }
  steps
}

///|
fn BundlePlan::linux_signing_steps(self : BundlePlan) -> Array[SigningStep] {
  let steps : Array[SigningStep] = []
  match self.signing.identity() {
    Some(identity) =>
      steps.push(
        SigningStep::new(
          name="sign-package",
          tool="gpg",
          arguments=[
            "--detach-sign",
            "--local-user",
            identity,
            self.executable_name(),
          ],
          description="Create a detached signature for the Linux package artifact",
        ),
      )
    None => ()
  }
  steps
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
fn BundlePlan::platform_files(self : BundlePlan) -> Array[BundleFile] {
  match self.target {
    MacOS =>
      [
        BundleFile::new(
          path="\{self.bundle_name}/Contents/Info.plist",
          content=self.info_plist(),
        ),
        BundleFile::new(
          path="\{self.bundle_name}/Contents/MacOS/\{self.executable_name}",
          content=macos_launcher(),
          executable=true,
        ),
      ]
    Windows =>
      [
        BundleFile::new(
          path="\{self.executable_name}/app.manifest.xml",
          content=self.windows_manifest(),
        ),
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}.cmd",
          content=windows_launcher(),
        ),
      ]
    Linux =>
      [
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}.desktop",
          content=self.desktop_entry(),
        ),
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}",
          content=linux_launcher(),
          executable=true,
        ),
      ]
  }
}

///|
pub fn BundlePlan::runtime_manifest(
  self : BundlePlan,
) -> Result[RuntimeLaunchManifest, Array[String]] {
  match self.runtime.launch_manifest(registered_routes=self.registered_routes) {
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
          "\"resources\":[\{self.resources().map(fn(resource) { resource.to_json() }).join(",")}],",
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
fn BundlePlan::info_plist(self : BundlePlan) -> String {
  let identifier = self.identifier().xml_escape()
  let product = self.metadata.product_name().xml_escape()
  let version = self.metadata.version().xml_escape()
  let executable = self.executable_name.xml_escape()
  [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" ",
    "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
    "<plist version=\"1.0\"><dict>",
    "<key>CFBundleIdentifier</key><string>\{identifier}</string>",
    "<key>CFBundleName</key><string>\{product}</string>",
    "<key>CFBundleDisplayName</key><string>\{product}</string>",
    "<key>CFBundleExecutable</key><string>\{executable}</string>",
    "<key>CFBundleShortVersionString</key><string>\{version}</string>",
    "<key>CFBundleVersion</key><string>\{version}</string>",
    if self.icon_path is Some(_) {
      "<key>CFBundleIconFile</key><string>AppIcon</string>"
    } else {
      ""
    },
    "</dict></plist>\n",
  ].join("")
}

///|
fn BundlePlan::windows_manifest(self : BundlePlan) -> String {
  let identifier = self.identifier().xml_escape()
  let product = self.metadata.product_name().xml_escape()
  [
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
    "<assembly xmlns=\"urn:schemas-microsoft-com:asm.v1\" manifestVersion=\"1.0\">",
    "<assemblyIdentity version=\"1.0.0.0\" processorArchitecture=\"*\" ",
    "name=\"\{identifier}\" type=\"win32\"/>",
    "<description>\{product}</description>",
    "</assembly>\n",
  ].join("")
}

///|
fn BundlePlan::desktop_entry(self : BundlePlan) -> String {
  [
    "[Desktop Entry]",
    "Type=Application",
    "Name=\{self.metadata.product_name()}",
    "Exec=\{self.executable_name}",
    "Icon=\{self.executable_name}",
    "Categories=Utility;",
    "",
  ].join("\n")
}

///|
fn macos_launcher() -> String {
  (
    #|#!/bin/sh
    #|APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
    #|exec lepusa-runtime launch --manifest "$APP_DIR/Resources/lepusa/runtime.json" "$@"
    #|
  )
}

///|
fn windows_launcher() -> String {
  (
    #|@echo off
    #|set "APP_DIR=%~dp0"
    #|lepusa-runtime.exe launch --manifest "%APP_DIR%lepusa\runtime.json" %*
    #|
  )
}

///|
fn linux_launcher() -> String {
  (
    #|#!/bin/sh
    #|APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    #|exec lepusa-runtime launch --manifest "$APP_DIR/lepusa/runtime.json" "$@"
    #|
  )
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
      Windows => ".exe"
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
      signing: self.signing,
    })
  } else {
    Err(problems)
  }
}

///|
fn String::xml_escape(self : String) -> String {
  self
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}
