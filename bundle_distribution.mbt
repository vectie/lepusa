///|
pub(all) enum BundleArtifactKind {
  AppBundleArtifact
  DiskImageArtifact
  ExecutableArtifact
  InstallerArtifact
  PortableDirectoryArtifact
  DesktopEntryArtifact
} derive(Debug, Eq)

///|
pub struct BundleArtifact {
  kind : BundleArtifactKind
  path : String
  description : String
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
pub fn BundleArtifact::new(
  kind~ : BundleArtifactKind,
  path~ : String,
  description~ : String,
) -> BundleArtifact {
  { kind, path, description }
}

///|
pub fn BundleArtifact::kind(self : BundleArtifact) -> BundleArtifactKind {
  self.kind
}

///|
pub fn BundleArtifact::path(self : BundleArtifact) -> String {
  self.path
}

///|
pub fn BundleArtifact::description(self : BundleArtifact) -> String {
  self.description
}

///|
pub fn BundleArtifactKind::name(self : BundleArtifactKind) -> String {
  match self {
    AppBundleArtifact => "app-bundle"
    DiskImageArtifact => "disk-image"
    ExecutableArtifact => "executable"
    InstallerArtifact => "installer"
    PortableDirectoryArtifact => "portable-directory"
    DesktopEntryArtifact => "desktop-entry"
  }
}

///|
pub fn BundleArtifact::to_json(self : BundleArtifact) -> String {
  [
    "{",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"path\":\{self.path.json_string()},",
    "\"description\":\{self.description.json_string()}",
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
pub fn BundlePlan::artifacts(self : BundlePlan) -> Array[BundleArtifact] {
  match self.target {
    MacOS =>
      [
        BundleArtifact::new(
          kind=AppBundleArtifact,
          path=self.bundle_name(),
          description="macOS application bundle directory",
        ),
        BundleArtifact::new(
          kind=DiskImageArtifact,
          path="\{self.executable_name}-\{self.metadata.version()}.dmg",
          description="macOS distributable disk image",
        ),
      ]
    Windows =>
      [
        BundleArtifact::new(
          kind=ExecutableArtifact,
          path="\{self.executable_name}/\{self.bundle_name()}",
          description="Windows command launcher executable",
        ),
        BundleArtifact::new(
          kind=InstallerArtifact,
          path="\{self.executable_name}-\{self.metadata.version()}-setup.exe",
          description="Windows installer package",
        ),
      ]
    Linux =>
      [
        BundleArtifact::new(
          kind=PortableDirectoryArtifact,
          path=self.executable_name(),
          description="Linux portable application directory",
        ),
        BundleArtifact::new(
          kind=DesktopEntryArtifact,
          path="\{self.executable_name}/\{self.executable_name}.desktop",
          description="Linux desktop integration entry",
        ),
      ]
  }
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
          description="Apply an Authenticode signature to the Windows launcher artifact",
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
