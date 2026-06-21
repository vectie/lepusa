///|
pub struct BundlePackageCommand {
  name : String
  tool : String
  arguments : Array[String]
  required : Bool
  description : String
} derive(Debug, Eq)

///|
pub struct BundlePackageOutput {
  kind : String
  path : String
  required : Bool
  description : String
} derive(Debug, Eq)

///|
pub struct BundlePackagePlan {
  manifest : BundleDistributionManifest
  package_kind : String
  commands : Array[BundlePackageCommand]
  outputs : Array[BundlePackageOutput]
  blockers : Array[String]
} derive(Debug, Eq)

///|
pub fn BundlePackageCommand::new(
  name~ : String,
  tool~ : String,
  arguments? : Array[String] = [],
  required? : Bool = true,
  description~ : String,
) -> BundlePackageCommand {
  { name, tool, arguments, required, description }
}

///|
pub fn BundlePackageCommand::name(self : BundlePackageCommand) -> String {
  self.name
}

///|
pub fn BundlePackageCommand::tool(self : BundlePackageCommand) -> String {
  self.tool
}

///|
pub fn BundlePackageCommand::arguments(
  self : BundlePackageCommand,
) -> Array[String] {
  self.arguments.copy()
}

///|
pub fn BundlePackageCommand::required(self : BundlePackageCommand) -> Bool {
  self.required
}

///|
pub fn BundlePackageCommand::description(self : BundlePackageCommand) -> String {
  self.description
}

///|
pub fn BundlePackageCommand::to_json(self : BundlePackageCommand) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"tool\":\{self.tool.json_string()},",
    "\"arguments\":[\{self.arguments.map(fn(argument) { argument.json_string() }).join(",")}],",
    "\"required\":\{self.required.json_bool()},",
    "\"description\":\{self.description.json_string()}",
    "}",
  ].join("")
}

///|
pub fn BundlePackageOutput::new(
  kind~ : String,
  path~ : String,
  required? : Bool = true,
  description~ : String,
) -> BundlePackageOutput {
  { kind, path, required, description }
}

///|
pub fn BundlePackageOutput::kind(self : BundlePackageOutput) -> String {
  self.kind
}

///|
pub fn BundlePackageOutput::path(self : BundlePackageOutput) -> String {
  self.path
}

///|
pub fn BundlePackageOutput::required(self : BundlePackageOutput) -> Bool {
  self.required
}

///|
pub fn BundlePackageOutput::description(self : BundlePackageOutput) -> String {
  self.description
}

///|
pub fn BundlePackageOutput::to_json(self : BundlePackageOutput) -> String {
  [
    "{",
    "\"kind\":\{self.kind.json_string()},",
    "\"path\":\{self.path.json_string()},",
    "\"required\":\{self.required.json_bool()},",
    "\"description\":\{self.description.json_string()}",
    "}",
  ].join("")
}

///|
pub fn BundleDistributionManifest::package_plan(
  self : BundleDistributionManifest,
) -> BundlePackagePlan {
  let outputs = package_outputs(self)
  let blockers : Array[String] = []
  let commands = match self.target() {
    "macos" => macos_package_commands(self, blockers)
    "windows" => windows_package_commands(self, blockers)
    "linux" => linux_package_commands(self, outputs, blockers)
    target => {
      blockers.push("unsupported package target: \{target}")
      []
    }
  }
  {
    manifest: self,
    package_kind: package_kind(self.target()),
    commands,
    outputs,
    blockers,
  }
}

///|
pub fn BundlePackagePlan::manifest(
  self : BundlePackagePlan,
) -> BundleDistributionManifest {
  self.manifest
}

///|
pub fn BundlePackagePlan::package_kind(self : BundlePackagePlan) -> String {
  self.package_kind
}

///|
pub fn BundlePackagePlan::commands(
  self : BundlePackagePlan,
) -> Array[BundlePackageCommand] {
  self.commands.copy()
}

///|
pub fn BundlePackagePlan::outputs(
  self : BundlePackagePlan,
) -> Array[BundlePackageOutput] {
  self.outputs.copy()
}

///|
pub fn BundlePackagePlan::blockers(self : BundlePackagePlan) -> Array[String] {
  self.blockers.copy()
}

///|
pub fn BundlePackagePlan::ready(self : BundlePackagePlan) -> Bool {
  self.blockers.is_empty()
}

///|
pub fn BundlePackagePlan::script_name(self : BundlePackagePlan) -> String {
  if self.manifest().target() == "windows" {
    "package.ps1"
  } else {
    "package.sh"
  }
}

///|
pub fn BundlePackagePlan::summary(self : BundlePackagePlan) -> String {
  let manifest = self.manifest()
  let lines : Array[String] = [
    "Lepusa package plan",
    "manifest: \{manifest.path()}",
    "identifier: \{manifest.identifier()}",
    "product: \{manifest.product_name()}",
    "target: \{manifest.target()}",
    "package-kind: \{self.package_kind()}",
    "commands: \{self.commands.length()}",
    "outputs: \{self.outputs.length()}",
    "ready: \{self.ready()}",
  ]
  for blocker in self.blockers {
    lines.push("blocker: \{blocker}")
  }
  for command in self.commands {
    lines.push(
      "command: \{command.name()} tool=\{command.tool()} required=\{command.required()} args=\{command.arguments().length()}",
    )
  }
  for output in self.outputs {
    lines.push(
      "output: \{output.kind()} path=\{output.path()} required=\{output.required()}",
    )
  }
  lines.join("\n") + "\n"
}

