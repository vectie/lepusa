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
  registered_routes : Array[String]
  executable_name : String
  bundle_name : String
  icon_path : String?
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
            path=self.shared_path(
              "lepusa/assets/\{window.label().to_asset_segment()}",
            ),
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
    Linux =>
      [
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
  }
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
          content="#!/bin/sh\nexec lepusa-runtime \"$@\"\n",
          executable=true,
        ),
      ]
    Windows =>
      [
        BundleFile::new(
          path="\{self.executable_name}/app.manifest.xml",
          content=self.windows_manifest(),
        ),
      ]
    Linux =>
      [
        BundleFile::new(
          path="\{self.executable_name}/\{self.executable_name}.desktop",
          content=self.desktop_entry(),
        ),
      ]
  }
}

///|
pub fn BundlePlan::runtime_manifest(
  self : BundlePlan,
) -> Result[RuntimeLaunchManifest, Array[String]] {
  self.runtime.launch_manifest(registered_routes=self.registered_routes)
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
          "\"signingPrerequisites\":[\{self.signing_prerequisites().map(fn(item) { item.to_json() }).join(",")}],",
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
