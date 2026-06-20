///|
test "distribution manifest parser exposes installer-facing bundle data" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    source=@lepusa.Source::html("<main></main>"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(runtime) => {
      let metadata = @lepusa.AppMetadata::new(
        identifier="dev.local.distribution",
        product_name="Distribution App",
        version="1.0.0",
      )
      match @lepusa.BundleConfig::new(metadata, target=Linux).plan(runtime) {
        Ok(plan) =>
          match
            BundleDistributionManifest::parse(
              "app/lepusa/distribution.json",
              plan.distribution_manifest_json(),
            ) {
            Ok(manifest) => {
              assert_eq(manifest.path(), "app/lepusa/distribution.json")
              assert_eq(manifest.identifier(), "dev.local.distribution")
              assert_eq(manifest.product_name(), "Distribution App")
              assert_eq(manifest.version(), "1.0.0")
              assert_eq(manifest.target(), "linux")
              assert_eq(manifest.executable(), "distribution-app")
              assert_eq(manifest.bundle(), "distribution-app")
              assert_eq(
                manifest.runtime_executable(),
                "distribution-app/lepusa-runtime",
              )
              assert_eq(manifest.artifacts().length(), 2)
              assert_eq(manifest.resources().length(), 0)
              assert_eq(manifest.runtime_dependencies().length(), 1)
              assert_eq(manifest.signing_prerequisites().length(), 2)
              assert_eq(manifest.signing_steps().length(), 0)
              assert_false(manifest.signing_configured())
              assert_true(
                manifest.runtime_dependencies()[0].contains("WebKitGTK"),
              )
              assert_true(manifest.summary().contains("target: linux"))
              assert_true(
                manifest
                .to_json()
                .contains("\"productName\":\"Distribution App\""),
              )
              let release = manifest.release_plan()
              assert_eq(release.steps().length(), 5)
              assert_eq(
                release.steps()[0].kind().name(),
                "validate-runtime-dependencies",
              )
              assert_eq(release.steps()[0].item_count(), 1)
              assert_eq(release.steps()[1].kind().name(), "stage-resources")
              assert_false(release.steps()[1].required())
              assert_eq(
                release.steps()[2].kind().name(),
                "validate-signing-prerequisites",
              )
              assert_eq(release.steps()[2].item_count(), 2)
              assert_eq(release.steps()[3].kind().name(), "run-signing-steps")
              assert_false(release.steps()[3].required())
              assert_eq(release.required_steps().length(), 3)
              assert_true(release.summary().contains("step: collect-artifacts"))
              assert_true(
                release.to_json().contains("\"kind\":\"collect-artifacts\""),
              )
            }
            Err(problem) => abort("unexpected invalid distribution: \{problem}")
          }
        Err(_) => abort("unexpected invalid bundle plan")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "distribution manifest parser validates required fields" {
  match BundleDistributionManifest::parse("distribution.json", "{}") {
    Ok(_) => abort("unexpected valid distribution manifest")
    Err(problem) => {
      assert_true(
        problem.contains("distribution identifier string is required"),
      )
      assert_true(problem.contains("distribution artifacts array is required"))
      assert_true(
        problem.contains("distribution runtimeDependencies array is required"),
      )
    }
  }
}