///|
pub fn BundlePackagePlan::to_json(self : BundlePackagePlan) -> String {
  [
    "{",
    "\"manifest\":\{self.manifest().to_json()},",
    "\"packageKind\":\{self.package_kind.json_string()},",
    "\"ready\":\{self.ready().json_bool()},",
    "\"scriptName\":\{self.script_name().json_string()},",
    "\"blockers\":[\{self.blockers.map(fn(blocker) { blocker.json_string() }).join(",")}],",
    "\"commands\":[\{self.commands.map(fn(command) { command.to_json() }).join(",")}],",
    "\"outputs\":[\{self.outputs.map(fn(output) { output.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn package_kind(target : String) -> String {
  match target {
    "macos" => "macos-app-dmg"
    "windows" => "windows-exe-installer"
    "linux" => "linux-portable-archive"
    _ => "unknown"
  }
}

///|
fn package_outputs(
  manifest : BundleDistributionManifest,
) -> Array[BundlePackageOutput] {
  let outputs : Array[BundlePackageOutput] = []
  for item in manifest.artifact_entries() {
    match item.path() {
      Some(path) =>
        outputs.push(
          BundlePackageOutput::new(
            kind=item.kind(),
            path~,
            required=item.required(),
            description=item.description(),
          ),
        )
      None => ()
    }
  }
  if manifest.target() == "linux" {
    outputs.push(
      BundlePackageOutput::new(
        kind="portable-archive",
        path="\{manifest.executable()}-\{manifest.version()}-linux.tar.gz",
        description="Linux portable archive generated from the bundle directory",
      ),
    )
  }
  outputs
}

///|
fn macos_package_commands(
  manifest : BundleDistributionManifest,
  blockers : Array[String],
) -> Array[BundlePackageCommand] {
  let commands : Array[BundlePackageCommand] = []
  let app = required_artifact_path(manifest, "app-bundle", blockers)
  let dmg = required_artifact_path(manifest, "disk-image", blockers)
  if app != "" && dmg != "" {
    commands.push(
      BundlePackageCommand::new(
        name="create disk image",
        tool="hdiutil",
        arguments=[
          "create",
          "-volname",
          manifest.product_name(),
          "-srcfolder",
          app,
          dmg,
        ],
        description="Create a distributable macOS disk image from the app bundle",
      ),
    )
  }
  commands
}

///|
fn windows_package_commands(
  manifest : BundleDistributionManifest,
  blockers : Array[String],
) -> Array[BundlePackageCommand] {
  let commands : Array[BundlePackageCommand] = []
  let launcher = required_artifact_path(manifest, "executable", blockers)
  let installer = required_artifact_path(manifest, "installer", blockers)
  if launcher != "" {
    commands.push(
      BundlePackageCommand::new(
        name="compile native launcher",
        tool="cc",
        arguments=[
          "\{manifest.executable()}/\{manifest.executable()}-launcher.c",
          "-o",
          launcher,
        ],
        description="Compile the generated Win32 launcher source into the app executable",
      ),
    )
  }
  if installer != "" {
    commands.push(
      BundlePackageCommand::new(
        name="build installer",
        tool="makensis",
        arguments=["installer.nsi"],
        description="Build the Windows installer from the generated NSIS script",
      ),
    )
  }
  commands
}

///|
fn linux_package_commands(
  manifest : BundleDistributionManifest,
  outputs : Array[BundlePackageOutput],
  blockers : Array[String],
) -> Array[BundlePackageCommand] {
  let commands : Array[BundlePackageCommand] = []
  let bundle = required_artifact_path(manifest, "portable-directory", blockers)
  let desktop = required_artifact_path(manifest, "desktop-entry", blockers)
  if desktop != "" {
    commands.push(
      BundlePackageCommand::new(
        name="validate desktop entry",
        tool="desktop-file-validate",
        arguments=[desktop],
        description="Validate Linux desktop integration metadata before packaging",
      ),
    )
  }
  let archive = output_path(outputs, "portable-archive")
  if bundle != "" && archive != "" {
    commands.push(
      BundlePackageCommand::new(
        name="create portable archive",
        tool="tar",
        arguments=["-czf", archive, bundle],
        description="Create a portable Linux archive from the materialized bundle directory",
      ),
    )
  }
  commands
}

///|
fn required_artifact_path(
  manifest : BundleDistributionManifest,
  kind : String,
  blockers : Array[String],
) -> String {
  for item in manifest.artifact_entries() {
    if item.kind() == kind {
      match item.path() {
        Some(path) => return path
        None => ()
      }
    }
  }
  blockers.push("missing required package artifact: \{kind}")
  ""
}

///|
fn output_path(outputs : Array[BundlePackageOutput], kind : String) -> String {
  for output in outputs {
    if output.kind() == kind {
      return output.path()
    }
  }
  ""
}
