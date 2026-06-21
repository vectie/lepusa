///|
fn executor_plan() -> DeploymentPlan {
  match
    DeploymentPlan::from_update_manifest(
      @lepusa.UpdateManifest::new(
        identifier="dev.vectie.executor",
        product_name="Executor App",
        version="4.0.0",
        public_key="ed25519:executor-key",
        artifacts=[
          @lepusa.UpdateManifestArtifact::new(
            target=Linux,
            kind=PortableDirectoryArtifact,
            path="executor-app",
            url="https://updates.example.com/executor-app",
            sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            signature="sig-app",
          ),
          @lepusa.UpdateManifestArtifact::new(
            target=Linux,
            kind=DesktopEntryArtifact,
            path="executor-app/executor-app.desktop",
            url="https://updates.example.com/executor-app/executor-app.desktop",
            sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            signature="sig-desktop",
          ),
        ],
      ),
      target=Linux,
      install_root="/opt/executor-app",
      staging_root="/var/lib/lepusa/executor-app",
      current_version="3.0.0",
    ) {
    Ok(plan) => plan
    Err(problems) =>
      abort("unexpected invalid executor plan: \{problems.join("; ")}")
  }
}

///|
test "deployment dry run reports committed transaction without restart" {
  let report = executor_plan().dry_run()
  assert_true(report.dry_run())
  assert_true(report.committed())
  assert_false(report.rolled_back())
  assert_true(report.ok())
  assert_eq(report.failed_count(), 0)
  assert_eq(report.rolled_back_count(), 0)
  assert_eq(report.completed_count(), 12)
  assert_eq(report.skipped_count(), 3)
  assert_true(report.first_failure_message() is None)
  assert_true(report.outcomes()[0].status() is DeploymentStepCompleted(_))
  assert_true(
    report.summary().contains("step: restart-application status=skipped"),
  )
  assert_true(report.to_json().contains("\"committed\":true"))
  assert_true(report.to_json().contains("\"firstFailure\":null"))
}

///|
test "deployment dry run can include delegated restart step" {
  let report = executor_plan().dry_run(allow_restart=true)
  assert_true(report.committed())
  assert_eq(report.failed_count(), 0)
  assert_eq(report.completed_count(), 13)
  assert_eq(report.skipped_count(), 2)
  assert_true(
    report.summary().contains("step: restart-application status=completed"),
  )
}

///|
test "deployment dry run rolls back installed artifacts after injected failure" {
  let report = executor_plan().dry_run(fail_at=InstallUpdateArtifact)
  assert_false(report.committed())
  assert_false(report.ok())
  assert_false(report.rolled_back())
  assert_eq(report.failed_count(), 1)
  assert_eq(report.rolled_back_count(), 0)
  assert_true(
    report
    .first_failure_message()
    .unwrap()
    .contains("dry-run injected failure at install-update-artifact"),
  )
  assert_true(report.to_json().contains("\"committed\":false"))
  assert_true(report.to_json().contains("\"failed\":1"))
}

///|
test "deployment dry run rolls back previous artifact when later install fails" {
  let report = executor_plan().dry_run(
    fail_at=RestartApplication,
    allow_restart=true,
  )
  assert_false(report.committed())
  assert_true(report.rolled_back())
  assert_eq(report.failed_count(), 1)
  assert_eq(report.rolled_back_count(), 2)
  assert_true(report.to_json().contains("\"status\":\"rolled-back\""))
  assert_true(
    report.summary().contains("dry-run rollback restored executor-app"),
  )
}
