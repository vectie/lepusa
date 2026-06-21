///|
fn release_readiness_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(@lepusa.Plugin::new("log").command_sync("write"))
    .with_capability(
      @lepusa.Capability::new("main").window("main").command("log.write"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
fn release_bundle(
  target : @lepusa.BundleTarget,
  signing? : @lepusa.SigningConfig = @lepusa.SigningConfig::new(),
) -> @lepusa.BundlePlan {
  match
    @lepusa.BundleConfig::new(
      @lepusa.AppMetadata::new(
        identifier="dev.vectie.release",
        product_name="Release App",
        version="0.1.0",
      ),
      target~,
      signing~,
    ).plan(release_readiness_plan(), registered_routes=["log.write"]) {
    Ok(plan) => plan
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "release readiness reports unsigned bundle gaps" {
  match release_bundle(MacOS).release_readiness() {
    Ok(report) => {
      assert_eq(report.target().name(), "macos")
      assert_eq(report.files(), 4)
      assert_eq(report.artifacts(), 2)
      assert_eq(report.required_runtime_dependencies(), 1)
      assert_eq(report.runtime_webviews(), 1)
      assert_eq(report.command_routes(), 1)
      assert_eq(report.registered_routes(), 1)
      assert_eq(report.signing_configured(), false)
      assert_eq(report.ready(), false)
      assert_true(report.issues().contains("signing is not configured"))
      assert_true(report.to_json().contains("\"ready\":false"))
    }
    Err(problems) => abort(problems.join(", "))
  }
}

///|
test "release readiness accepts configured linux signing" {
  let signing = @lepusa.SigningConfig::new(identity="release-key")
  match release_bundle(Linux, signing~).release_readiness() {
    Ok(report) => {
      assert_eq(report.target().name(), "linux")
      assert_eq(report.signing_configured(), true)
      assert_eq(report.signing_prerequisites(), 3)
      assert_eq(report.signing_steps(), 1)
      assert_eq(report.ready(), true)
      assert_eq(report.issues().length(), 0)
      assert_true(report.to_json().contains("\"signingSteps\":1"))
    }
    Err(problems) => abort(problems.join(", "))
  }
}
