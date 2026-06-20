///|
async fn render_bundle_plan_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_bundle_plan(args, target) {
        Ok(plan) => render_bundle_plan_summary(plan)
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_bundle_plan_summary(plan : @lepusa.BundlePlan) -> CliResult {
  match plan.files() {
    Ok(files) => {
      let local_service_count = match plan.runtime_manifest() {
        Ok(manifest) => manifest.local_services().length()
        Err(_) => 0
      }
      let filesystem_scope_count = match plan.runtime_manifest() {
        Ok(manifest) => manifest.file_system_scopes().length()
        Err(_) => 0
      }
      ok(
        "Lepusa bundle plan\n" +
        "target: \{plan.target().name()}\n" +
        "identifier: \{plan.identifier()}\n" +
        "executable: \{plan.executable_name()}\n" +
        "bundle: \{plan.bundle_name()}\n" +
        "runtime-executable: \{plan.runtime_executable_path()}\n" +
        "local-services: \{local_service_count}\n" +
        "filesystem-scopes: \{filesystem_scope_count}\n" +
        "resources: \{plan.resources().length()}\n" +
        "signing-prerequisites: \{plan.signing_prerequisites().length()}\n" +
        "files: \{files.length()}\n",
      )
    }
    Err(problems) => fail(render_problems("Lepusa bundle files", problems))
  }
}

///|
async fn render_bundle_write(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) => {
      let out_dir = values.get(1).unwrap_or("_build/lepusa-bundle")
      match project_bundle_plan(args, target) {
        Ok(plan) =>
          match @bundle.write_plan(plan, out_dir) {
            Ok(result) => {
              let output = if has_flag(args, "--json") {
                render_bundle_write_json(plan, result) + "\n"
              } else {
                render_bundle_write_summary(plan, result)
              }
              if result.verified() {
                ok(output)
              } else {
                fail(output)
              }
            }
            Err(problems) =>
              fail(render_problems("Lepusa bundle write", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_bundle_write_summary(
  plan : @lepusa.BundlePlan,
  result : @bundle.BundleWriteResult,
) -> String {
  let local_service_count = match plan.runtime_manifest() {
    Ok(manifest) => manifest.local_services().length()
    Err(_) => 0
  }
  let filesystem_scope_count = match plan.runtime_manifest() {
    Ok(manifest) => manifest.file_system_scopes().length()
    Err(_) => 0
  }
  "Lepusa bundle write\n" +
  "target: \{plan.target().name()}\n" +
  "root: \{result.root()}\n" +
  "local-services: \{local_service_count}\n" +
  "filesystem-scopes: \{filesystem_scope_count}\n" +
  "resources: \{plan.resources().length()}\n" +
  "resources-written: \{result.resources().length()}\n" +
  "verification-checks: \{result.checks().length()}\n" +
  "verified: \{result.verified().to_string()}\n" +
  "signing-prerequisites: \{plan.signing_prerequisites().length()}\n" +
  "files: \{result.files().length()}\n" +
  render_bundle_write_checks(result.checks())
}

///|
fn render_bundle_write_json(
  plan : @lepusa.BundlePlan,
  result : @bundle.BundleWriteResult,
) -> String {
  [
    "{",
    "\"target\":\{cli_json_string(plan.target().name())},",
    "\"identifier\":\{cli_json_string(plan.identifier())},",
    "\"bundle\":\{result.to_json()},",
    "\"signingPrerequisites\":\{plan.signing_prerequisites().length()}",
    "}",
  ].join("")
}

///|
fn render_bundle_write_checks(
  checks : Array[@bundle.BundleWriteCheck],
) -> String {
  checks
  .map(fn(check) {
    let status = if check.ok() { "ok" } else { "fail" }
    "[\{status}] verify: \{check.kind().name()} \{check.path()} - \{check.message()}\n"
  })
  .join("")
}
