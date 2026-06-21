///|
struct PublishCommand {
  name : String
  command : String
  required : Bool
  description : String
} derive(Debug, Eq)

///|
struct PublishPlan {
  target : @lepusa.BundleTarget
  project : String
  bundle : @lepusa.BundlePlan
  bundle_root : String
  distribution_path : String
  release_root : String
  package_root : String
  install_smoke_root : String
  install_root : String
  release_ready : Bool
  release_readiness : String
  package_ready : Bool
  package_kind : String
  package_script : String
  package_blockers : Array[String]
  install_smoke_ready : Bool
  install_smoke_script : String
  install_smoke_blockers : Array[String]
  commands : Array[PublishCommand]
} derive(Debug, Eq)

///|
async fn render_publish_plan_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_bundle_plan(args, target) {
        Ok(bundle) =>
          match publish_plan(args, target, bundle) {
            Ok(plan) =>
              if has_flag(args, "--json") {
                ok(plan.to_json() + "\n")
              } else {
                ok(plan.summary())
              }
            Err(problems) =>
              fail(render_problems("Lepusa publish plan", problems))
          }
        Err(problems) => fail(render_problems("Lepusa publish plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn publish_plan(
  args : Array[String],
  target : @lepusa.BundleTarget,
  bundle : @lepusa.BundlePlan,
) -> Result[PublishPlan, Array[String]] {
  let project = project_path_arg(args).unwrap_or("lepusa.json")
  let bundle_root = "_build/lepusa-bundle-\{target.name()}"
  let distribution_path = publish_distribution_path(bundle, bundle_root)
  let release_root = "_build/lepusa-release-\{target.name()}"
  let package_root = "_build/lepusa-package-\{target.name()}"
  let install_smoke_root = "_build/lepusa-install-smoke-\{target.name()}"
  let install_root = publish_install_root(target)
  match
    @bundle.BundleDistributionManifest::parse(
      "lepusa/distribution.json",
      bundle.distribution_manifest_json(),
    ) {
    Ok(manifest) =>
      match @bundle.package_plan_for_bundle(bundle) {
        Ok(package_plan) => {
          let release_plan = manifest.release_plan()
          let smoke_plan = manifest.install_smoke_plan(install_root~)
          let package_script = "\{package_root}/\{package_plan.script_name()}"
          let install_smoke_script = "\{install_smoke_root}/\{smoke_plan.script_name()}"
          let commands = publish_commands(
            project, target, bundle_root, distribution_path, release_root, package_root,
            package_script, install_smoke_root, install_root,
          )
          Ok({
            target,
            project,
            bundle,
            bundle_root,
            distribution_path,
            release_root,
            package_root,
            install_smoke_root,
            install_root,
            release_ready: release_plan.ready(),
            release_readiness: release_plan.readiness_message(),
            package_ready: package_plan.ready(),
            package_kind: package_plan.package_kind(),
            package_script,
            package_blockers: package_plan.blockers(),
            install_smoke_ready: smoke_plan.ready(),
            install_smoke_script,
            install_smoke_blockers: smoke_plan.blockers(),
            commands,
          })
        }
        Err(problems) => Err(problems)
      }
    Err(problem) => Err([problem])
  }
}

///|
fn publish_install_root(target : @lepusa.BundleTarget) -> String {
  match target {
    MacOS => "/Applications"
    Windows => "C:/Program Files"
    Linux => "/opt"
  }
}

///|
fn publish_distribution_path(
  bundle : @lepusa.BundlePlan,
  bundle_root : String,
) -> String {
  let app_root = match bundle.target() {
    MacOS => "\{bundle_root}/\{bundle.bundle_name()}/Contents/Resources"
    _ => "\{bundle_root}/\{bundle.executable_name()}"
  }
  "\{app_root}/lepusa/distribution.json"
}

///|
fn publish_commands(
  project : String,
  target : @lepusa.BundleTarget,
  bundle_root : String,
  distribution_path : String,
  release_root : String,
  package_root : String,
  package_script : String,
  install_smoke_root : String,
  install_root : String,
) -> Array[PublishCommand] {
  let target_name = target.name()
  [
    PublishCommand::new(
      name="verify",
      command="lepusa verify \{target_name} --strict --project \{project}",
      description="prove runtime, native launch, bundle, release, and package readiness",
    ),
    PublishCommand::new(
      name="bundle-write",
      command="lepusa bundle-write \{target_name} \{bundle_root} --project \{project}",
      description="materialize the platform bundle and distribution manifest",
    ),
    PublishCommand::new(
      name="release-write",
      command="lepusa bundle-release-write \{distribution_path} \{release_root}",
      description="write the release plan and release checklist",
    ),
    PublishCommand::new(
      name="package-write",
      command="lepusa bundle-package-write \{distribution_path} \{package_root}",
      description="write the package plan, checklist, and target package script",
    ),
    PublishCommand::new(
      name="package-script",
      command=publish_package_script_command(package_script, bundle_root),
      description="run the target package script with the materialized bundle root",
    ),
    PublishCommand::new(
      name="install-smoke-write",
      command="lepusa bundle-install-smoke-write \{distribution_path} \{install_smoke_root} \{publish_command_arg(install_root)}",
      description="write post-install validation JSON, checklist, and target smoke script",
    ),
  ]
}

///|
fn publish_package_script_command(
  package_script : String,
  bundle_root : String,
) -> String {
  if package_script.has_suffix(".ps1") {
    "powershell -ExecutionPolicy Bypass -File \{package_script} -BundleRoot \{bundle_root}"
  } else {
    "BUNDLE_ROOT=\{bundle_root} sh \{package_script}"
  }
}

///|
fn publish_command_arg(value : String) -> String {
  if value.contains(" ") {
    "\"\{value.replace_all(old="\"", new="\\\"")}\""
  } else {
    value
  }
}

