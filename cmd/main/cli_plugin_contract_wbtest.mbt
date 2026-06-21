///|
async test "plugin catalog renders official contract report" {
  let result = render_cli_async(["plugin", "catalog"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa plugin catalog"))
  assert_true(result.output.contains("plugins: 21"))
  assert_true(result.output.contains("- fs commands="))
  let json = render_cli_async(["plugin", "catalog", "--json"])
  assert_eq(json.exit_code, 0)
  assert_true(json.output.contains("\"name\":\"fs\""))
  assert_true(json.output.contains("\"commands\":["))
}

///|
async test "plugin contract renders single official plugin" {
  let result = render_cli_async(["plugin", "contract", "fs"])
  assert_eq(result.exit_code, 0)
  assert_true(result.output.contains("Lepusa plugin contract"))
  assert_true(result.output.contains("plugin: fs"))
  assert_true(result.output.contains("fs.readText"))
  assert_true(result.output.contains("filesystem.read"))
  let json = render_cli_async(["plugin", "contract", "fs", "--json"])
  assert_eq(json.exit_code, 0)
  assert_true(json.output.contains("\"name\":\"fs\""))
  assert_true(json.output.contains("\"route\":\"fs.readText\""))
  let missing_name = render_cli_async(["plugin", "contract"])
  assert_eq(missing_name.exit_code, 1)
  assert_true(missing_name.output.contains("plugin contract name is required"))
  let unknown = render_cli_async(["plugin", "contract", "missing"])
  assert_eq(unknown.exit_code, 1)
  assert_true(unknown.output.contains("unknown plugin: missing"))
}
