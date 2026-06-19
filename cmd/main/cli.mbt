///|
struct CliResult {
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
fn Array::with_first(self : Array[String], value : String) -> Array[String] {
  let args : Array[String] = [value]
  for i in 1..<self.length() {
    args.push(self[i])
  }
  args
}

///|
fn project_path_arg(args : Array[String]) -> String? {
  for i in 0..<args.length() {
    if args[i] == "--project" {
      return args.get(i + 1)
    }
  }
  None
}

///|
fn project_flag_missing_value(args : Array[String]) -> Bool {
  for i in 0..<args.length() {
    if args[i] == "--project" && args.get(i + 1) is None {
      return true
    }
  }
  false
}

///|
async fn project_config_path(args : Array[String]) -> String? {
  match project_path_arg(args) {
    Some(path) => Some(path)
    None => {
      let found = @fs.exists("lepusa.json") catch { _ => false }
      if found {
        Some("lepusa.json")
      } else {
        None
      }
    }
  }
}

///|
fn positional_args(args : Array[String]) -> Array[String] {
  let values : Array[String] = []
  let mut skip_next = false
  for i in 1..<args.length() {
    if skip_next {
      skip_next = false
    } else if args[i] == "--project" {
      skip_next = true
    } else {
      values.push(args[i])
    }
  }
  values
}

///|
fn render_cli(args : Array[String]) -> CliResult {
  match args.get(0) {
    None => ok(help_text())
    Some("help") | Some("--help") | Some("-h") => ok(help_text())
    Some("doctor") => render_doctor()
    Some("plan") => render_plan()
    Some("manifest") => render_manifest()
    Some("bridge") => render_bridge()
    Some("bundle-plan") => render_bundle_plan(args)
    Some("dev") => fail("dev requires the native async runner\n")
    Some("init") => fail("init requires the native async runner\n")
    Some("plugin") => fail("plugin commands require the native async runner\n")
    Some("invoke") => fail("invoke requires the native async runner\n")
    Some("bundle-write") =>
      fail("bundle-write requires the native async runner\n")
    Some(command) => fail("unknown command: \{command}\n\n" + help_text())
  }
}

///|
async fn render_cli_async(args : Array[String]) -> CliResult {
  match args.get(0) {
    Some("doctor") => render_doctor_async(args)
    Some("plan") => render_plan_async(args)
    Some("manifest") => render_manifest_async(args)
    Some("bridge") => render_bridge_async(args)
    Some("dev") => render_dev_async(args)
    Some("init") => render_init(args)
    Some("plugin") => render_plugin(args)
    Some("invoke") => render_invoke_async(args)
    Some("bundle-plan") => render_bundle_plan_async(args)
    Some("bundle-write") => render_bundle_write(args)
    Some("bundle") => render_bundle_write(args.with_first("bundle-write"))
    Some("build") => render_bundle_write(args.with_first("bundle-write"))
    _ => render_cli(args)
  }
}

///|
fn ok(output : String) -> CliResult {
  { exit_code: 0, output }
}

///|
fn fail(output : String) -> CliResult {
  { exit_code: 1, output }
}

///|
fn help_text() -> String {
  (
    #|lepusa: MoonBit-native desktop framework
    #|
    #|Usage:
    #|  lepusa doctor
    #|  lepusa plan
    #|  lepusa manifest
    #|  lepusa bridge
    #|  lepusa dev
    #|  lepusa invoke <window> <plugin.command> [payload]
    #|  lepusa init [out-dir]
    #|  lepusa plugin new <name> [out-dir]
    #|  lepusa bundle-plan [macos|windows|linux]
    #|  lepusa bundle-write [macos|windows|linux] [out-dir]
    #|  lepusa build [macos|windows|linux] [out-dir]
    #|  lepusa bundle [macos|windows|linux] [out-dir]
    #|
    #|Options:
    #|  --project <lepusa.json>
    #|
  )
}

///|
async fn project_runtime_plan(
  args : Array[String],
) -> Result[@lepusa.RuntimePlan, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match load_project_config(path) {
        Ok(project) => project.manifest.runtime_plan(project.root)
        Err(problems) => Err(problems)
      }
    None => sample_runtime_plan()
  }
}

///|
async fn project_runtime_host(
  args : Array[String],
) -> Result[@runtime.RuntimeHost, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match load_project_config(path) {
        Ok(project) =>
          match project.manifest.runtime_plan(project.root) {
            Ok(plan) =>
              Ok(@runtime.RuntimeHost::new(plan, registry=project.registry))
            Err(problems) => Err(problems)
          }
        Err(problems) => Err(problems)
      }
    None =>
      match sample_runtime_plan() {
        Ok(plan) => Ok(@runtime.RuntimeHost::new(plan))
        Err(problems) => Err(problems)
      }
  }
}

///|
async fn project_bundle_plan(
  args : Array[String],
  target : @lepusa.BundleTarget,
) -> Result[@lepusa.BundlePlan, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match load_project_config(path) {
        Ok(project) => project.manifest.bundle_plan(project.root, target~)
        Err(problems) => Err(problems)
      }
    None => sample_manifest().bundle_plan(sample_root(), target~)
  }
}

