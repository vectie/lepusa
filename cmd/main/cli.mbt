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
fn render_cli(args : Array[String]) -> CliResult {
  match args.get(0) {
    None => ok(help_text())
    Some("help") | Some("--help") | Some("-h") => ok(help_text())
    Some("doctor") => render_doctor()
    Some("plan") => render_plan()
    Some("bridge") => render_bridge()
    Some("bundle-plan") => render_bundle_plan(args)
    Some(command) => fail("unknown command: \{command}\n\n" + help_text())
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
    #|  lepusa bridge
    #|  lepusa bundle-plan [macos|windows|linux]
    #|
  )
}

///|
fn render_doctor() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) =>
      ok(
        "Lepusa doctor\n" +
        "[ok] public-api: root package can build launch/runtime plans\n" +
        "[ok] runtime: backend=\{plan.backend().name()} protocol=\{plan.asset_protocol()}\n" +
        "[ok] ipc: routes=\{plan.command_routes().length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa doctor", problems))
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
  let target = match args.get(1) {
    None => @lepusa.MacOS
    Some("macos") => MacOS
    Some("windows") => Windows
    Some("linux") => Linux
    Some(value) => return fail("unknown bundle target: \{value}\n")
  }
  match sample_runtime_plan() {
    Ok(_) =>
      match sample_manifest().bundle_plan(sample_root(), target~) {
        Ok(plan) =>
          ok(
            "Lepusa bundle plan\n" +
            "target: \{plan.target().name()}\n" +
            "identifier: \{plan.identifier()}\n" +
            "executable: \{plan.executable_name()}\n" +
            "bundle: \{plan.bundle_name()}\n",
          )
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
  }
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
  .with_window(
    @lepusa.WindowConfig::new(source=@lepusa.Source::html("<main></main>")),
  )
  .with_plugin(
    @lepusa.Plugin::new("core").command_sync("invoke").command_stream("events"),
  )
  .with_capability(@lepusa.Capability::new("core").permission(Notification))
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
