///|
async fn render_frontend_async(args : Array[String]) -> CliResult {
  match frontend_api_config_from_args(args) {
    Ok(config) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match host.launch_manifest() {
            Ok(manifest) =>
              match
                @frontend.FrontendApiBundle::from_launch_manifest(
                  manifest,
                  config~,
                ) {
                Ok(bundle) => render_frontend_bundle(args, bundle)
                Err(problems) =>
                  fail(render_problems("Lepusa frontend", problems))
              }
            Err(problems) => fail(render_problems("Lepusa frontend", problems))
          }
        Err(problems) => fail(render_problems("Lepusa frontend", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn frontend_api_config_from_args(
  args : Array[String],
) -> Result[@frontend.FrontendApiConfig, String] {
  if option_flag_missing_value(args, "--global") {
    return Err("--global requires a name")
  }
  if option_flag_missing_value(args, "--module") {
    return Err("--module requires a name")
  }
  Ok(
    @frontend.FrontendApiConfig::new(
      global_name=option_arg(args, "--global").unwrap_or("lepusa"),
      module_name=option_arg(args, "--module").unwrap_or("lepusa-api"),
    ),
  )
}

///|
fn render_frontend_bundle(
  args : Array[String],
  bundle : @frontend.FrontendApiBundle,
) -> CliResult {
  let mode = frontend_output_mode(args)
  match mode {
    Ok("js") => ok(bundle.javascript())
    Ok("dts") => ok(bundle.typescript())
    Ok("json") => ok(bundle.to_json() + "\n")
    Ok(value) => fail("unknown frontend output: \{value}\n")
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn frontend_output_mode(args : Array[String]) -> Result[String, String] {
  if has_flag(args, "--json") {
    return Ok("json")
  }
  let values = positional_args(args)
  match values.get(0) {
    None => Ok("js")
    Some("js") => Ok("js")
    Some("dts") => Ok("dts")
    Some("json") => Ok("json")
    Some(value) => Err("unknown frontend output: \{value}")
  }
}
