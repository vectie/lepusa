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
  let json = @json.parse(text) catch {
    error =>
      return runtime_fail(
        "Lepusa runtime\n[fail] invalid runtime json: \{error}\n",
      )
  }
  match json {
    Object(object) =>
      match optional_object(object, "runtime") {
        Some(runtime) => runtime_ok(runtime_summary(path, object, runtime))
        None =>
          runtime_fail("Lepusa runtime\n[fail] runtime object is required\n")
      }
    _ =>
      runtime_fail(
        "Lepusa runtime\n[fail] runtime manifest must be a json object\n",
      )
  }
}

///|
fn runtime_summary(
  path : String,
  bundle : Map[String, Json],
  runtime : Map[String, Json],
) -> String {
  let webviews = optional_array(runtime, "webviews").unwrap_or([])
  let local_services = optional_array(runtime, "localServices").unwrap_or([])
  let startup_actions = optional_array(runtime, "startupActions").unwrap_or([])
  let lifecycle_hooks = optional_array(runtime, "lifecycleHooks").unwrap_or([])
  let routes = optional_array(runtime, "commandRoutes").unwrap_or([])
  let registered_routes = optional_array(runtime, "registeredRoutes").unwrap_or([],
  )
  "Lepusa runtime\n" +
  "manifest: \{path}\n" +
  "identifier: \{optional_string(bundle, "identifier").unwrap_or("")}\n" +
  "product: \{optional_string(bundle, "productName").unwrap_or("")}\n" +
  "target: \{optional_string(bundle, "target").unwrap_or("")}\n" +
  "backend: \{optional_string(runtime, "backend").unwrap_or("")}\n" +
  "bridge: \{optional_string(runtime, "bridgeUrl").unwrap_or("")}\n" +
  "webviews: \{webviews.length()}\n" +
  "first-window-url: \{first_webview_url(webviews)}\n" +
  "local-services: \{local_services.length()}\n" +
  "startup-actions: \{startup_actions.length()}\n" +
  "lifecycle-hooks: \{lifecycle_hooks.length()}\n" +
  "command-routes: \{routes.length()}\n" +
  "registered-routes: \{registered_routes.length()}\n"
}

///|
fn first_webview_url(webviews : Array[Json]) -> String {
  match webviews.get(0) {
    Some(Object(webview)) => optional_string(webview, "url").unwrap_or("")
    _ => ""
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
fn optional_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_array(object : Map[String, Json], key : String) -> Array[Json]? {
  match object.get(key) {
    Some(Array(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
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
    #|  lepusa-runtime asset <url> --manifest <lepusa/runtime.json>
    #|  lepusa-runtime lifecycle <event> [window] --manifest <lepusa/runtime.json>
    #|
  )
}
