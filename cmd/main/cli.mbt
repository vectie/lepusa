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
    Some("verify") => render_verify_async(args)
    Some("bridge") => render_bridge_async(args)
    Some("frontend") => render_frontend_async(args)
    Some("dev") => render_dev_async(args)
    Some("bridge-task") => render_bridge_task_async(args)
    Some("bridge-handoff") => render_bridge_handoff_async(args)
    Some("bridge-complete") => render_bridge_complete_async(args)
    Some("bridge-dispatch") => render_bridge_dispatch_async(args)
    Some("bridge-loop") => render_bridge_loop_async(args)
    Some("bridge-drain") => render_bridge_drain_async(args)
    Some("init") => render_init(args)
    Some("plugin") => render_plugin(args)
    Some("invoke") => render_invoke_async(args)
    Some("asset") => render_asset_async(args)
    Some("lifecycle") => render_lifecycle_async(args)
    Some("bundle-plan") => render_bundle_plan_async(args)
    Some("bundle-inspect") => render_bundle_inspect_async(args)
    Some("bundle-release-plan") => render_bundle_release_plan_async(args)
    Some("bundle-release-write") => render_bundle_release_write_async(args)
    Some("bundle-package-plan") => render_bundle_package_plan_async(args)
    Some("bundle-package-write") => render_bundle_package_write_async(args)
    Some("bundle-write") => render_bundle_write(args)
    Some("deploy-dry-run") => render_deploy_dry_run_async(args)
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
    #|  lepusa doctor [macos|windows|linux] [--strict] [--json]
    #|  lepusa plan
    #|  lepusa manifest
    #|  lepusa native-plan [macos|windows|linux]
    #|  lepusa launch-session [macos|windows|linux] [--async-bridge]
    #|  lepusa run [macos|windows|linux] [--launch] [--json]
    #|  lepusa verify [macos|windows|linux] [--strict] [--json]
    #|  lepusa bridge
    #|  lepusa frontend [js|dts|json] [--global <name>] [--module <name>]
    #|  lepusa dev [--json]
    #|  lepusa bridge-task <window> <plugin.command> [payload]
    #|  lepusa bridge-handoff <window> <plugin.command> [payload]
    #|  lepusa bridge-complete <window> <plugin.command> [payload]
    #|  lepusa bridge-dispatch <window> <plugin.command> [payload]
    #|  lepusa bridge-loop <window> <plugin.command> [payload]
    #|  lepusa bridge-drain <window> <plugin.command> [payload]
    #|  lepusa invoke <window> <plugin.command> [payload]
    #|  lepusa asset <url>
    #|  lepusa lifecycle <event> [window]
    #|  lepusa init [out-dir] [--workspace <lepusa-root>]
    #|  lepusa plugin catalog [--json]
    #|  lepusa plugin contract <name> [--json]
    #|  lepusa plugin new <name> [out-dir] [--workspace <lepusa-root>]
    #|  lepusa bundle-plan [macos|windows|linux] [--json]
    #|  lepusa bundle-inspect <lepusa/distribution.json> [--json]
    #|  lepusa bundle-release-plan <lepusa/distribution.json> [--json]
    #|  lepusa bundle-release-write <lepusa/distribution.json> [out-dir] [--json]
    #|  lepusa bundle-package-plan <lepusa/distribution.json> [--json]
    #|  lepusa bundle-package-write <lepusa/distribution.json> [out-dir] [--json]
    #|  lepusa bundle-write [macos|windows|linux] [out-dir] [--json]
    #|  lepusa deploy-dry-run <update.json> <macos|windows|linux> <install-root> <staging-root> [current-version] [--allow-restart] [--json]
    #|  lepusa build [macos|windows|linux] [out-dir]
    #|  lepusa bundle [macos|windows|linux] [out-dir]
    #|
    #|Options:
    #|  --project <lepusa.json>
    #|  --workspace <lepusa-root>
    #|
  )
}
