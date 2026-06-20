///|
async fn render_runtime_launch_session(
  args : Array[String],
) -> RuntimeCliResult {
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime launch-session\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_launch_session_text(path, text)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_launch_session_text(
  path : String,
  text : String,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Err(problem) =>
      runtime_fail("Lepusa runtime launch-session\n[fail] \{problem}\n")
    Ok(manifest) =>
      match manifest.target() {
        "macos" => render_macos_launch_session(manifest)
        "linux" => render_linux_launch_session(manifest)
        "windows" => render_windows_launch_session(manifest)
        target =>
          runtime_fail(
            "Lepusa runtime launch-session\n[fail] native launch-session requires target macos, linux, or windows: \{target}\n",
          )
      }
  }
}

///|
fn render_macos_launch_session(
  manifest : @bundled.BundledRuntimeManifest,
) -> RuntimeCliResult {
  match @macos.run_bundled(manifest) {
    Ok(result) => runtime_ok(result.plan().launch_session().to_json() + "\n")
    Err(problems) =>
      runtime_fail(
        render_runtime_run_problems("Lepusa runtime launch-session", problems),
      )
  }
}

///|
fn render_linux_launch_session(
  manifest : @bundled.BundledRuntimeManifest,
) -> RuntimeCliResult {
  match @linux.run_bundled(manifest) {
    Ok(result) =>
      match result.launch_session() {
        Ok(session) => runtime_ok(session.to_json() + "\n")
        Err(problem) =>
          runtime_fail("Lepusa runtime launch-session\n[fail] \{problem}\n")
      }
    Err(problems) =>
      runtime_fail(
        render_runtime_run_problems("Lepusa runtime launch-session", problems),
      )
  }
}

///|
fn render_windows_launch_session(
  manifest : @bundled.BundledRuntimeManifest,
) -> RuntimeCliResult {
  match @windows.run_bundled(manifest) {
    Ok(result) =>
      match result.launch_session() {
        Ok(session) => runtime_ok(session.to_json() + "\n")
        Err(problem) =>
          runtime_fail("Lepusa runtime launch-session\n[fail] \{problem}\n")
      }
    Err(problems) =>
      runtime_fail(
        render_runtime_run_problems("Lepusa runtime launch-session", problems),
      )
  }
}
