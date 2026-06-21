///|
pub struct BundlePackageWriteResult {
  root : String
  plan_path : String
  checklist_path : String
  script_path : String
  installer_script_path : String?
  plan : BundlePackagePlan
} derive(Debug, Eq)

///|
pub fn BundlePackageWriteResult::root(
  self : BundlePackageWriteResult,
) -> String {
  self.root
}

///|
pub fn BundlePackageWriteResult::plan_path(
  self : BundlePackageWriteResult,
) -> String {
  self.plan_path
}

///|
pub fn BundlePackageWriteResult::checklist_path(
  self : BundlePackageWriteResult,
) -> String {
  self.checklist_path
}

///|
pub fn BundlePackageWriteResult::script_path(
  self : BundlePackageWriteResult,
) -> String {
  self.script_path
}

///|
pub fn BundlePackageWriteResult::installer_script_path(
  self : BundlePackageWriteResult,
) -> String? {
  self.installer_script_path
}

///|
pub fn BundlePackageWriteResult::plan(
  self : BundlePackageWriteResult,
) -> BundlePackagePlan {
  self.plan
}

///|
pub fn BundlePackageWriteResult::ready(self : BundlePackageWriteResult) -> Bool {
  self.plan.ready()
}

///|
pub fn BundlePackageWriteResult::files(
  self : BundlePackageWriteResult,
) -> Array[String] {
  let files = [self.plan_path, self.checklist_path, self.script_path]
  match self.installer_script_path {
    Some(path) => files.push(path)
    None => ()
  }
  files
}

