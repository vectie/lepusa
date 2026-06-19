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
    Some("bootstrap") => render_runtime_bootstrap(args)
    Some("asset") => render_runtime_asset(args)
    Some("lifecycle") => render_runtime_lifecycle(args)
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
    #|  lepusa-runtime bootstrap --manifest <lepusa/runtime.json>
    #|  lepusa-runtime asset <url> --manifest <lepusa/runtime.json>
    #|  lepusa-runtime lifecycle <event> [window] --manifest <lepusa/runtime.json>
    #|
  )
}
