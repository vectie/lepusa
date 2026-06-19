///|
async fn load_project_config(
  path : String,
) -> Result[@project.ProjectConfig, Array[String]] {
  let text = @fs.read_file(path).text() catch {
    error => return Err(["could not read project config \{path}: \{error}"])
  }
  @project.ProjectConfig::parse(text, base_dir=parent_directory(path))
}
