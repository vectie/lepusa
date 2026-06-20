///|
pub fn ProjectConfig::load(
  path : String,
) -> Result[ProjectConfig, Array[String]] {
  let text = @xfs.read_file_to_string(path) catch {
    error =>
      return Err([
        "could not read project config \{path}: \{@debug.to_string(error)}",
      ])
  }
  ProjectConfig::parse(text, base_dir=project_config_parent_directory(path))
}

///|
fn project_config_parent_directory(path : String) -> String {
  let normalized = path.trim_end(chars="/\\").to_owned()
  match normalized.rev_find("/") {
    Some(index) => if index == 0 { "/" } else { normalized[:index].to_owned() }
    None => "."
  }
}
