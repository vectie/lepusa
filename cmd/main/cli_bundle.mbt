///|
async fn render_bundle_plan_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_bundle_plan(args, target) {
        Ok(plan) =>
          if has_flag(args, "--json") {
            render_bundle_plan_json(plan)
          } else {
            render_bundle_plan_summary(plan)
          }
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_bundle_inspect_async(args : Array[String]) -> CliResult {
  match read_bundle_distribution_manifest(args, "bundle-inspect") {
    Ok(manifest) =>
      if has_flag(args, "--json") {
        ok(manifest.to_json() + "\n")
      } else {
        ok(manifest.summary())
      }
    Err(problem) => fail(problem)
  }
}

///|
async fn render_bundle_release_plan_async(args : Array[String]) -> CliResult {
  match read_bundle_distribution_manifest(args, "bundle-release-plan") {
    Ok(manifest) => {
      let plan = manifest.release_plan()
      if has_flag(args, "--json") {
        ok(plan.to_json() + "\n")
      } else {
        ok(plan.summary())
      }
    }
    Err(problem) => fail(problem)
  }
}

///|
async fn read_bundle_distribution_manifest(
  args : Array[String],
  command : String,
) -> Result[@bundle.BundleDistributionManifest, String] {
  let values = positional_args(args)
  match values.get(0) {
    Some(path) => {
      let content = @fs.read_file(path) catch {
        error =>
          return Err("could not read bundle distribution manifest: \{error}\n")
      }
      match @bundle.BundleDistributionManifest::parse(path, content.text()) {
        Ok(manifest) => Ok(manifest)
        Err(problem) =>
          Err("invalid bundle distribution manifest: \{problem}\n")
      }
    }
    None => Err("\{command} requires a lepusa/distribution.json path\n")
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
        "runtime-dependencies: \{plan.runtime_dependencies().length()}\n" +
        "signing-prerequisites: \{plan.signing_prerequisites().length()}\n" +
        "files: \{files.length()}\n",
      )
    }
    Err(problems) => fail(render_problems("Lepusa bundle files", problems))
  }
}

///|
fn render_bundle_plan_json(plan : @lepusa.BundlePlan) -> CliResult {
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
        [
          "{",
          "\"target\":\{cli_json_string(plan.target().name())},",
          "\"identifier\":\{cli_json_string(plan.identifier())},",
          "\"executable\":\{cli_json_string(plan.executable_name())},",
          "\"bundle\":\{cli_json_string(plan.bundle_name())},",
          "\"runtimeExecutable\":\{cli_json_string(plan.runtime_executable_path())},",
          "\"localServices\":\{local_service_count},",
          "\"filesystemScopes\":\{filesystem_scope_count},",
          "\"resources\":[\{plan.resources().map(fn(resource) { resource.to_json() }).join(",")}],",
          "\"runtimeDependencies\":[\{plan.runtime_dependencies().map(fn(dependency) { dependency.to_json() }).join(",")}],",
          "\"signingPrerequisites\":[\{plan.signing_prerequisites().map(fn(item) { item.to_json() }).join(",")}],",
          "\"signingSteps\":[\{plan.signing_steps().map(fn(step) { step.to_json() }).join(",")}],",
          "\"files\":[\{files.map(fn(file) { render_bundle_file_json(file) }).join(",")}]",
          "}\n",
        ].join(""),
      )
    }
    Err(problems) => fail(render_problems("Lepusa bundle files", problems))
  }
}

///|
fn render_bundle_file_json(file : @lepusa.BundleFile) -> String {
  [
    "{",
    "\"path\":\{cli_json_string(file.path())},",
    "\"executable\":\{cli_json_bool(file.executable())}",
    "}",
  ].join("")
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
  "runtime-dependencies: \{plan.runtime_dependencies().length()}\n" +
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
    "\"runtimeDependencies\":[\{plan.runtime_dependencies().map(fn(dependency) { dependency.to_json() }).join(",")}],",
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
