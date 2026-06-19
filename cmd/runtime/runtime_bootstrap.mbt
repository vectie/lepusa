///|
async fn render_runtime_bootstrap(args : Array[String]) -> RuntimeCliResult {
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime bootstrap\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_bootstrap_text(path, text)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_bootstrap_text(
  path : String,
  text : String,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) => runtime_ok(manifest.bootstrap_json() + "\n")
    Err(problem) =>
      runtime_fail("Lepusa runtime bootstrap\n[fail] \{problem}\n")
  }
}
