///|
pub struct BundleInstallSmokeCommand {
  name : String
  tool : String
  arguments : Array[String]
  required : Bool
  description : String
} derive(Debug, Eq)

///|
pub struct BundleInstallSmokeCheck {
  kind : String
  path : String
  required : Bool
  description : String
} derive(Debug, Eq)

///|
pub struct BundleInstallSmokePlan {
  manifest : BundleDistributionManifest
  install_root : String
  runtime_manifest_path : String
  commands : Array[BundleInstallSmokeCommand]
  checks : Array[BundleInstallSmokeCheck]
  blockers : Array[String]
} derive(Debug, Eq)

///|
pub fn BundleInstallSmokeCommand::new(
  name~ : String,
  tool~ : String,
  arguments? : Array[String] = [],
  required? : Bool = true,
  description~ : String,
) -> BundleInstallSmokeCommand {
  { name, tool, arguments, required, description }
}

///|
pub fn BundleInstallSmokeCommand::name(
  self : BundleInstallSmokeCommand,
) -> String {
  self.name
}

///|
pub fn BundleInstallSmokeCommand::tool(
  self : BundleInstallSmokeCommand,
) -> String {
  self.tool
}

///|
pub fn BundleInstallSmokeCommand::arguments(
  self : BundleInstallSmokeCommand,
) -> Array[String] {
  self.arguments.copy()
}

///|
pub fn BundleInstallSmokeCommand::required(
  self : BundleInstallSmokeCommand,
) -> Bool {
  self.required
}

///|
pub fn BundleInstallSmokeCommand::description(
  self : BundleInstallSmokeCommand,
) -> String {
  self.description
}

