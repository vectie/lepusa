///|
pub struct BundleInstallSmokeWriteResult {
  root : String
  plan_path : String
  checklist_path : String
  script_path : String
  plan : BundleInstallSmokePlan
} derive(Debug, Eq)

///|
pub fn BundleInstallSmokeWriteResult::root(
  self : BundleInstallSmokeWriteResult,
) -> String {
  self.root
}

///|
pub fn BundleInstallSmokeWriteResult::plan_path(
  self : BundleInstallSmokeWriteResult,
) -> String {
  self.plan_path
}

///|
pub fn BundleInstallSmokeWriteResult::checklist_path(
  self : BundleInstallSmokeWriteResult,
) -> String {
  self.checklist_path
}

///|
pub fn BundleInstallSmokeWriteResult::script_path(
  self : BundleInstallSmokeWriteResult,
) -> String {
  self.script_path
}

///|
pub fn BundleInstallSmokeWriteResult::plan(
  self : BundleInstallSmokeWriteResult,
) -> BundleInstallSmokePlan {
  self.plan
}

///|
pub fn BundleInstallSmokeWriteResult::ready(
  self : BundleInstallSmokeWriteResult,
) -> Bool {
  self.plan.ready()
}

///|
pub fn BundleInstallSmokeWriteResult::files(
  self : BundleInstallSmokeWriteResult,
) -> Array[String] {
  [self.plan_path, self.checklist_path, self.script_path]
}

///|
pub fn BundleInstallSmokeWriteResult::to_json(
  self : BundleInstallSmokeWriteResult,
) -> String {
  [
    "{",
    "\"root\":\{self.root.json_string()},",
    "\"ready\":\{self.ready().json_bool()},",
    "\"files\":[\{self.files().map(fn(file) { file.json_string() }).join(",")}],",
    "\"plan\":\{self.plan.to_json()}",
    "}",
  ].join("")
}

///|
pub async fn write_install_smoke_plan(
  plan : BundleInstallSmokePlan,
  out_dir : String,
) -> Result[BundleInstallSmokeWriteResult, Array[String]] {
  let root = normalize_output_root(out_dir)
  let plan_path = join_path(root, "install-smoke-plan.json")
  let checklist_path = join_path(root, "install-smoke-checklist.md")
  let script_path = join_path(root, plan.script_name())
  let problems : Array[String] = []
  ensure_directory(root, problems)
  write_package_file(plan_path, plan.to_json() + "\n", problems)
  write_package_file(
    checklist_path,
    plan.install_smoke_checklist_markdown(),
    problems,
  )
  write_package_file(script_path, plan.install_smoke_script(), problems)
  if problems.is_empty() && plan.manifest().target() != "windows" {
    @fs.chmod(script_path, 0o755) catch {
      error =>
        problems.push(
          "could not mark install smoke script executable: \{error}",
        )
    }
  }
  if problems.is_empty() {
    Ok({ root, plan_path, checklist_path, script_path, plan })
  } else {
    Err(problems)
  }
}

///|
pub fn BundleInstallSmokePlan::install_smoke_checklist_markdown(
  self : BundleInstallSmokePlan,
) -> String {
  let manifest = self.manifest()
  let lines : Array[String] = [
    "# Lepusa Install Smoke Checklist",
    "",
    "- manifest: \{manifest.path()}",
    "- identifier: \{manifest.identifier()}",
    "- product: \{manifest.product_name()}",
    "- version: \{manifest.version()}",
    "- target: \{manifest.target()}",
    "- install-root: \{self.install_root()}",
    "- runtime-manifest: \{self.runtime_manifest_path()}",
    "- ready: \{self.ready()}",
    "",
    "## Files",
    "",
  ]
  for blocker in self.blockers() {
    lines.push("- blocker: \{blocker}")
  }
  if !self.blockers().is_empty() {
    lines.push("")
  }
  for check in self.checks() {
    let mark = if check.required() { "[ ]" } else { "[-]" }
    lines.push("\{mark} \{check.kind()} \{check.path()}")
    if check.description() != "" {
      lines.push("  - \{check.description()}")
    }
  }
  lines.push("")
  lines.push("## Commands")
  lines.push("")
  for command in self.commands() {
    let mark = if command.required() { "[ ]" } else { "[-]" }
    lines.push(
      "\{mark} \{command.name()} -- \{command.tool()} \{command.arguments().join(" ")}",
    )
    lines.push("  - \{command.description()}")
  }
  lines.join("\n") + "\n"
}

///|
pub fn BundleInstallSmokePlan::install_smoke_script(
  self : BundleInstallSmokePlan,
) -> String {
  if self.manifest().target() == "windows" {
    self.windows_install_smoke_script()
  } else {
    self.posix_install_smoke_script()
  }
}

///|
fn BundleInstallSmokePlan::posix_install_smoke_script(
  self : BundleInstallSmokePlan,
) -> String {
  let lines : Array[String] = ["#!/bin/sh", "set -eu", ""]
  for check in self.checks() {
    if check.required() {
      lines.push(
        "test -e \{check.path().posix_quote()} || { echo \"missing required \{check.kind()}: \{check.path()}\" >&2; exit 1; }",
      )
    }
  }
  lines.push("")
  for command in self.commands() {
    if command.required() {
      lines.push(posix_install_smoke_command_line(command))
    } else {
      lines.push("# optional: \{posix_install_smoke_command_line(command)}")
    }
  }
  lines.join("\n") + "\n"
}

///|
fn BundleInstallSmokePlan::windows_install_smoke_script(
  self : BundleInstallSmokePlan,
) -> String {
  let lines : Array[String] = ["$ErrorActionPreference = \"Stop\"", ""]
  for check in self.checks() {
    if check.required() {
      lines.push(
        "if (!(Test-Path \{check.path().powershell_quote()})) { throw \"missing required \{check.kind()}: \{check.path()}\" }",
      )
    }
  }
  lines.push("")
  for command in self.commands() {
    if command.required() {
      lines.push(windows_install_smoke_command_line(command))
    } else {
      lines.push("# optional: \{windows_install_smoke_command_line(command)}")
    }
  }
  lines.join("\n") + "\n"
}

///|
fn posix_install_smoke_command_line(
  command : BundleInstallSmokeCommand,
) -> String {
  let parts = [command.tool().posix_quote()]
  for argument in command.arguments() {
    parts.push(argument.posix_quote())
  }
  parts.join(" ")
}

///|
fn windows_install_smoke_command_line(
  command : BundleInstallSmokeCommand,
) -> String {
  "& \{command.tool().powershell_quote()} \{command.arguments().map(fn(arg) { arg.powershell_quote() }).join(" ")}"
}