///|
async fn render_plugin(args : Array[String]) -> CliResult {
  match args.get(1) {
    Some("new") => render_plugin_new(args)
    Some(command) =>
      fail("unknown plugin command: \{command}\n\n" + help_text())
    None => fail("plugin command is required\n\n" + help_text())
  }
}

///|
async fn render_plugin_new(args : Array[String]) -> CliResult {
  let name = args.get(2).unwrap_or("")
  let out_dir = args.get(3).unwrap_or("")
  match write_plugin_skeleton(name, out_dir) {
    Ok(result) =>
      ok(
        "Lepusa plugin new\n" +
        "plugin: \{result.plugin_name}\n" +
        "root: \{result.root}\n" +
        "files: \{result.files.length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa plugin new", problems))
  }
}

///|
async fn render_doctor_async(args : Array[String]) -> CliResult {
  match project_runtime_host(args) {
    Ok(host) => {
      let plan = host.plan()
      match host.launch_manifest() {
        Ok(manifest) =>
          ok(
            "Lepusa doctor\n" +
            "[ok] public-api: root package can build launch/runtime plans\n" +
            "[ok] runtime: backend=\{plan.backend().name()} protocol=\{plan.asset_protocol()}\n" +
            "[ok] manifest: webviews=\{manifest.webviews().length()} routes=\{manifest.command_routes().length()}\n" +
            "[ok] ipc: routes=\{plan.command_routes().length()}\n",
          )
        Err(problems) => fail(render_problems("Lepusa doctor", problems))
      }
    }
    Err(problems) => fail(render_problems("Lepusa doctor", problems))
  }
}

///|
async fn render_init(args : Array[String]) -> CliResult {
  let out_dir = args.get(1).unwrap_or("lepusa-app")
  match write_project_skeleton(out_dir) {
    Ok(result) =>
      ok(
        "Lepusa init\n" +
        "root: \{result.root}\n" +
        "files: \{result.files.length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa init", problems))
  }
}

///|
async fn render_manifest_async(args : Array[String]) -> CliResult {
  match project_runtime_host(args) {
    Ok(host) =>
      match host.launch_manifest() {
        Ok(manifest) => ok(manifest.to_json() + "\n")
        Err(problems) => fail(render_problems("Lepusa manifest", problems))
      }
    Err(problems) => fail(render_problems("Lepusa manifest", problems))
  }
}

///|
async fn render_plan_async(args : Array[String]) -> CliResult {
  match project_runtime_plan(args) {
    Ok(plan) => render_runtime_plan(plan)
    Err(problems) => fail(render_problems("Lepusa runtime plan", problems))
  }
}

///|
async fn render_bridge_async(args : Array[String]) -> CliResult {
  match project_runtime_plan(args) {
    Ok(plan) =>
      match plan.bridge_script() {
        Ok(script) => ok(script.source())
        Err(problems) => fail(render_problems("Lepusa bridge", problems))
      }
    Err(problems) => fail(render_problems("Lepusa bridge", problems))
  }
}

///|
async fn render_dev_async(args : Array[String]) -> CliResult {
  match project_runtime_host(args) {
    Ok(host) =>
      match host.dev_plan() {
        Ok(dev) => render_dev_plan(dev)
        Err(problems) => fail(render_problems("Lepusa dev", problems))
      }
    Err(problems) => fail(render_problems("Lepusa dev", problems))
  }
}

///|
async fn render_invoke_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("invoke window is required\n")
  }
  match parse_invoke_route(route) {
    Ok((plugin, command)) =>
      match project_runtime_host(args) {
        Ok(host) => {
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          ok(
            @runtime.encode_invoke_response_json(host.dispatch(request)) + "\n",
          )
        }
        Err(problems) => fail(render_problems("Lepusa invoke", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn parse_invoke_route(route : String) -> Result[(String, String), String] {
  let mut plugin = ""
  let mut command = ""
  let mut found_separator = false
  for char in route {
    if !found_separator && char == '.' {
      found_separator = true
    } else if found_separator {
      command = command + char.to_string()
    } else {
      plugin = plugin + char.to_string()
    }
  }
  if plugin == "" || command == "" {
    return Err("invoke route must be <plugin.command>")
  }
  Ok((plugin, command))
}

///|
fn render_doctor() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) =>
      match plan.launch_manifest() {
        Ok(manifest) =>
          ok(
            "Lepusa doctor\n" +
            "[ok] public-api: root package can build launch/runtime plans\n" +
            "[ok] runtime: backend=\{plan.backend().name()} protocol=\{plan.asset_protocol()}\n" +
            "[ok] manifest: webviews=\{manifest.webviews().length()} routes=\{manifest.command_routes().length()}\n" +
            "[ok] ipc: routes=\{plan.command_routes().length()}\n",
          )
        Err(problems) => fail(render_problems("Lepusa doctor", problems))
      }
    Err(problems) => fail(render_problems("Lepusa doctor", problems))
  }
}

///|
fn render_manifest() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) =>
      match plan.launch_manifest() {
        Ok(manifest) => ok(manifest.to_json() + "\n")
        Err(problems) => fail(render_problems("Lepusa manifest", problems))
      }
    Err(problems) => fail(render_problems("Lepusa manifest", problems))
  }
}

