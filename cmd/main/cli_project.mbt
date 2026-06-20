///|
async fn project_runtime_plan(
  args : Array[String],
) -> Result[@lepusa.RuntimePlan, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match @project.ProjectConfig::load(path) {
        Ok(project) => project.manifest().runtime_plan(project.root())
        Err(problems) => Err(problems)
      }
    None => sample_runtime_plan()
  }
}

///|
async fn project_runtime_host(
  args : Array[String],
) -> Result[@runtime.RuntimeHost, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match @project.ProjectConfig::load(path) {
        Ok(project) =>
          match project.manifest().runtime_plan(project.root()) {
            Ok(plan) =>
              Ok(@runtime.RuntimeHost::new(plan, registry=project.registry()))
            Err(problems) => Err(problems)
          }
        Err(problems) => Err(problems)
      }
    None =>
      match sample_runtime_plan() {
        Ok(plan) =>
          Ok(@runtime.RuntimeHost::new(plan, registry=sample_registry()))
        Err(problems) => Err(problems)
      }
  }
}

///|
async fn project_bundle_plan(
  args : Array[String],
  target : @lepusa.BundleTarget,
) -> Result[@lepusa.BundlePlan, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match @project.ProjectConfig::load(path) {
        Ok(project) =>
          project
          .manifest()
          .bundle_plan(
            project.root(),
            target~,
            registered_routes=project.registry().routes(),
          )
        Err(problems) => Err(problems)
      }
    None =>
      sample_manifest().bundle_plan(
        sample_root(),
        target~,
        registered_routes=sample_registry().routes(),
      )
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
  .with_window(@lepusa.WindowConfig::new())
  .with_plugin(
    @lepusa.Plugin::new("core").command_sync("invoke").command_stream("events"),
  )
  .with_capability(
    @lepusa.Capability::new("core")
    .command("core.invoke")
    .command("core.events"),
  )
}

///|
fn sample_registry() -> @lepusa.CommandRegistry {
  @lepusa.CommandRegistry::new()
  .register_fn("core.invoke", handler=fn(payload) { Ok(payload) })
  .register_fn("core.events", handler=fn(_) { Ok("") })
}

///|
fn sample_metadata() -> @lepusa.AppMetadata {
  @lepusa.AppMetadata::new(
    identifier="dev.vectie.lepusa.example",
    product_name="Lepusa Example",
    version="0.1.0",
  )
}
