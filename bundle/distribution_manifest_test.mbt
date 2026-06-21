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
              let dependency_entries = manifest.runtime_dependency_entries()
              assert_eq(dependency_entries.length(), 1)
              assert_eq(dependency_entries[0].kind(), "system-webview-runtime")
              assert_eq(dependency_entries[0].name(), "WebKitGTK 4.1 or 4.0")
              assert_true(dependency_entries[0].path() is None)
              assert_true(dependency_entries[0].source_path() is None)
              assert_true(dependency_entries[0].required())
              assert_true(
                dependency_entries[0].description().contains("Linux WebView"),
              )
              let artifact_entries = manifest.artifact_entries()
              assert_eq(artifact_entries.length(), 2)
              assert_eq(artifact_entries[0].kind(), "portable-directory")
              assert_eq(artifact_entries[0].path().unwrap(), "distribution-app")
              assert_eq(artifact_entries[0].name(), "distribution-app")
              assert_true(manifest.summary().contains("target: linux"))
              assert_true(
                manifest
                .to_json()
                .contains("\"productName\":\"Distribution App\""),
              )
              let release = manifest.release_plan()
              assert_eq(release.steps().length(), 5)
              assert_eq(release.required_step_count(), 3)
              assert_eq(release.optional_step_count(), 2)
              assert_eq(release.required_item_count(), 5)
              assert_eq(release.optional_item_count(), 0)
              assert_true(release.ready())
              assert_true(
                release.readiness_message().contains("required release steps"),
              )
              assert_eq(release.missing_required_steps().length(), 0)
              assert_eq(
                release.steps()[0].kind().name(),
                "validate-runtime-dependencies",
              )
              assert_eq(release.steps()[0].item_count(), 1)
              assert_eq(
                release.steps()[0].items()[0].name(),
                "WebKitGTK 4.1 or 4.0",
              )
              assert_eq(release.steps()[1].kind().name(), "stage-resources")
              assert_false(release.steps()[1].required())
              assert_eq(
                release.steps()[2].kind().name(),
                "validate-signing-prerequisites",
              )
              assert_eq(release.steps()[2].item_count(), 2)
              assert_eq(
                release.steps()[2].items()[0].kind(),
                "signing-identity",
              )
              assert_eq(release.steps()[3].kind().name(), "run-signing-steps")
              assert_false(release.steps()[3].required())
              assert_eq(release.required_steps().length(), 3)
              assert_eq(release.optional_steps().length(), 2)
              assert_true(release.summary().contains("step: collect-artifacts"))
              assert_true(release.summary().contains("ready: true"))
              assert_true(
                release.to_json().contains("\"kind\":\"collect-artifacts\""),
              )
              assert_true(release.to_json().contains("\"ready\":true"))
              assert_true(release.to_json().contains("\"requiredStepCount\":3"))
              let package_plan = manifest.package_plan()
              assert_true(package_plan.ready())
              assert_eq(package_plan.package_kind(), "linux-portable-archive")
              assert_eq(package_plan.commands().length(), 2)
              assert_eq(package_plan.outputs().length(), 3)
              assert_eq(package_plan.script_name(), "package.sh")
              assert_eq(
                package_plan.commands()[0].tool(),
                "desktop-file-validate",
              )
              assert_eq(package_plan.commands()[1].tool(), "tar")
              assert_true(
                package_plan.commands()[1]
                .arguments()
                .contains("distribution-app-1.0.0-linux.tar.gz"),
              )
              assert_true(
                package_plan
                .summary()
                .contains("package-kind: linux-portable-archive"),
              )
              assert_true(
                package_plan
                .to_json()
                .contains("\"packageKind\":\"linux-portable-archive\""),
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
test "release plan reports missing required release data" {
  match
    BundleDistributionManifest::parse(
      "app/lepusa/distribution.json",
      (
        #|{
        #|  "identifier": "dev.local.missing",
        #|  "productName": "Missing Release Data",
        #|  "version": "1.0.0",
        #|  "target": "linux",
        #|  "executable": "missing",
        #|  "bundle": "missing",
        #|  "runtimeExecutable": "missing/lepusa-runtime",
        #|  "artifacts": [
        #|    { "kind": "portable-directory", "name": "missing", "path": "missing" }
        #|  ],
        #|  "resources": [],
        #|  "runtimeDependencies": [
        #|    { "kind": "system-webview-runtime", "name": "WebKitGTK", "required": true }
        #|  ],
        #|  "signing": {},
        #|  "signingPrerequisites": [],
        #|  "signingSteps": []
        #|}
      ),
    ) {
    Ok(manifest) => {
      let release = manifest.release_plan()
      assert_false(release.ready())
      assert_eq(release.missing_required_steps().length(), 1)
      assert_eq(
        release.missing_required_steps()[0].kind().name(),
        "validate-signing-prerequisites",
      )
      assert_true(
        release.readiness_message().contains("validate-signing-prerequisites"),
      )
      assert_true(release.to_json().contains("\"ready\":false"))
      assert_true(release.to_json().contains("\"missingRequiredSteps\":[{"))
    }
    Err(problem) => abort("unexpected invalid distribution: \{problem}")
  }
}

///|
test "package plan reports missing target package artifacts" {
  match
    BundleDistributionManifest::parse(
      "app/lepusa/distribution.json",
      (
        #|{
        #|  "identifier": "dev.local.package",
        #|  "productName": "Package Data",
        #|  "version": "1.0.0",
        #|  "target": "windows",
        #|  "executable": "package-data",
        #|  "bundle": "package-data.exe",
        #|  "runtimeExecutable": "package-data/lepusa-runtime.exe",
        #|  "artifacts": [
        #|    { "kind": "executable", "name": "package-data.exe", "path": "package-data/package-data.exe" }
        #|  ],
        #|  "resources": [],
        #|  "runtimeDependencies": [
        #|    { "kind": "native-loader-library", "name": "WebView2Loader.dll", "path": "package-data/WebView2Loader.dll", "required": true }
        #|  ],
        #|  "signing": {},
        #|  "signingPrerequisites": [],
        #|  "signingSteps": []
        #|}
      ),
    ) {
    Ok(manifest) => {
      let package_plan = manifest.package_plan()
      assert_false(package_plan.ready())
      assert_eq(package_plan.package_kind(), "windows-exe-installer")
      assert_eq(package_plan.script_name(), "package.ps1")
      assert_eq(package_plan.blockers().length(), 1)
      assert_eq(
        package_plan.blockers()[0],
        "missing required package artifact: installer",
      )
      assert_true(package_plan.to_json().contains("\"ready\":false"))
    }
    Err(problem) => abort("unexpected invalid distribution: \{problem}")
  }
}

///|
test "package plan emits windows package scripts" {
  match
    BundleDistributionManifest::parse(
      "/tmp/lepusa-windows-bundle/package-data/lepusa/distribution.json",
      (
        #|{
        #|  "identifier": "dev.local.package",
        #|  "productName": "Package Data",
        #|  "version": "1.0.0",
        #|  "target": "windows",
        #|  "executable": "package-data",
        #|  "bundle": "package-data.exe",
        #|  "runtimeExecutable": "package-data/lepusa-runtime.exe",
        #|  "artifacts": [
        #|    { "kind": "executable", "name": "package-data.exe", "path": "package-data/package-data.exe" },
        #|    { "kind": "installer", "name": "package-data setup", "path": "package-data-1.0.0-setup.exe" }
        #|  ],
        #|  "resources": [],
        #|  "runtimeDependencies": [
        #|    { "kind": "native-loader-library", "name": "WebView2Loader.dll", "path": "package-data/WebView2Loader.dll", "required": true }
        #|  ],
        #|  "signing": {},
        #|  "signingPrerequisites": [],
        #|  "signingSteps": []
        #|}
      ),
    ) {
    Ok(manifest) => {
      let package_plan = manifest.package_plan()
      assert_true(package_plan.ready())
      assert_eq(package_plan.commands().length(), 2)
      assert_eq(package_plan.script_name(), "package.ps1")
      let script = package_plan.package_script()
      assert_true(script.contains("Set-Location $BundleRoot"))
      assert_true(script.contains("makensis"))
      let installer = package_plan.windows_installer_script()
      assert_true(
        installer.contains("OutFile \"package-data-1.0.0-setup.exe\""),
      )
      assert_true(installer.contains("File /r \"package-data\\*\""))
    }
    Err(problem) => abort("unexpected invalid distribution: \{problem}")
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
