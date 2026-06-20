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
      runtime_ok(
        runtime_launch_readiness(
          "macos",
          result.plan().launch_session(bridge_mode~),
        ).to_json() +
        "\n",
      )
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
        Ok(session) =>
          runtime_ok(
            runtime_launch_readiness("linux", session).to_json() + "\n",
          )
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
        Ok(session) =>
          runtime_ok(
            runtime_launch_readiness("windows", session).to_json() + "\n",
          )
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
fn runtime_launch_readiness(
  target : String,
  session : @runtime_core.NativeLaunchSession,
) -> @runtime_core.NativeLaunchReadiness {
  @runtime_core.NativeLaunchReadiness::new(
    target~,
    platform_name=runtime_target_display_name(target),
    session~,
    capability=runtime_launch_capability_for_target(target),
    preflight=runtime_backend_preflight_for_target(target),
  )
}

///|
fn runtime_launch_capability_for_target(
  target : String,
) -> @runtime_core.NativeLaunchCapability {
  match target {
    "macos" => @macos.launch_capability()
    "linux" => @linux.launch_capability()
    "windows" => @windows.launch_capability()
    _ =>
      @runtime_core.NativeLaunchCapability::new(
        webview_creation=false,
        async_bridge_drain=false,
        webview_creation_message="unknown native launch target: \{target}",
      )
  }
}

///|
fn runtime_backend_preflight_for_target(
  target : String,
) -> @runtime_core.NativeBackendPreflight {
  match target {
    "macos" => @macos.preflight()
    "linux" => @linux.preflight()
    "windows" => @windows.preflight()
    _ =>
      @runtime_core.NativeBackendPreflight::new(
        platform=target,
        webview_engine="unknown",
        dependency_name="unknown",
        dependency_available=false,
        webview_creation_loop=false,
        async_bridge_drain=false,
        dependency_message="unknown native launch target: \{target}",
        webview_creation_message="unknown native launch target: \{target}",
      )
  }
}

///|
fn runtime_target_display_name(target : String) -> String {
  match target {
    "macos" => "macOS"
    "linux" => "Linux"
    "windows" => "Windows"
    _ => target
  }
}
