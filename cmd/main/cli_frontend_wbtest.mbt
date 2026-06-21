///|
async test "frontend command renders javascript by default" {
  let result = render_cli_async(["frontend"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("export const commandManifest"))
  assert_true(result.output.contains("export const invokeContractReport"))
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
  assert_true(json.output.contains("\"invokeContractReport\""))
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

///|
async test "frontend command emits only registered project invoke routes" {
  let root = "/tmp/lepusa-frontend-filter-\{@async.now().to_int()}"
  @fs.mkdir(root, recursive=true, permission=0o755)
  @fs.write_file(
    root + "/lepusa.json",
    (
      #|{
      #|  "identifier": "dev.local.frontend-filter",
      #|  "productName": "Frontend Filter",
      #|  "version": "0.1.0",
      #|  "window": {
      #|    "label": "main",
      #|    "source": { "html": "<main>filter</main>" }
      #|  },
      #|  "plugins": [
      #|    { "name": "custom", "commands": [{ "name": "run" }] }
      #|  ],
      #|  "capabilities": [
      #|    { "name": "main", "windows": ["main"], "permissions": ["custom:custom.run"] }
      #|  ]
      #|}
    ),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let js = render_cli_async([
    "frontend",
    "js",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(js.exit_code, 0)
  assert_true(js.output.contains("const routeList = [];"))
  assert_true(js.output.contains("custom.run"))
  let dts = render_cli_async([
    "frontend",
    "dts",
    "--project",
    root + "/lepusa.json",
  ])
  assert_eq(dts.exit_code, 0)
  assert_true(dts.output.contains("Record<string, never>"))
  assert_false(dts.output.contains("\"custom.run\":"))
}