///|
fn PublishCommand::new(
  name~ : String,
  command~ : String,
  required? : Bool = true,
  description~ : String,
) -> PublishCommand {
  { name, command, required, description }
}

///|
fn PublishCommand::to_json(self : PublishCommand) -> String {
  [
    "{",
    "\"name\":\{cli_json_string(self.name)},",
    "\"command\":\{cli_json_string(self.command)},",
    "\"required\":\{cli_json_bool(self.required)},",
    "\"description\":\{cli_json_string(self.description)}",
    "}",
  ].join("")
}

///|
fn PublishPlan::summary(self : PublishPlan) -> String {
  let lines : Array[String] = [
    "Lepusa publish plan",
    "target: \{self.target.name()}",
    "project: \{self.project}",
    "identifier: \{self.bundle.identifier()}",
    "bundle-root: \{self.bundle_root}",
    "distribution: \{self.distribution_path}",
    "release-root: \{self.release_root}",
    "package-root: \{self.package_root}",
    "install-smoke-root: \{self.install_smoke_root}",
    "install-root: \{self.install_root}",
    "release-ready: \{self.release_ready}",
    "release-readiness: \{self.release_readiness}",
    "package-ready: \{self.package_ready}",
    "package-kind: \{self.package_kind}",
    "package-script: \{self.package_script}",
    "install-smoke-ready: \{self.install_smoke_ready}",
    "install-smoke-script: \{self.install_smoke_script}",
  ]
  for blocker in self.package_blockers {
    lines.push("package-blocker: \{blocker}")
  }
  for blocker in self.install_smoke_blockers {
    lines.push("install-smoke-blocker: \{blocker}")
  }
  for command in self.commands {
    lines.push("command: \{command.name} \{command.command}")
  }
  lines.join("\n") + "\n"
}

///|
fn PublishPlan::to_json(self : PublishPlan) -> String {
  [
    "{",
    "\"target\":\{cli_json_string(self.target.name())},",
    "\"project\":\{cli_json_string(self.project)},",
    "\"identifier\":\{cli_json_string(self.bundle.identifier())},",
    "\"bundleRoot\":\{cli_json_string(self.bundle_root)},",
    "\"distributionPath\":\{cli_json_string(self.distribution_path)},",
    "\"releaseRoot\":\{cli_json_string(self.release_root)},",
    "\"packageRoot\":\{cli_json_string(self.package_root)},",
    "\"installSmokeRoot\":\{cli_json_string(self.install_smoke_root)},",
    "\"installRoot\":\{cli_json_string(self.install_root)},",
    "\"releaseReady\":\{cli_json_bool(self.release_ready)},",
    "\"releaseReadiness\":\{cli_json_string(self.release_readiness)},",
    "\"packageReady\":\{cli_json_bool(self.package_ready)},",
    "\"packageKind\":\{cli_json_string(self.package_kind)},",
    "\"packageScript\":\{cli_json_string(self.package_script)},",
    "\"packageBlockers\":[\{self.package_blockers.map(fn(blocker) { cli_json_string(blocker) }).join(",")}],",
    "\"installSmokeReady\":\{cli_json_bool(self.install_smoke_ready)},",
    "\"installSmokeScript\":\{cli_json_string(self.install_smoke_script)},",
    "\"installSmokeBlockers\":[\{self.install_smoke_blockers.map(fn(blocker) { cli_json_string(blocker) }).join(",")}],",
    "\"commands\":[\{self.commands.map(fn(command) { command.to_json() }).join(",")}]",
    "}",
  ].join("")
}
