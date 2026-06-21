///|
test "bundle plan builds signed update manifest from release artifacts" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    source=@lepusa.Source::html("<main></main>"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(runtime) => {
      let metadata = @lepusa.AppMetadata::new(
        identifier="dev.vectie.update",
        product_name="Update App",
        version="2.0.0",
      )
      match @lepusa.BundleConfig::new(metadata, target=Linux).plan(runtime) {
        Ok(plan) =>
          match
            plan.update_manifest(
              base_url="https://updates.example.com/releases",
              public_key="ed25519:release-key",
              artifact_trust=[
                @lepusa.UpdateArtifactTrust::new(
                  path="update-app",
                  sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  signature="sig-portable",
                ),
                @lepusa.UpdateArtifactTrust::new(
                  path="update-app/update-app.desktop",
                  sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                  signature="sig-desktop",
                ),
              ],
            ) {
            Ok(manifest) => {
              assert_eq(manifest.identifier(), "dev.vectie.update")
              assert_eq(manifest.product_name(), "Update App")
              assert_eq(manifest.version(), "2.0.0")
              assert_eq(manifest.channel(), "stable")
              assert_eq(manifest.public_key().unwrap(), "ed25519:release-key")
              assert_eq(manifest.artifacts().length(), 2)
              assert_true(manifest.artifacts()[0].target() is Linux)
              assert_true(
                manifest.artifacts()[0].kind() is PortableDirectoryArtifact,
              )
              assert_eq(manifest.artifacts()[0].path(), "update-app")
              assert_eq(
                manifest.artifacts()[0].url(),
                "https://updates.example.com/releases/update-app",
              )
              assert_eq(
                manifest.artifacts()[0].signature().unwrap(),
                "sig-portable",
              )
              assert_eq(manifest.validate().length(), 0)
              let report = manifest.trust_report()
              assert_true(report.trusted())
              assert_true(report.signature_required())
              assert_eq(report.artifact_count(), 2)
              assert_eq(report.signed_artifacts(), 2)
              let json = manifest.to_json()
              assert_true(json.contains("\"schemaVersion\":1"))
              assert_true(
                json.contains("\"publicKey\":\"ed25519:release-key\""),
              )
              assert_true(json.contains("\"signature\":\"sig-desktop\""))
              match
                plan.update_manifest_json(
                  base_url="https://updates.example.com/releases/",
                  public_key="ed25519:release-key",
                  artifact_trust=[
                    @lepusa.UpdateArtifactTrust::new(
                      path="update-app",
                      sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                      signature="sig-portable",
                    ),
                    @lepusa.UpdateArtifactTrust::new(
                      path="update-app/update-app.desktop",
                      sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                      signature="sig-desktop",
                    ),
                  ],
                ) {
                Ok(json) =>
                  assert_true(
                    json.contains(
                      "\"url\":\"https://updates.example.com/releases/update-app\"",
                    ),
                  )
                Err(problems) =>
                  abort(
                    "unexpected invalid update manifest json: \{problems.join("; ")}",
                  )
              }
            }
            Err(problems) =>
              abort(
                "unexpected invalid update manifest: \{problems.join("; ")}",
              )
          }
        Err(_) => abort("unexpected invalid bundle plan")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "update manifest generation rejects incomplete artifact trust" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root).window(
    source=@lepusa.Source::html("<main></main>"),
  )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(runtime) => {
      let metadata = @lepusa.AppMetadata::new(
        identifier="dev.vectie.update.invalid",
        product_name="Invalid Update App",
        version="2.0.0",
      )
      match @lepusa.BundleConfig::new(metadata, target=Linux).plan(runtime) {
        Ok(plan) =>
          match
            plan.update_manifest(
              base_url="http://updates.example.com/releases",
              public_key="ed25519:release-key",
              artifact_trust=[
                @lepusa.UpdateArtifactTrust::new(
                  path="update-app",
                  sha256="not-a-sha",
                ),
                @lepusa.UpdateArtifactTrust::new(
                  path="extra.zip",
                  sha256="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                ),
              ],
            ) {
            Ok(_) => abort("unexpected valid update manifest")
            Err(problems) => {
              assert_true(problems.contains("update base url must use https"))
              assert_true(
                problems.contains(
                  "update artifact sha256 must be 64 lowercase hex characters: update-app",
                ),
              )
              assert_true(
                problems.contains(
                  "update artifact trust path is not a bundle artifact: extra.zip",
                ),
              )
              assert_true(
                problems.contains(
                  "update artifact trust is missing: invalid-update-app",
                ),
              )
            }
          }
        Err(_) => abort("unexpected invalid bundle plan")
      }
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "update trust report requires public key for native updates" {
  let artifact = @lepusa.UpdateManifestArtifact::new(
    target=MacOS,
    kind=DiskImageArtifact,
    path="demo.dmg",
    url="https://updates.example.com/demo.dmg",
    sha256="dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
  )
  let manifest = @lepusa.UpdateManifest::new(
    identifier="dev.vectie.demo",
    product_name="Demo",
    version="1.0.0",
    artifacts=[artifact],
  )
  assert_eq(manifest.validate().length(), 0)
  let report = manifest.trust_report()
  assert_false(report.trusted())
  assert_false(report.signature_required())
  assert_eq(report.signed_artifacts(), 0)
  assert_true(
    report
    .problems()
    .contains("update public key is required for trusted native updates"),
  )
  assert_true(report.to_json().contains("\"trusted\":false"))
}