///|
pub fn BundlePackageWriteResult::to_json(
  self : BundlePackageWriteResult,
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
pub async fn write_package_plan(
  plan : BundlePackagePlan,
  out_dir : String,
) -> Result[BundlePackageWriteResult, Array[String]] {
  let root = normalize_output_root(out_dir)
  let plan_path = join_path(root, "package-plan.json")
  let checklist_path = join_path(root, "package-checklist.md")
  let script_path = join_path(root, plan.script_name())
  let installer_script_path = if plan.manifest().target() == "windows" {
    Some(join_path(root, "installer.nsi"))
  } else {
    None
  }
  let problems : Array[String] = []
  ensure_directory(root, problems)
  write_package_file(plan_path, plan.to_json() + "\n", problems)
  write_package_file(
    checklist_path,
    plan.package_checklist_markdown(),
    problems,
  )
  write_package_file(script_path, plan.package_script(), problems)
  match installer_script_path {
    Some(path) =>
      write_package_file(path, plan.windows_installer_script(), problems)
    None => ()
  }
  if problems.is_empty() {
    if plan.manifest().target() != "windows" {
      @fs.chmod(script_path, 0o755) catch {
        error =>
          problems.push("could not mark package script executable: \{error}")
      }
    }
  }
  if problems.is_empty() {
    Ok({
      root,
      plan_path,
      checklist_path,
      script_path,
      installer_script_path,
      plan,
    })
  } else {
    Err(problems)
  }
}

///|
pub fn BundlePackagePlan::package_checklist_markdown(
  self : BundlePackagePlan,
) -> String {
  let manifest = self.manifest()
  let lines : Array[String] = [
    "# Lepusa Package Checklist",
    "",
    "- manifest: \{manifest.path()}",
    "- identifier: \{manifest.identifier()}",
    "- product: \{manifest.product_name()}",
    "- version: \{manifest.version()}",
    "- target: \{manifest.target()}",
    "- package-kind: \{self.package_kind()}",
    "- ready: \{self.ready()}",
    "",
    "## Commands",
    "",
  ]
  for blocker in self.blockers() {
    lines.push("- blocker: \{blocker}")
  }
  if !self.blockers().is_empty() {
    lines.push("")
  }
  for command in self.commands() {
    let mark = if command.required() { "[ ]" } else { "[-]" }
    lines.push(
      "\{mark} \{command.name()} -- \{command.tool()} \{command.arguments().join(" ")}",
    )
    lines.push("  - \{command.description()}")
  }
  lines.push("")
  lines.push("## Outputs")
  lines.push("")
  for output in self.outputs() {
    let mark = if output.required() { "[ ]" } else { "[-]" }
    lines.push("\{mark} \{output.kind()} \{output.path()}")
    if output.description() != "" {
      lines.push("  - \{output.description()}")
    }
  }
  lines.join("\n") + "\n"
}

///|
pub fn BundlePackagePlan::package_script(self : BundlePackagePlan) -> String {
  if self.manifest().target() == "windows" {
    self.windows_package_script()
  } else {
    self.posix_package_script()
  }
}

///|
fn BundlePackagePlan::posix_package_script(self : BundlePackagePlan) -> String {
  let root = self.bundle_root_hint()
  let lines : Array[String] = [
    "#!/bin/sh",
    "set -eu",
    "BUNDLE_ROOT=${BUNDLE_ROOT:-\{root.posix_quote()}}",
    "cd \"$BUNDLE_ROOT\"",
    "",
  ]
  for command in self.commands() {
    lines.push(posix_command_line(command))
  }
  lines.join("\n") + "\n"
}

///|
fn BundlePackagePlan::windows_package_script(
  self : BundlePackagePlan,
) -> String {
  let root = self.bundle_root_hint()
  let lines : Array[String] = [
    "$ErrorActionPreference = \"Stop\"",
    "$BundleRoot = if ($env:BUNDLE_ROOT) { $env:BUNDLE_ROOT } else { \{root.powershell_quote()} }",
    "Set-Location $BundleRoot",
    "",
  ]
  for command in self.commands() {
    let executable = if command.tool() == "cc" {
      "if ($env:CC) { $env:CC } else { \"cc\" }"
    } else {
      command.tool().powershell_quote()
    }
    lines.push(
      "& \{executable} \{command.arguments().map(fn(arg) { arg.powershell_quote() }).join(" ")}",
    )
  }
  lines.join("\n") + "\n"
}

///|
fn posix_command_line(command : BundlePackageCommand) -> String {
  let parts = [command.tool().posix_quote()]
  for argument in command.arguments() {
    parts.push(argument.posix_quote())
  }
  parts.join(" ")
}

///|
pub fn BundlePackagePlan::windows_installer_script(
  self : BundlePackagePlan,
) -> String {
  let manifest = self.manifest()
  if manifest.target() != "windows" {
    return ""
  }
  let installer = package_output_path(self.outputs(), "installer")
  (
    #|Name "__LEPUSA_PRODUCT__"
    #|OutFile "__LEPUSA_INSTALLER__"
    #|InstallDir "$PROGRAMFILES64\__LEPUSA_PRODUCT__"
    #|RequestExecutionLevel admin
    #|
    #|Section "Install"
    #|  SetOutPath "$INSTDIR"
    #|  File /r "__LEPUSA_EXE_DIR__\*"
    #|  CreateShortCut "$DESKTOP\__LEPUSA_PRODUCT__.lnk" "$INSTDIR\__LEPUSA_EXE__"
    #|SectionEnd
    #|
  )
  .replace_all(old="__LEPUSA_PRODUCT__", new=manifest.product_name())
  .replace_all(old="__LEPUSA_INSTALLER__", new=installer)
  .replace_all(old="__LEPUSA_EXE_DIR__", new=manifest.executable())
  .replace_all(old="__LEPUSA_EXE__", new=manifest.bundle())
}

///|
fn BundlePackagePlan::bundle_root_hint(self : BundlePackagePlan) -> String {
  let manifest = self.manifest()
  let suffix = "/\{manifest.bundle()}/lepusa/distribution.json"
  if manifest.path().has_suffix(suffix) {
    let end = manifest.path().length() - suffix.length()
    if end == 0 {
      "."
    } else {
      manifest.path()[:end].to_owned()
    }
  } else {
    "."
  }
}

///|
async fn write_package_file(
  path : String,
  content : String,
  problems : Array[String],
) -> Unit {
  if !problems.is_empty() {
    return
  }
  ensure_directory(parent_directory(path), problems)
  if !problems.is_empty() {
    return
  }
  @fs.write_file(path, content, create_mode=CreateOrTruncate, permission=0o644) catch {
    error => problems.push("could not write package artifact \{path}: \{error}")
  }
}

///|
fn package_output_path(
  outputs : Array[BundlePackageOutput],
  kind : String,
) -> String {
  for output in outputs {
    if output.kind() == kind {
      return output.path()
    }
  }
  ""
}

///|
fn String::posix_quote(self : String) -> String {
  "'\{self.replace_all(old="'", new="'\\''")}'"
}

///|
fn String::powershell_quote(self : String) -> String {
  "'\{self.replace_all(old="'", new="''")}'"
}