///|
fn render_plan() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) => render_runtime_plan(plan)
    Err(problems) => fail(render_problems("Lepusa runtime plan", problems))
  }
}

///|
fn render_runtime_plan(plan : @lepusa.RuntimePlan) -> CliResult {
  let routes = plan.command_routes().join(",")
  let first_window = match plan.windows().get(0) {
    Some(window) => window.url()
    None => ""
  }
  ok(
    "Lepusa runtime plan\n" +
    "backend: \{plan.backend().name()}\n" +
    "windows: \{plan.window_count()}\n" +
    "first-window-url: \{first_window}\n" +
    "plugins: \{plan.plugin_count()}\n" +
    "capabilities: \{plan.capability_count()}\n" +
    "routes: \{routes}\n",
  )
}

///|
fn render_dev_plan(dev : @runtime.RuntimeDevPlan) -> CliResult {
  let session = dev.session()
  let routes = session.command_routes().join(",")
  let registered_routes = session.registered_routes().join(",")
  let first_window = match dev.webviews().get(0) {
    Some(window) => window.url()
    None => ""
  }
  ok(
    "Lepusa dev plan\n" +
    "backend: \{session.backend().name()}\n" +
    "webviews: \{dev.webviews().length()}\n" +
    "first-window-url: \{first_window}\n" +
    "asset-protocol: \{session.asset_protocol()}\n" +
    "routes: \{routes}\n" +
    "registered-routes: \{registered_routes}\n" +
    "startup-operations: \{dev.startup_operations().length()}\n",
  )
}

///|
fn render_bridge() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) =>
      match plan.bridge_script() {
        Ok(script) => ok(script.source())
        Err(problems) => fail(render_problems("Lepusa bridge", problems))
      }
    Err(problems) => fail(render_problems("Lepusa bridge", problems))
  }
}

///|
fn render_bundle_plan(args : Array[String]) -> CliResult {
  match parse_bundle_target(args.get(1)) {
    Ok(target) =>
      match sample_runtime_plan() {
        Ok(_) =>
          match sample_manifest().bundle_plan(sample_root(), target~) {
            Ok(plan) => render_bundle_plan_summary(plan)
            Err(problems) =>
              fail(render_problems("Lepusa bundle plan", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_bundle_plan_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_bundle_plan(args, target) {
        Ok(plan) => render_bundle_plan_summary(plan)
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_bundle_plan_summary(plan : @lepusa.BundlePlan) -> CliResult {
  match plan.files() {
    Ok(files) =>
      ok(
        "Lepusa bundle plan\n" +
        "target: \{plan.target().name()}\n" +
        "identifier: \{plan.identifier()}\n" +
        "executable: \{plan.executable_name()}\n" +
        "bundle: \{plan.bundle_name()}\n" +
        "files: \{files.length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa bundle files", problems))
  }
}

///|
async fn render_bundle_write(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) => {
      let out_dir = values.get(1).unwrap_or("_build/lepusa-bundle")
      match project_bundle_plan(args, target) {
        Ok(plan) =>
          match write_bundle_plan(plan, out_dir) {
            Ok(result) =>
              ok(
                "Lepusa bundle write\n" +
                "target: \{plan.target().name()}\n" +
                "root: \{result.root}\n" +
                "files: \{result.files.length()}\n",
              )
            Err(problems) =>
              fail(render_problems("Lepusa bundle write", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn parse_bundle_target(
  target : String?,
) -> Result[@lepusa.BundleTarget, String] {
  let target = match target {
    None => @lepusa.MacOS
    Some("macos") => MacOS
    Some("windows") => Windows
    Some("linux") => Linux
    Some(value) => return Err("unknown bundle target: \{value}")
  }
  Ok(target)
}

///|
fn sample_runtime_plan() -> Result[@lepusa.RuntimePlan, Array[String]] {
  sample_manifest().runtime_plan(sample_root())
}

///|
fn sample_root() -> @lepusa.Cell {
  @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
}

///|
fn sample_manifest() -> @lepusa.ProjectManifest {
  @lepusa.ProjectManifest::new(
    sample_metadata(),
    runtime=@lepusa.RuntimeConfig::headless(),
  )
  .with_window(@lepusa.WindowConfig::new())
  .with_plugin(
    @lepusa.Plugin::new("core").command_sync("invoke").command_stream("events"),
  )
  .with_capability(
    @lepusa.Capability::new("core")
    .command("core.invoke")
    .command("core.events"),
  )
}

///|
fn sample_metadata() -> @lepusa.AppMetadata {
  @lepusa.AppMetadata::new(
    identifier="dev.vectie.lepusa.example",
    product_name="Lepusa Example",
    version="0.1.0",
  )
}

///|
fn render_problems(title : String, problems : Array[String]) -> String {
  let lines : Array[String] = [title]
  for problem in problems {
    lines.push("[fail] \{problem}")
  }
  lines.join("\n") + "\n"
}
