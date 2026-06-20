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
  if workspace_flag_missing_value(args) {
    return fail("--workspace requires a Lepusa checkout path\n")
  }
  let values = positional_args(args)
  let name = values.get(1).unwrap_or("")
  let out_dir = values.get(2).unwrap_or("")
  let workspace = workspace_path_arg(args).unwrap_or("")
  match
    @scaffold.write_plugin_with_workspace(name, out_dir, lepusa_root=workspace) {
    Ok(result) =>
      ok(
        "Lepusa plugin new\n" +
        "plugin: \{result.plugin_name()}\n" +
        "root: \{result.root()}\n" +
        render_workspace_line(workspace) +
        "files: \{result.files().length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa plugin new", problems))
  }
}

///|
async fn render_init(args : Array[String]) -> CliResult {
  if workspace_flag_missing_value(args) {
    return fail("--workspace requires a Lepusa checkout path\n")
  }
  let values = positional_args(args)
  let out_dir = values.get(0).unwrap_or("lepusa-app")
  let workspace = workspace_path_arg(args).unwrap_or("")
  match @scaffold.write_app_with_workspace(out_dir, lepusa_root=workspace) {
    Ok(result) =>
      ok(
        "Lepusa init\n" +
        "root: \{result.root()}\n" +
        render_workspace_line(workspace) +
        "files: \{result.files().length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa init", problems))
  }
}

///|
fn render_workspace_line(workspace : String) -> String {
  if workspace == "" {
    ""
  } else {
    "workspace: \{workspace}\n"
  }
}
