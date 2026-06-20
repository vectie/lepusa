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
      render_runtime_launch_session_text(
        path,
        text,
        bridge_mode=runtime_bridge_mode_from_args(args),
      )
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_launch_session_text(
  path : String,
  text : String,
  bridge_mode? : @runtime_core.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Err(problem) =>
      runtime_fail("Lepusa runtime launch-session\n[fail] \{problem}\n")
    Ok(manifest) => {
      let target_bridge_mode = runtime_bridge_mode_for_target(
        manifest.target(),
        bridge_mode,
      )
      match manifest.target() {
        "macos" =>
          render_macos_launch_session(manifest, bridge_mode=target_bridge_mode)
        "linux" =>
          render_linux_launch_session(manifest, bridge_mode=target_bridge_mode)
        "windows" =>
          render_windows_launch_session(
            manifest,
            bridge_mode=target_bridge_mode,
          )
        target =>
          runtime_fail(
            "Lepusa runtime launch-session\n[fail] native launch-session requires target macos, linux, or windows: \{target}\n",
          )
      }
    }
  }
}

///|
fn runtime_bridge_mode_for_target(
  target : String,
  requested : @runtime_core.NativeBridgeSchedulerMode,
) -> @runtime_core.NativeBridgeSchedulerMode {
  match requested {
    NativeBridgeSyncOnly => NativeBridgeSyncOnly
    NativeBridgeAsyncCapable =>
      match target {
        "macos" => @macos.launch_capability().bridge_mode()
        "linux" => @linux.launch_capability().bridge_mode()
        "windows" => @windows.launch_capability().bridge_mode()
        _ => NativeBridgeSyncOnly
      }
  }
}

///|
fn render_macos_launch_session(
  manifest : @bundled.BundledRuntimeManifest,
  bridge_mode? : @runtime_core.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> RuntimeCliResult {
  match @macos.run_bundled(manifest) {
    Ok(result) =>
      runtime_ok(result.plan().launch_session(bridge_mode~).to_json() + "\n")
    Err(problems) =>
      runtime_fail(
        render_runtime_run_problems("Lepusa runtime launch-session", problems),
      )
  }
}

///|
fn render_linux_launch_session(
  manifest : @bundled.BundledRuntimeManifest,
  bridge_mode? : @runtime_core.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> RuntimeCliResult {
  match @linux.run_bundled(manifest) {
    Ok(result) =>
      match result.launch_session(bridge_mode~) {
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
  bridge_mode? : @runtime_core.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> RuntimeCliResult {
  match @windows.run_bundled(manifest) {
    Ok(result) =>
      match result.launch_session(bridge_mode~) {
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
