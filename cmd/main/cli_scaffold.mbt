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
  match @scaffold.write_plugin(name, out_dir) {
    Ok(result) =>
      ok(
        "Lepusa plugin new\n" +
        "plugin: \{result.plugin_name()}\n" +
        "root: \{result.root()}\n" +
        "files: \{result.files().length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa plugin new", problems))
  }
}

///|
async fn render_init(args : Array[String]) -> CliResult {
  let out_dir = args.get(1).unwrap_or("lepusa-app")
  match @scaffold.write_app(out_dir) {
    Ok(result) =>
      ok(
        "Lepusa init\n" +
        "root: \{result.root()}\n" +
        "files: \{result.files().length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa init", problems))
  }
}
