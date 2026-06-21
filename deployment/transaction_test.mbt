///|
fn signed_manifest() -> @lepusa.UpdateManifest {
  @lepusa.UpdateManifest::new(
    identifier="dev.vectie.deploy",
    product_name="Deploy App",
    version="3.0.0",
    channel="stable",
    public_key="ed25519:deploy-key",
    artifacts=[
      @lepusa.UpdateManifestArtifact::new(
        target=Linux,
        kind=PortableDirectoryArtifact,
        path="deploy-app",
        url="https://updates.example.com/deploy-app",
        sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        signature="sig-app",
      ),
      @lepusa.UpdateManifestArtifact::new(
        target=Linux,
        kind=DesktopEntryArtifact,
        path="deploy-app/deploy-app.desktop",
        url="https://updates.example.com/deploy-app/deploy-app.desktop",
        sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        signature="sig-desktop",
      ),
      @lepusa.UpdateManifestArtifact::new(
        target=MacOS,
        kind=DiskImageArtifact,
        path="deploy-app.dmg",
        url="https://updates.example.com/deploy-app.dmg",
        sha256="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
        signature="sig-dmg",
      ),
    ],
  )
}

///|
test "deployment plan turns a trusted update manifest into a rollback transaction" {
  match
    DeploymentPlan::from_update_manifest(
      signed_manifest(),
      target=Linux,
      install_root="/opt/deploy-app",
      staging_root="/var/lib/lepusa/deploy-app",
      current_version="2.0.0",
    ) {
    Ok(plan) => {
      assert_true(plan.target() is Linux)
      assert_true(plan.mode() is UpdateInstall)
      assert_eq(plan.identifier(), "dev.vectie.deploy")
      assert_eq(plan.product_name(), "Deploy App")
      assert_eq(plan.version(), "3.0.0")
      assert_eq(plan.channel(), "stable")
      assert_eq(plan.install_root(), "/opt/deploy-app")
      assert_eq(plan.staging_root(), "/var/lib/lepusa/deploy-app")
      assert_true(plan.trust().trusted())
      assert_true(plan.ready())
      assert_eq(plan.steps().length(), 15)
      assert_eq(plan.steps_by_kind(ValidateUpdateManifest).length(), 1)
      assert_eq(plan.steps_by_kind(DownloadUpdateArtifact).length(), 2)
      assert_eq(plan.steps_by_kind(VerifyArtifactChecksum).length(), 2)
      assert_eq(plan.steps_by_kind(VerifyArtifactSignature).length(), 2)
      assert_eq(plan.steps_by_kind(StageUpdateArtifact).length(), 2)
      assert_eq(plan.steps_by_kind(BackupCurrentInstall).length(), 1)
      assert_eq(plan.steps_by_kind(InstallUpdateArtifact).length(), 2)
      assert_eq(plan.rollback_steps().length(), 2)
      assert_eq(plan.steps_by_kind(RestartApplication).length(), 1)
      let download = plan.steps_by_kind(DownloadUpdateArtifact)[0]
      assert_eq(download.artifact_path().unwrap(), "deploy-app")
      assert_eq(
        download.source().unwrap(),
        "https://updates.example.com/deploy-app",
      )
      assert_eq(
        download.destination().unwrap(),
        "/var/lib/lepusa/deploy-app/download/deploy-app",
      )
      assert_true(plan.summary().contains("mode: update-install"))
      assert_true(plan.summary().contains("rollback-steps: 2"))
      assert_true(plan.to_json().contains("\"ready\":true"))
      assert_true(
        plan.to_json().contains("\"kind\":\"verify-artifact-signature\""),
      )
    }
    Err(problems) =>
      abort("unexpected invalid deployment plan: \{problems.join("; ")}")
  }
}

///|
test "deployment plan rejects unsigned manifests by default" {
  let manifest = @lepusa.UpdateManifest::new(
    identifier="dev.vectie.unsigned",
    product_name="Unsigned",
    version="1.0.0",
    artifacts=[
      @lepusa.UpdateManifestArtifact::new(
        target=Linux,
        kind=PortableDirectoryArtifact,
        path="unsigned",
        url="https://updates.example.com/unsigned",
        sha256="dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      ),
    ],
  )
  match
    DeploymentPlan::from_update_manifest(
      manifest,
      target=Linux,
      install_root="/opt/unsigned",
      staging_root="/var/lib/lepusa/unsigned",
    ) {
    Ok(_) => abort("unexpected valid unsigned deployment plan")
    Err(problems) =>
      assert_true(
        problems.contains(
          "update public key is required for trusted native updates",
        ),
      )
  }
}

///|
test "deployment plan validates target selection and roots" {
  match
    DeploymentPlan::from_update_manifest(
      signed_manifest(),
      target=Windows,
      install_root="/same",
      staging_root="/same",
      current_version="",
    ) {
    Ok(_) => abort("unexpected valid deployment plan")
    Err(problems) => {
      assert_true(
        problems.contains(
          "deployment install root and staging root must be different",
        ),
      )
      assert_true(
        problems.contains("deployment current version must not be empty"),
      )
      assert_true(
        problems.contains(
          "deployment update manifest has no artifacts for target: windows",
        ),
      )
    }
  }
}
