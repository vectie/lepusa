///|
async fn render_plugin(args : Array[String]) -> CliResult {
  match args.get(1) {
    Some("catalog") => render_plugin_catalog(args)
    Some("contract") => render_plugin_contract(args)
    Some("new") => render_plugin_new(args)
    Some(command) =>
      fail("unknown plugin command: \{command}\n\n" + help_text())
    None => fail("plugin command is required\n\n" + help_text())
  }
}

///|
fn render_plugin_catalog(args : Array[String]) -> CliResult {
  let contracts = @catalog.plugin_contracts()
  if has_flag(args, "--json") {
    ok(@catalog.plugin_contracts_json() + "\n")
  } else {
    let lines : Array[String] = [
      "Lepusa plugin catalog",
      "plugins: \{contracts.length()}",
    ]
    for contract in contracts {
      lines.push(
        "- \{contract.name()} commands=\{contract.command_count()} sync=\{contract.sync_count()} async=\{contract.async_count()} events=\{contract.event_count()} lifecycle=\{contract.lifecycle_count()} ok=\{contract.ok()}",
      )
    }
    ok(lines.join("\n") + "\n")
  }
}

///|
fn render_plugin_contract(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let name = values.get(1).unwrap_or("")
  if name == "" {
    return fail("plugin contract name is required\n")
  }
  match @catalog.plugin_contract(name) {
    Some(contract) =>
      if has_flag(args, "--json") {
        ok(contract.to_json() + "\n")
      } else {
        ok(render_plugin_contract_text(contract))
      }
    None => fail("unknown plugin: \{name}\n")
  }
}

///|
fn render_plugin_contract_text(contract : @lepusa.PluginContract) -> String {
  let lines : Array[String] = [
    "Lepusa plugin contract",
    "plugin: \{contract.name()}",
    "ok: \{contract.ok()}",
    "commands: \{contract.command_count()}",
    "sync: \{contract.sync_count()} async: \{contract.async_count()} stream: \{contract.stream_count()} event: \{contract.event_count()}",
    "lifecycle: \{contract.lifecycle_count()}",
    "permissions: \{contract.permissions().join(", ")}",
    "routes:",
  ]
  for command in contract.commands() {
    lines.push(
      "- \{command.route()} mode=\{command.mode().name()} permission=\{command.permission().name()}",
    )
  }
  let problems = contract.problems()
  if !problems.is_empty() {
    lines.push("problems:")
    for problem in problems {
      lines.push("- \{problem}")
    }
  }
  lines.join("\n") + "\n"
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
