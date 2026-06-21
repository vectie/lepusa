///|
async test "frontend command renders javascript by default" {
  let result = render_cli_async(["frontend"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("export const commandManifest"))
  assert_true(result.output.contains("\"route\":\"core.invoke\""))
  assert_true(result.output.contains("export const core = commands[\"core\"];"))
}

///|
async test "frontend command renders declarations and json" {
  let dts = render_cli_async(["frontend", "dts"])
  assert_eq(dts.exit_code, 0)
  assert_true(dts.output.contains("export type LepusaRoute"))
  assert_true(dts.output.contains("export declare function invoke"))
  assert_true(dts.output.contains("export declare const core"))
  let json = render_cli_async([
    "frontend", "json", "--global", "lepusaNative", "--module", "app-api",
  ])
  assert_eq(json.exit_code, 0)
  assert_true(json.output.contains("\"globalName\":\"lepusaNative\""))
  assert_true(json.output.contains("\"moduleName\":\"app-api\""))
  assert_true(json.output.contains("\"javascript\""))
}

///|
async test "frontend command validates mode and named options" {
  let mode = render_cli_async(["frontend", "css"])
  assert_eq(mode.exit_code, 1)
  assert_eq(mode.output, "unknown frontend output: css\n")
  let missing_global = render_cli_async(["frontend", "--global"])
  assert_eq(missing_global.exit_code, 1)
  assert_eq(missing_global.output, "--global requires a name\n")
  let missing_module = render_cli_async(["frontend", "--module"])
  assert_eq(missing_module.exit_code, 1)
  assert_eq(missing_module.output, "--module requires a name\n")
}
