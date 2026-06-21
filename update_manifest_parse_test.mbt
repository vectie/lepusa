///|
test "update manifest parser round trips generated manifest json" {
  let manifest = @lepusa.UpdateManifest::new(
    identifier="dev.vectie.parse",
    product_name="Parse App",
    version="1.2.3",
    channel="stable",
    public_key="ed25519:parse-key",
    artifacts=[
      @lepusa.UpdateManifestArtifact::new(
        target=Linux,
        kind=PortableDirectoryArtifact,
        path="parse-app",
        url="https://updates.example.com/parse-app",
        sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        signature="sig-app",
      ),
      @lepusa.UpdateManifestArtifact::new(
        target=Linux,
        kind=DesktopEntryArtifact,
        path="parse-app/parse-app.desktop",
        url="https://updates.example.com/parse-app/parse-app.desktop",
        sha256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        signature="sig-desktop",
      ),
    ],
  )
  match @lepusa.UpdateManifest::parse(manifest.to_json()) {
    Ok(parsed) => {
      assert_eq(parsed.identifier(), "dev.vectie.parse")
      assert_eq(parsed.product_name(), "Parse App")
      assert_eq(parsed.version(), "1.2.3")
      assert_eq(parsed.channel(), "stable")
      assert_eq(parsed.public_key().unwrap(), "ed25519:parse-key")
      assert_eq(parsed.artifacts().length(), 2)
      assert_true(parsed.artifacts()[0].target() is Linux)
      assert_true(parsed.artifacts()[0].kind() is PortableDirectoryArtifact)
      assert_eq(parsed.artifacts()[0].signature().unwrap(), "sig-app")
      assert_true(parsed.trust_report().trusted())
    }
    Err(problems) =>
      abort("unexpected invalid update manifest: \{problems.join("; ")}")
  }
}

///|
test "update manifest parser validates required release metadata" {
  match
    @lepusa.UpdateManifest::parse(
      (
        #|{
        #|  "schemaVersion": 2,
        #|  "identifier": "",
        #|  "productName": "Broken",
        #|  "version": "1.0.0",
        #|  "channel": "weird",
        #|  "publicKey": 12,
        #|  "artifacts": [
        #|    {
        #|      "target": "ios",
        #|      "kind": "zip",
        #|      "path": "broken.zip",
        #|      "url": "http://updates.example.com/broken.zip",
        #|      "sha256": "not-a-sha"
        #|    }
        #|  ]
        #|}
      ),
    ) {
    Ok(_) => abort("unexpected valid update manifest")
    Err(problems) => {
      assert_true(problems.contains("update schemaVersion must be 1"))
      assert_true(problems.contains("update identifier must not be empty"))
      assert_true(
        problems.contains("update publicKey must be a string or null"),
      )
      assert_true(
        problems.contains("update artifact target is invalid at 0: ios"),
      )
      assert_true(
        problems.contains("update artifact kind is invalid at 0: zip"),
      )
      assert_true(problems.contains("update channel is invalid: weird"))
      assert_true(problems.contains("update artifacts must not be empty"))
    }
  }
}
