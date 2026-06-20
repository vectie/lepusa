///|
pub struct DesktopProject {
  root : @lepusa.Cell
  manifest : @lepusa.ProjectManifest
  kit : DesktopKit
}

///|
pub fn DesktopProject::new(
  metadata : @lepusa.AppMetadata,
  root : @lepusa.Cell,
  runtime? : @lepusa.RuntimeConfig = @lepusa.RuntimeConfig::system_webview(),
) -> DesktopProject {
  {
    root,
    manifest: @lepusa.ProjectManifest::new(metadata, runtime~),
    kit: DesktopKit::new(),
  }
}

///|
pub fn DesktopProject::root(self : DesktopProject) -> @lepusa.Cell {
  self.root
}

///|
pub fn DesktopProject::kit(self : DesktopProject) -> DesktopKit {
  self.kit
}

///|
pub fn DesktopProject::base_manifest(
  self : DesktopProject,
) -> @lepusa.ProjectManifest {
  self.manifest
}

///|
pub fn DesktopProject::manifest(
  self : DesktopProject,
) -> Result[@lepusa.ProjectManifest, Array[String]] {
  let problems = self.kit.validate()
  if !problems.is_empty() {
    return Err(problems)
  }
  Ok(self.effective_manifest())
}

///|
pub fn DesktopProject::with_kit(
  self : DesktopProject,
  kit : DesktopKit,
) -> DesktopProject {
  { ..self, kit, }
}

///|
pub fn DesktopProject::with_window(
  self : DesktopProject,
  window : @lepusa.WindowConfig,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_window(window) }
}

///|
pub fn DesktopProject::window(
  self : DesktopProject,
  label? : String = "main",
  title? : String = "Lepusa",
  width? : Int = 1000,
  height? : Int = 720,
  resizable? : Bool = true,
  title_bar? : @lepusa.TitleBarStyle = Native,
  source? : @lepusa.Source,
) -> DesktopProject {
  self.with_window(
    @lepusa.WindowConfig::new(
      label~,
      title~,
      width~,
      height~,
      resizable~,
      title_bar~,
      source?,
    ),
  )
}

///|
pub fn DesktopProject::with_plugin(
  self : DesktopProject,
  plugin : @lepusa.Plugin,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_plugin(plugin) }
}

///|
pub fn DesktopProject::with_capability(
  self : DesktopProject,
  capability : @lepusa.Capability,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_capability(capability) }
}

///|
pub fn DesktopProject::with_official_plugin(
  self : DesktopProject,
  name : String,
  window_label? : String = "main",
  capability_name? : String = "",
) -> DesktopProject {
  { ..self, kit: self.kit.with_plugin(name, window_label~, capability_name~) }
}

///|
pub fn DesktopProject::with_official_plugins(
  self : DesktopProject,
  names : Array[String],
  window_label? : String = "main",
) -> DesktopProject {
  { ..self, kit: self.kit.with_plugins(names, window_label~) }
}

///|
pub fn DesktopProject::with_sync_plugins(
  self : DesktopProject,
  window_label? : String = "main",
) -> DesktopProject {
  { ..self, kit: self.kit.with_sync_plugins(window_label~) }
}

///|
pub fn DesktopProject::with_filesystem_scope(
  self : DesktopProject,
  scope : @lepusa.FileSystemScope,
) -> DesktopProject {
  {
    ..self,
    manifest: self.manifest.with_file_system_scope(scope),
    kit: self.kit.with_filesystem_scope(scope),
  }
}

///|
pub fn DesktopProject::with_local_service(
  self : DesktopProject,
  service : @lepusa.LocalService,
) -> DesktopProject {
  { ..self, kit: self.kit.with_local_service(service) }
}

///|
pub fn DesktopProject::with_registry(
  self : DesktopProject,
  registry : @lepusa.CommandRegistry,
) -> DesktopProject {
  { ..self, kit: self.kit.with_registry(registry) }
}

///|
pub fn DesktopProject::with_startup(
  self : DesktopProject,
  command : @lepusa.Cmd,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_startup(command) }
}

///|
pub fn DesktopProject::with_lifecycle(
  self : DesktopProject,
  event : @lepusa.LifecycleEvent,
  command : @lepusa.Cmd,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_lifecycle(event, command) }
}

///|
pub fn DesktopProject::on_shutdown(
  self : DesktopProject,
  command : @lepusa.Cmd,
) -> DesktopProject {
  self.with_lifecycle(AppWillExit, command)
}

///|
pub fn DesktopProject::on_window_close_requested(
  self : DesktopProject,
  label : String,
  command : @lepusa.Cmd,
) -> DesktopProject {
  self.with_lifecycle(WindowCloseRequested(label), command)
}

///|
pub fn DesktopProject::with_runtime(
  self : DesktopProject,
  runtime : @lepusa.RuntimeConfig,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_runtime(runtime) }
}

///|
pub fn DesktopProject::with_icon_path(
  self : DesktopProject,
  icon_path : String,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_icon_path(icon_path) }
}

///|
pub fn DesktopProject::with_signing(
  self : DesktopProject,
  signing : @lepusa.SigningConfig,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_signing(signing) }
}

///|
pub fn DesktopProject::with_runtime_dependency_source(
  self : DesktopProject,
  source : @lepusa.BundleRuntimeDependencySource,
) -> DesktopProject {
  { ..self, manifest: self.manifest.with_runtime_dependency_source(source) }
}

///|
pub fn DesktopProject::validate(self : DesktopProject) -> Array[String] {
  let problems = self.kit.validate()
  for problem in self.effective_manifest().validate() {
    problems.push(problem)
  }
  problems
}

///|
pub fn DesktopProject::app(
  self : DesktopProject,
) -> Result[@lepusa.App, Array[String]] {
  match self.manifest() {
    Ok(manifest) => Ok(manifest.app(self.root))
    Err(problems) => Err(problems)
  }
}

///|
pub fn DesktopProject::runtime_plan(
  self : DesktopProject,
) -> Result[@lepusa.RuntimePlan, Array[String]] {
  match self.manifest() {
    Ok(manifest) => manifest.runtime_plan(self.root)
    Err(problems) => Err(problems)
  }
}

///|
pub fn DesktopProject::runtime_host(
  self : DesktopProject,
) -> Result[@runtime.RuntimeHost, Array[String]] {
  match self.runtime_plan() {
    Ok(plan) => self.kit.runtime_host(plan)
    Err(problems) => Err(problems)
  }
}

///|
pub fn DesktopProject::bundle_plan(
  self : DesktopProject,
  target? : @lepusa.BundleTarget = MacOS,
) -> Result[@lepusa.BundlePlan, Array[String]] {
  match self.manifest() {
    Ok(manifest) =>
      match manifest.runtime_plan(self.root) {
        Ok(plan) =>
          match self.kit.registered_routes_for_plan(plan) {
            Ok(registered_routes) =>
              manifest.bundle_plan(self.root, target~, registered_routes~)
            Err(problems) => Err(problems)
          }
        Err(problems) => Err(problems)
      }
    Err(problems) => Err(problems)
  }
}

///|
fn DesktopProject::effective_manifest(
  self : DesktopProject,
) -> @lepusa.ProjectManifest {
  let mut manifest = self.manifest
  for plugin in self.kit.plugins() {
    manifest = manifest.with_plugin(plugin)
  }
  for capability in self.kit.capabilities() {
    manifest = manifest.with_capability(capability)
  }
  manifest
}
