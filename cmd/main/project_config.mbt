///|
async fn load_project_config(
  path : String,
) -> Result[@project.ProjectConfig, Array[String]] {
  let text = @fs.read_file(path).text() catch {
    error => return Err(["could not read project config \{path}: \{error}"])
  }
  @project.ProjectConfig::parse(text, base_dir=parent_directory(path))
}

///|
fn parent_directory(path : String) -> String {
  let normalized = path.trim_end(chars="/\\").to_owned()
  match normalized.rev_find("/") {
    Some(index) => if index == 0 { "/" } else { normalized[:index].to_owned() }
    None => "."
  }
}
