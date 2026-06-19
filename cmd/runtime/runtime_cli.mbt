///|
struct RuntimeCliResult {
  exit_code : Int
  output : String
} derive(Debug, Eq)

///|
fn drop_program(argv : Array[String]) -> Array[String] {
  let args : Array[String] = []
  for i in 1..<argv.length() {
    args.push(argv[i])
  }
  args
}

///|
async fn render_runtime_cli_async(args : Array[String]) -> RuntimeCliResult {
  match args.get(0) {
    Some("help") | Some("--help") | Some("-h") => runtime_ok(runtime_help())
    Some("run") => render_runtime_run(args, launch=false)
    Some("launch") => render_runtime_run(args, launch=true)
    Some("bootstrap") => render_runtime_bootstrap(args)
    Some("asset") => render_runtime_asset(args)
    Some("lifecycle") => render_runtime_lifecycle(args)
    Some("invoke") => render_runtime_invoke(args)
    Some("--manifest") | None => render_runtime_manifest(args)
    Some(command) =>
      runtime_fail("unknown runtime command: \{command}\n\n" + runtime_help())
  }
}

///|
async fn render_runtime_manifest(args : Array[String]) -> RuntimeCliResult {
  match runtime_manifest_arg(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_manifest_text(path, text)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
async fn render_runtime_asset(args : Array[String]) -> RuntimeCliResult {
  let url = args.get(1).unwrap_or("")
  if url == "" || url == "--manifest" {
    return runtime_fail("asset url is required\n")
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime asset\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_asset_text(path, text, url)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_manifest_text(
  path : String,
  text : String,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) => runtime_ok(manifest.summary())
    Err(problem) => runtime_fail("Lepusa runtime\n[fail] \{problem}\n")
  }
}

///|
async fn render_runtime_run(
  args : Array[String],
  launch~ : Bool,
) -> RuntimeCliResult {
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime run\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_run_text(path, text, launch~)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_run_text(
  path : String,
  text : String,
  launch? : Bool = false,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Err(problem) => runtime_fail("Lepusa runtime run\n[fail] \{problem}\n")
    Ok(manifest) => {
      let result = if launch {
        @macos.launch_bundled(manifest)
      } else {
        @macos.run_bundled(manifest)
      }
      match result {
        Err(problems) =>
          runtime_fail(
            render_runtime_run_problems("Lepusa runtime run", problems),
          )
        Ok(result) => runtime_ok(render_runtime_run_result(result, launch~))
      }
    }
  }
}

///|
fn render_runtime_run_result(
  result : @macos.MacOSRunResult,
  launch~ : Bool,
) -> String {
  let plan = result.plan()
  [
    "Lepusa runtime run",
    "mode: \{if launch { "launch" } else { "dry-run" }}",
    "backend: macos",
    "engine: WKWebView",
    "status: \{macos_status_name(result.status())}",
    "webviews: \{plan.webviews()}",
    "title: \{plan.title()}",
    "first-window-url: \{plan.url()}",
    "load-url: \{plan.load_url()}",
    "",
  ].join("\n")
}

///|
fn macos_status_name(status : @macos.MacOSRunStatus) -> String {
  match status {
    MacOSPrepared => "prepared"
    MacOSLaunched => "launched"
    MacOSLaunchFailed(_) => "launch-failed"
  }
}

///|
fn render_runtime_run_problems(
  title : String,
  problems : Array[String],
) -> String {
  let lines : Array[String] = [title]
  for problem in problems {
    lines.push("[fail] \{problem}")
  }
  lines.push("")
  lines.join("\n")
}

///|
fn runtime_manifest_arg(args : Array[String]) -> Result[String, String] {
  match args.get(0) {
    None => Ok("lepusa/runtime.json")
    Some("--manifest") =>
      match args.get(1) {
        Some(path) if path != "" => Ok(path)
        _ => Err("--manifest requires a file path")
      }
    Some(value) => Err("unknown runtime command: \{value}")
  }
}

///|
fn runtime_manifest_path(args : Array[String]) -> Result[String, String] {
  for i in 0..<args.length() {
    if args[i] == "--manifest" {
      match args.get(i + 1) {
        Some(path) if path != "" => return Ok(path)
        _ => return Err("--manifest requires a file path")
      }
    }
  }
  Ok("lepusa/runtime.json")
}

///|
fn runtime_ok(output : String) -> RuntimeCliResult {
  { exit_code: 0, output }
}

///|
fn runtime_fail(output : String) -> RuntimeCliResult {
  { exit_code: 1, output }
}

///|
fn runtime_help() -> String {
  (
    #|lepusa-runtime: bundled Lepusa runtime launcher
    #|
    #|Usage:
    #|  lepusa-runtime --manifest <lepusa/runtime.json>
    #|  lepusa-runtime run --manifest <lepusa/runtime.json>
    #|  lepusa-runtime launch --manifest <lepusa/runtime.json>
    #|  lepusa-runtime bootstrap --manifest <lepusa/runtime.json>
    #|  lepusa-runtime asset <url> --manifest <lepusa/runtime.json>
    #|  lepusa-runtime lifecycle <event> [window] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime invoke <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
    #|
  )
}

///|
async fn render_runtime_invoke(args : Array[String]) -> RuntimeCliResult {
  let values = runtime_positional_args(args)
  let window_label = values.get(1).unwrap_or("")
  let route = values.get(2).unwrap_or("")
  let payload = values.get(3).unwrap_or("")
  if window_label == "" {
    return runtime_fail("invoke window is required\n")
  }
  if route == "" || route == "--manifest" {
    return runtime_fail("invoke route is required\n")
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime invoke\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_invoke_text(path, text, window_label, route, payload)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn runtime_positional_args(args : Array[String]) -> Array[String] {
  let values : Array[String] = []
  let mut skip_next = false
  for arg in args {
    if skip_next {
      skip_next = false
    } else if arg == "--manifest" {
      skip_next = true
    } else {
      values.push(arg)
    }
  }
  values
}

///|
async fn render_runtime_invoke_text(
  path : String,
  text : String,
  window_label : String,
  route : String,
  payload : String,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) =>
      runtime_ok(
        manifest.dispatch_json_async(id="cli", window_label~, route~, payload~) +
        "\n",
      )
    Err(problem) => runtime_fail("Lepusa runtime invoke\n[fail] \{problem}\n")
  }
}
