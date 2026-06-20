///|
struct CliResult {
  exit_code : Int
  output : String
} derive(Debug, Eq)

///|
fn render_cli(args : Array[String]) -> CliResult {
  match args.get(0) {
    None => ok(help_text())
    Some("help") | Some("--help") | Some("-h") => ok(help_text())
    Some(command) => fail("unknown command: \{command}\n\n" + help_text())
  }
}

///|
async fn render_cli_async(args : Array[String]) -> CliResult {
  match args.get(0) {
    Some("doctor") => render_doctor_async(args)
    Some("plan") => render_plan_async(args)
    Some("manifest") => render_manifest_async(args)
    Some("native-plan") => render_native_plan_async(args)
    Some("launch-session") => render_launch_session_async(args)
    Some("run") => render_run_async(args)
    Some("bridge") => render_bridge_async(args)
    Some("dev") => render_dev_async(args)
    Some("bridge-task") => render_bridge_task_async(args)
    Some("bridge-handoff") => render_bridge_handoff_async(args)
    Some("bridge-dispatch") => render_bridge_dispatch_async(args)
    Some("init") => render_init(args)
    Some("plugin") => render_plugin(args)
    Some("invoke") => render_invoke_async(args)
    Some("asset") => render_asset_async(args)
    Some("lifecycle") => render_lifecycle_async(args)
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
    #|  lepusa doctor [macos|windows|linux]
    #|  lepusa plan
    #|  lepusa manifest
    #|  lepusa native-plan [macos|windows|linux]
    #|  lepusa launch-session [macos|windows|linux]
    #|  lepusa run [macos|windows|linux] [--launch]
    #|  lepusa bridge
    #|  lepusa dev
    #|  lepusa bridge-task <window> <plugin.command> [payload]
    #|  lepusa bridge-handoff <window> <plugin.command> [payload]
    #|  lepusa bridge-dispatch <window> <plugin.command> [payload]
    #|  lepusa invoke <window> <plugin.command> [payload]
    #|  lepusa asset <url>
    #|  lepusa lifecycle <event> [window]
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
