///|
async fn render_deploy_dry_run_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match values.get(0) {
    Some(path) =>
      match parse_bundle_target(values.get(1)) {
        Ok(target) =>
          match (values.get(2), values.get(3)) {
            (Some(install_root), Some(staging_root)) =>
              match read_update_manifest(path) {
                Ok(manifest) =>
                  match
                    @deployment.DeploymentPlan::from_update_manifest(
                      manifest,
                      target~,
                      install_root~,
                      staging_root~,
                      current_version?=values.get(4),
                    ) {
                    Ok(plan) => {
                      let report = plan.dry_run(
                        allow_restart=has_flag(args, "--allow-restart"),
                      )
                      if has_flag(args, "--json") {
                        ok(report.to_json() + "\n")
                      } else {
                        ok(report.summary())
                      }
                    }
                    Err(problems) =>
                      fail(render_problems("Lepusa deploy dry-run", problems))
                  }
                Err(problems) =>
                  fail(render_problems("Lepusa update manifest", problems))
              }
            _ => fail(deploy_dry_run_usage())
          }
        Err(problem) => fail(problem + "\n")
      }
    None => fail(deploy_dry_run_usage())
  }
}

///|
async fn read_update_manifest(
  path : String,
) -> Result[@lepusa.UpdateManifest, Array[String]] {
  let content = @fs.read_file(path) catch {
    error => return Err(["could not read update manifest: \{error}"])
  }
  @lepusa.UpdateManifest::parse(content.text())
}

///|
fn deploy_dry_run_usage() -> String {
  "deploy-dry-run requires <update.json> <macos|windows|linux> <install-root> <staging-root> [current-version]\n"
}
