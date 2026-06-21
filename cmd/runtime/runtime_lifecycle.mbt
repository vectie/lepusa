///|
async fn render_runtime_lifecycle(args : Array[String]) -> RuntimeCliResult {
  match runtime_lifecycle_event_arg(args) {
    Ok(event) =>
      match runtime_manifest_path(args) {
        Ok(path) => {
          let text = @fs.read_file(path).text() catch {
            error =>
              return runtime_fail(
                "Lepusa runtime lifecycle\n[fail] could not read manifest \{path}: \{error}\n",
              )
          }
          render_runtime_lifecycle_text(text, event)
        }
        Err(problem) => runtime_fail(problem + "\n")
      }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_lifecycle_text(
  text : String,
  event : @bundled.BundledLifecycleEvent,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse("lepusa/runtime.json", text) {
    Ok(manifest) => runtime_ok(manifest.lifecycle_json(event) + "\n")
    Err(problem) =>
      runtime_fail("Lepusa runtime lifecycle\n[fail] \{problem}\n")
  }
}

///|
fn runtime_lifecycle_event_arg(
  args : Array[String],
) -> Result[@bundled.BundledLifecycleEvent, String] {
  match args.get(1) {
    None => Err("lifecycle event is required")
    Some("app-started") => Ok(@bundled.BundledLifecycleEvent::app_started())
    Some("app-will-exit") => Ok(@bundled.BundledLifecycleEvent::app_will_exit())
    Some("plugin-setup") =>
      match args.get(2) {
        Some(plugin) if plugin != "" && plugin != "--manifest" =>
          @bundled.BundledLifecycleEvent::plugin_setup(plugin)
        _ => Err("lifecycle plugin is required")
      }
    Some("plugin-ready") =>
      match args.get(2) {
        Some(plugin) if plugin != "" && plugin != "--manifest" =>
          @bundled.BundledLifecycleEvent::plugin_ready(plugin)
        _ => Err("lifecycle plugin is required")
      }
    Some("plugin-will-exit") =>
      match args.get(2) {
        Some(plugin) if plugin != "" && plugin != "--manifest" =>
          @bundled.BundledLifecycleEvent::plugin_will_exit(plugin)
        _ => Err("lifecycle plugin is required")
      }
    Some("window-close-requested") =>
      match args.get(2) {
        Some(label) if label != "" && label != "--manifest" =>
          @bundled.BundledLifecycleEvent::window_close_requested(label)
        _ => Err("lifecycle window is required")
      }
    Some("window-closed") =>
      match args.get(2) {
        Some(label) if label != "" && label != "--manifest" =>
          @bundled.BundledLifecycleEvent::window_closed(label)
        _ => Err("lifecycle window is required")
      }
    Some(value) => Err("unknown lifecycle event: \{value}")
  }
}
