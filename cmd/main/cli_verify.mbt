///|
async fn render_verify_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let strict = has_flag(args, "--strict")
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match project_bundle_plan(args, target) {
            Ok(bundle) => render_verify_project(target, host, bundle, strict~)
            Err(problems) => fail(render_problems("Lepusa verify", problems))
          }
        Err(problems) => fail(render_problems("Lepusa verify", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_verify_project(
  target : @lepusa.BundleTarget,
  host : @runtime.RuntimeHost,
  bundle : @lepusa.BundlePlan,
  strict~ : Bool,
) -> CliResult {
  let lines : Array[String] = ["Lepusa verify\n", "target: \{target.name()}\n"]
  if strict {
    lines.push("mode: strict\n")
  }
  let mut passed = true
  passed = verify_runtime_plan(host, lines) && passed
  passed = verify_dev_plan(host, lines) && passed
  passed = verify_launch_manifest(host, lines) && passed
  passed = verify_handler_coverage(host, lines, strict~) && passed
  passed = verify_native_session(target, host, lines, strict~) && passed
  passed = verify_bundle_contract(bundle, lines) && passed
  if passed {
    ok(lines.join(""))
  } else {
    fail(lines.join(""))
  }
}

///|
fn verify_runtime_plan(
  host : @runtime.RuntimeHost,
  lines : Array[String],
) -> Bool {
  let plan = host.plan()
  lines.push(
    "[ok] plan: windows=\{plan.window_count()} routes=\{plan.command_routes().length()} capabilities=\{plan.capability_count()}\n",
  )
  true
}

///|
fn verify_dev_plan(host : @runtime.RuntimeHost, lines : Array[String]) -> Bool {
  match host.dev_plan() {
    Ok(dev) => {
      lines.push(
        "[ok] dev: webviews=\{dev.webviews().length()} startup=\{dev.startup_operations().length()} lifecycle=\{dev.lifecycle_steps().length()} bridge-sync=\{dev.bridge_sync_routes().length()} bridge-async=\{dev.bridge_async_routes().length()}\n",
      )
      true
    }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
fn verify_launch_manifest(
  host : @runtime.RuntimeHost,
  lines : Array[String],
) -> Bool {
  match host.launch_manifest() {
    Ok(manifest) => {
      lines.push(
        "[ok] manifest: webviews=\{manifest.webviews().length()} routes=\{manifest.command_routes().length()} local-services=\{manifest.local_services().length()} filesystem-scopes=\{manifest.file_system_scopes().length()}\n",
      )
      let bridge_asset = host.resolve_asset_json(manifest.bridge_url())
      if bridge_asset.contains("\"ok\":true") {
        lines.push("[ok] asset: bridge \{manifest.bridge_url()}\n")
        true
      } else {
        lines.push("[fail] asset: bridge \{manifest.bridge_url()}\n")
        false
      }
    }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
fn verify_native_session(
  target : @lepusa.BundleTarget,
  host : @runtime.RuntimeHost,
  lines : Array[String],
  strict~ : Bool,
) -> Bool {
  match native_runtime_for_target(target, host) {
    Ok(runtime) =>
      match verify_native_dry_run(target, runtime) {
        Ok(session) => {
          lines.push(verify_native_session_summary(session))
          verify_release_launch_gate(target, session, lines, strict~)
        }
        Err(problems) => {
          lines.push(render_problem_lines(problems))
          false
        }
      }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
fn verify_native_dry_run(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
) -> Result[@runtime.NativeLaunchSession, Array[String]] {
  match target {
    MacOS =>
      match @macos_backend.run(runtime) {
        Ok(result) => {
          let session = result.plan().launch_session()
          Ok(session)
        }
        Err(problems) => Err(problems)
      }
    Windows =>
      match @windows_backend.run(runtime) {
        Ok(result) => Ok(result.launch_session())
        Err(problems) => Err(problems)
      }
    Linux =>
      match @linux_backend.run(runtime) {
        Ok(result) => Ok(result.launch_session())
        Err(problems) => Err(problems)
      }
  }
}

///|
fn verify_native_session_summary(
  session : @runtime.NativeLaunchSession,
) -> String {
  "[ok] native-session: webviews=\{session.webviews().length()} startup=\{session.execution().startup_operations().length()} lifecycle=\{session.execution().lifecycle_steps().length()} can-launch=\{session.can_launch()}\n"
}

///|
fn verify_handler_coverage(
  host : @runtime.RuntimeHost,
  lines : Array[String],
  strict~ : Bool,
) -> Bool {
  let missing = missing_handler_routes(host)
  lines.push(render_handler_coverage(host))
  if strict && !missing.is_empty() {
    lines.push(
      "[fail] strict: missing concrete handlers for \{missing.length()} route(s)\n",
    )
    false
  } else {
    true
  }
}

///|
fn missing_handler_routes(host : @runtime.RuntimeHost) -> Array[String] {
  let declared = handler_required_routes(host)
  let registered = host.registry().routes()
  let missing : Array[String] = []
  for route in declared {
    if !registered.contains(route) {
      missing.push(route)
    }
  }
  missing
}

///|
fn verify_release_launch_gate(
  target : @lepusa.BundleTarget,
  session : @runtime.NativeLaunchSession,
  lines : Array[String],
  strict~ : Bool,
) -> Bool {
  if !strict {
    return true
  }
  match
    session.launch_blocker_with_capability(
      verify_target_display_name(target),
      native_launch_capability_for_target(target),
    ) {
    Some(problem) => {
      lines.push("[fail] strict: \{problem}\n")
      false
    }
    None => {
      lines.push("[ok] strict: native launch gate passed\n")
      true
    }
  }
}

///|
fn verify_target_display_name(target : @lepusa.BundleTarget) -> String {
  match target {
    MacOS => "macOS"
    Windows => "Windows"
    Linux => "Linux"
  }
}

///|
fn verify_bundle_contract(
  bundle : @lepusa.BundlePlan,
  lines : Array[String],
) -> Bool {
  match bundle.files() {
    Ok(files) =>
      match bundle.runtime_manifest() {
        Ok(manifest) => {
          lines.push(
            "[ok] bundle: files=\{files.length()} resources=\{bundle.resources().length()} runtime-webviews=\{manifest.webviews().length()} signing-prerequisites=\{bundle.signing_prerequisites().length()}\n",
          )
          true
        }
        Err(problems) => {
          lines.push(render_problem_lines(problems))
          false
        }
      }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
fn render_problem_lines(problems : Array[String]) -> String {
  problems.map(fn(problem) { "[fail] \{problem}\n" }).join("")
}