///|
pub fn BundleInstallSmokeCommand::to_json(
  self : BundleInstallSmokeCommand,
) -> String {
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
pub fn BundleInstallSmokeCheck::new(
  kind~ : String,
  path~ : String,
  required? : Bool = true,
  description~ : String,
) -> BundleInstallSmokeCheck {
  { kind, path, required, description }
}

///|
pub fn BundleInstallSmokeCheck::kind(self : BundleInstallSmokeCheck) -> String {
  self.kind
}

///|
pub fn BundleInstallSmokeCheck::path(self : BundleInstallSmokeCheck) -> String {
  self.path
}

///|
pub fn BundleInstallSmokeCheck::required(
  self : BundleInstallSmokeCheck,
) -> Bool {
  self.required
}

///|
pub fn BundleInstallSmokeCheck::description(
  self : BundleInstallSmokeCheck,
) -> String {
  self.description
}

///|
pub fn BundleInstallSmokeCheck::to_json(
  self : BundleInstallSmokeCheck,
) -> String {
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
pub fn BundleDistributionManifest::install_smoke_plan(
  self : BundleDistributionManifest,
  install_root? : String = "_build/lepusa-install-smoke",
) -> BundleInstallSmokePlan {
  let root = clean_install_root(install_root)
  let blockers : Array[String] = []
  let runtime_manifest_path = installed_runtime_manifest_path(self, root)
  if runtime_manifest_path == "" {
    blockers.push("unsupported install smoke target: \{self.target()}")
  }
  {
    manifest: self,
    install_root: root,
    runtime_manifest_path,
    commands: install_smoke_commands(runtime_manifest_path),
    checks: install_smoke_checks(self, root, runtime_manifest_path),
    blockers,
  }
}

///|
pub fn BundleInstallSmokePlan::manifest(
  self : BundleInstallSmokePlan,
) -> BundleDistributionManifest {
  self.manifest
}

///|
pub fn BundleInstallSmokePlan::install_root(
  self : BundleInstallSmokePlan,
) -> String {
  self.install_root
}

///|
pub fn BundleInstallSmokePlan::runtime_manifest_path(
  self : BundleInstallSmokePlan,
) -> String {
  self.runtime_manifest_path
}

///|
pub fn BundleInstallSmokePlan::commands(
  self : BundleInstallSmokePlan,
) -> Array[BundleInstallSmokeCommand] {
  self.commands.copy()
}

///|
pub fn BundleInstallSmokePlan::checks(
  self : BundleInstallSmokePlan,
) -> Array[BundleInstallSmokeCheck] {
  self.checks.copy()
}

///|
pub fn BundleInstallSmokePlan::blockers(
  self : BundleInstallSmokePlan,
) -> Array[String] {
  self.blockers.copy()
}

///|
pub fn BundleInstallSmokePlan::ready(self : BundleInstallSmokePlan) -> Bool {
  self.blockers.is_empty()
}

///|
pub fn BundleInstallSmokePlan::script_name(
  self : BundleInstallSmokePlan,
) -> String {
  if self.manifest().target() == "windows" {
    "install-smoke.ps1"
  } else {
    "install-smoke.sh"
  }
}

///|
pub fn BundleInstallSmokePlan::summary(self : BundleInstallSmokePlan) -> String {
  let manifest = self.manifest()
  let lines : Array[String] = [
    "Lepusa install smoke plan",
    "manifest: \{manifest.path()}",
    "identifier: \{manifest.identifier()}",
    "product: \{manifest.product_name()}",
    "target: \{manifest.target()}",
    "install-root: \{self.install_root()}",
    "runtime-manifest: \{self.runtime_manifest_path()}",
    "commands: \{self.commands.length()}",
    "checks: \{self.checks.length()}",
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
  for check in self.checks {
    lines.push(
      "check: \{check.kind()} path=\{check.path()} required=\{check.required()}",
    )
  }
  lines.join("\n") + "\n"
}

///|
pub fn BundleInstallSmokePlan::to_json(self : BundleInstallSmokePlan) -> String {
  [
    "{",
    "\"manifest\":\{self.manifest().to_json()},",
    "\"installRoot\":\{self.install_root.json_string()},",
    "\"runtimeManifest\":\{self.runtime_manifest_path.json_string()},",
    "\"ready\":\{self.ready().json_bool()},",
    "\"scriptName\":\{self.script_name().json_string()},",
    "\"blockers\":[\{self.blockers.map(fn(blocker) { blocker.json_string() }).join(",")}],",
    "\"commands\":[\{self.commands.map(fn(command) { command.to_json() }).join(",")}],",
    "\"checks\":[\{self.checks.map(fn(check) { check.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn clean_install_root(root : String) -> String {
  if root == "" {
    "."
  } else if root.has_suffix("/") {
    root[:root.length() - 1].to_owned()
  } else {
    root
  }
}

///|
fn installed_runtime_manifest_path(
  manifest : BundleDistributionManifest,
  install_root : String,
) -> String {
  match manifest.target() {
    "macos" =>
      join_path(
        join_path(install_root, manifest.bundle()),
        "Contents/Resources/lepusa/runtime.json",
      )
    "windows" | "linux" =>
      join_path(
        join_path(install_root, manifest.executable()),
        "lepusa/runtime.json",
      )
    _ => ""
  }
}

///|
fn install_smoke_commands(
  runtime_manifest_path : String,
) -> Array[BundleInstallSmokeCommand] {
  if runtime_manifest_path == "" {
    return []
  }
  [
    BundleInstallSmokeCommand::new(
      name="inspect runtime manifest",
      tool="lepusa-runtime",
      arguments=["--manifest", runtime_manifest_path],
      description="Parse installed runtime manifest and print target diagnostics",
    ),
    BundleInstallSmokeCommand::new(
      name="dry-run native runtime",
      tool="lepusa-runtime",
      arguments=["run", "--manifest", runtime_manifest_path],
      description="Prepare packaged native runtime launch data without opening windows",
    ),
    BundleInstallSmokeCommand::new(
      name="check async bridge session",
      tool="lepusa-runtime",
      arguments=[
        "launch-session", "--async-bridge", "--manifest", runtime_manifest_path,
      ],
      description="Verify the installed runtime exposes the native loop bridge-drain boundary",
    ),
    BundleInstallSmokeCommand::new(
      name="resolve bridge asset",
      tool="lepusa-runtime",
      arguments=[
        "asset", "lepusa://runtime/bridge.js", "--manifest", runtime_manifest_path,
      ],
      description="Verify the installed custom protocol can resolve the generated bridge",
    ),
    BundleInstallSmokeCommand::new(
      name="launch installed app",
      tool="lepusa-runtime",
      arguments=["launch", "--manifest", runtime_manifest_path],
      required=false,
      description="Open the installed app when the host has GUI access and platform WebView dependencies",
    ),
  ]
}

///|
fn install_smoke_checks(
  manifest : BundleDistributionManifest,
  install_root : String,
  runtime_manifest_path : String,
) -> Array[BundleInstallSmokeCheck] {
  let checks : Array[BundleInstallSmokeCheck] = []
  if runtime_manifest_path != "" {
    checks.push(
      BundleInstallSmokeCheck::new(
        kind="runtime-manifest",
        path=runtime_manifest_path,
        description="Installed Lepusa runtime manifest",
      ),
    )
  }
  checks.push(
    BundleInstallSmokeCheck::new(
      kind="runtime-executable",
      path=join_path(install_root, manifest.runtime_executable()),
      description="Installed lepusa-runtime executable",
    ),
  )
  for dependency in manifest.runtime_dependency_entries() {
    match dependency.path() {
      Some(path) =>
        checks.push(
          BundleInstallSmokeCheck::new(
            kind=dependency.kind(),
            path=join_path(install_root, path),
            required=dependency.required(),
            description=dependency.description(),
          ),
        )
      None => ()
    }
  }
  for artifact in manifest.artifact_entries() {
    match artifact.path() {
      Some(path) =>
        checks.push(
          BundleInstallSmokeCheck::new(
            kind=artifact.kind(),
            path=join_path(install_root, path),
            required=artifact.required(),
            description=artifact.description(),
          ),
        )
      None => ()
    }
  }
  checks
}
