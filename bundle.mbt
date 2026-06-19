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
pub fn BundlePlan::identifier(self : BundlePlan) -> String {
  self.metadata.identifier()
}

///|
pub fn BundlePlan::executable_name(self : BundlePlan) -> String {
  self.executable_name
}

///|
pub fn BundlePlan::files(
  self : BundlePlan,
) -> Result[Array[BundleFile], Array[String]] {
  match self.runtime.bridge_script() {
    Ok(bridge) => {
      let files : Array[BundleFile] = []
      for file in self.platform_files() {
        files.push(file)
      }
      files.push(
        BundleFile::new(
          path=self.shared_path("lepusa/runtime.json"),
          content=self.runtime_manifest_json(),
        ),
      )
      files.push(
        BundleFile::new(
          path=self.shared_path("lepusa/bridge.js"),
          content=bridge.source(),
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
fn BundlePlan::runtime_manifest_json(self : BundlePlan) -> String {
  let windows = self.runtime
    .windows()
    .map(fn(window) {
      "{\"label\":\{window.label().json_string()},\"url\":\{window.url().json_string()}}"
    })
    .join(",")
  let routes = self.runtime
    .command_routes()
    .map(fn(route) { route.json_string() })
    .join(",")
  [
    "{",
    "\"identifier\":\{self.identifier().json_string()},",
    "\"productName\":\{self.metadata.product_name().json_string()},",
    "\"version\":\{self.metadata.version().json_string()},",
    "\"target\":\{self.target.name().json_string()},",
    "\"backend\":\{self.runtime.backend().name().json_string()},",
    "\"assetProtocol\":\{self.runtime.asset_protocol().json_string()},",
    "\"windows\":[\{windows}],",
    "\"commandRoutes\":[\{routes}]",
    "}",
  ].join("")
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
fn String::xml_escape(self : String) -> String {
  self
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}
