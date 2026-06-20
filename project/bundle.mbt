///|
fn project_runtime_dependency_sources_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> Array[@lepusa.BundleRuntimeDependencySource] {
  let sources : Array[@lepusa.BundleRuntimeDependencySource] = []
  match optional_config_array(object, "runtimeDependencies") {
    Some(items) =>
      for item in items {
        match item {
          Object(dependency) =>
            sources.push(
              runtime_dependency_source_from_object(
                dependency,
                base_dir~,
                problems,
              ),
            )
          _ =>
            problems.push("project runtimeDependencies entries must be objects")
        }
      }
    None => ()
  }
  sources
}

///|
fn runtime_dependency_source_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.BundleRuntimeDependencySource {
  let name = match optional_config_string(object, "name") {
    Some(value) => value
    None => {
      problems.push("project runtime dependency name is required")
      ""
    }
  }
  let source_path = match optional_config_string(object, "source") {
    Some(path) => config_path(base_dir, path)
    None =>
      match optional_config_string(object, "sourcePath") {
        Some(path) => config_path(base_dir, path)
        None => {
          problems.push("project runtime dependency source is required")
          ""
        }
      }
  }
  @lepusa.BundleRuntimeDependencySource::new(name~, source_path~)
}
