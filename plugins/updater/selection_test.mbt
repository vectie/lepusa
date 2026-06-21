///|
fn updater_manifest(
  version? : String = "2.0.0",
  channel? : String = "stable",
  target? : @lepusa.BundleTarget = Linux,
) -> @lepusa.UpdateManifest {
  @lepusa.UpdateManifest::new(
    identifier="dev.vectie.updater-selection",
    product_name="Updater Selection",
    version~,
    channel~,
    public_key="ed25519:selection-key",
    artifacts=[
      @lepusa.UpdateManifestArtifact::new(
        target~,
        kind=PortableDirectoryArtifact,
        path="updater-selection",
        url="https://updates.example.com/updater-selection",
        sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        signature="sig-app",
      ),
    ],
  )
}

///|
fn updater_policy(
  channel? : String = "stable",
  allow_prerelease? : Bool = false,
) -> UpdaterPolicy {
  UpdaterPolicy::new(
    feed_url="https://updates.example.com/app.json",
    channel~,
    public_key="ed25519:selection-key",
    allow_prerelease~,
  )
}

///|
test "updater policy selects trusted newer target update" {
  let decision = updater_policy().select_update(
    updater_manifest(),
    current_version="1.5.0",
    target=Linux,
  )
  assert_true(decision.kind() is UpdateSelected)
  assert_true(decision.update_available())
  assert_eq(decision.current_version(), "1.5.0")
  assert_eq(decision.candidate_version().unwrap(), "2.0.0")
  assert_true(decision.target() is Linux)
  assert_eq(decision.artifact_count(), 1)
  assert_true(decision.trust().trusted())
  assert_eq(decision.reason(), "update candidate is newer than current version")
  assert_true(decision.to_json().contains("\"kind\":\"update-selected\""))
  assert_true(decision.to_json().contains("\"updateAvailable\":true"))
}

///|
test "updater policy reports no update for stale or equal versions" {
  let stale = updater_policy().select_update(
    updater_manifest(version="1.0.0"),
    current_version="1.0.1",
    target=Linux,
  )
  assert_true(stale.kind() is NoUpdate)
  assert_false(stale.update_available())
  assert_eq(
    stale.reason(),
    "update candidate is not newer than current version",
  )
  let equal = updater_policy().select_update(
    updater_manifest(version="1.0.1"),
    current_version="1.0.1",
    target=Linux,
  )
  assert_true(equal.kind() is NoUpdate)
}

///|
test "updater policy gates prerelease candidates" {
  let blocked = updater_policy().select_update(
    updater_manifest(version="2.0.0-beta.1"),
    current_version="1.9.0",
    target=Linux,
  )
  assert_true(blocked.kind() is NoUpdate)
  assert_false(blocked.update_available())
  assert_eq(
    blocked.reason(),
    "update candidate is prerelease and policy disallows prerelease",
  )
  let allowed = updater_policy(allow_prerelease=true).select_update(
    updater_manifest(version="2.0.0-beta.1"),
    current_version="2.0.0-alpha.1",
    target=Linux,
  )
  assert_true(allowed.kind() is UpdateSelected)
}

///|
test "updater policy rejects incompatible manifest metadata" {
  let wrong_channel = updater_policy(channel="stable").select_update(
    updater_manifest(channel="beta"),
    current_version="1.0.0",
    target=Linux,
  )
  assert_true(wrong_channel.kind() is UpdateRejected)
  assert_eq(
    wrong_channel.reason(),
    "update channel does not match policy: beta",
  )
  let wrong_target = updater_policy().select_update(
    updater_manifest(target=MacOS),
    current_version="1.0.0",
    target=Linux,
  )
  assert_true(wrong_target.kind() is UpdateRejected)
  assert_eq(wrong_target.artifact_count(), 0)
  assert_true(wrong_target.reason().contains("no artifact for target: linux"))
}

///|
test "updater policy rejects untrusted or unparsable update versions" {
  let unsigned = @lepusa.UpdateManifest::new(
    identifier="dev.vectie.unsigned",
    product_name="Unsigned",
    version="2.0.0",
    artifacts=[
      @lepusa.UpdateManifestArtifact::new(
        target=Linux,
        kind=PortableDirectoryArtifact,
        path="unsigned",
        url="https://updates.example.com/unsigned",
        sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      ),
    ],
  )
  let untrusted = updater_policy().select_update(
    unsigned,
    current_version="1.0.0",
    target=Linux,
  )
  assert_true(untrusted.kind() is UpdateRejected)
  assert_true(
    untrusted
    .reason()
    .contains("update public key is required for trusted native updates"),
  )
  let invalid = updater_policy().select_update(
    updater_manifest(version="next"),
    current_version="1.0.0",
    target=Linux,
  )
  assert_true(invalid.kind() is UpdateRejected)
  assert_eq(
    invalid.reason(),
    "update version comparison requires numeric major.minor.patch versions",
  )
}
