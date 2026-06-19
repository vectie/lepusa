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
fn render_cli(args : Array[String]) -> CliResult {
  match args.get(0) {
    None => ok(help_text())
    Some("help") | Some("--help") | Some("-h") => ok(help_text())
    Some("doctor") => render_doctor()
    Some("plan") => render_plan()
    Some("manifest") => render_manifest()
    Some("bridge") => render_bridge()
    Some("bundle-plan") => render_bundle_plan(args)
    Some("init") => fail("init requires the native async runner\n")
    Some("plugin") => fail("plugin commands require the native async runner\n")
    Some("bundle-write") =>
      fail("bundle-write requires the native async runner\n")
    Some(command) => fail("unknown command: \{command}\n\n" + help_text())
  }
}

///|
async fn render_cli_async(args : Array[String]) -> CliResult {
  match args.get(0) {
    Some("init") => render_init(args)
    Some("plugin") => render_plugin(args)
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
    #|  lepusa init [out-dir]
    #|  lepusa plugin new <name> [out-dir]
    #|  lepusa bundle-plan [macos|windows|linux]
    #|  lepusa bundle-write [macos|windows|linux] [out-dir]
    #|  lepusa build [macos|windows|linux] [out-dir]
    #|  lepusa bundle [macos|windows|linux] [out-dir]
    #|
  )
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
    Ok(plan) => {
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
    Err(problems) => fail(render_problems("Lepusa runtime plan", problems))
  }
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
            Ok(plan) =>
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
                Err(problems) =>
                  fail(render_problems("Lepusa bundle files", problems))
              }
            Err(problems) =>
              fail(render_problems("Lepusa bundle plan", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_bundle_write(args : Array[String]) -> CliResult {
  match parse_bundle_target(args.get(1)) {
    Ok(target) => {
      let out_dir = args.get(2).unwrap_or("_build/lepusa-bundle")
      match sample_runtime_plan() {
        Ok(_) =>
          match sample_manifest().bundle_plan(sample_root(), target~) {
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
            Err(problems) =>
              fail(render_problems("Lepusa bundle write", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bundle write", problems))
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
