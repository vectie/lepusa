///|
fn render_runtime_asset_text(
  manifest_path : String,
  text : String,
  url : String,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(manifest_path, text) {
    Ok(manifest) => runtime_ok(manifest.resolve_asset_json(url) + "\n")
    Err(problem) => runtime_fail("Lepusa runtime asset\n[fail] \{problem}\n")
  }
}
