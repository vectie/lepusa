///|
struct ProjectInitResult {
  root : String
  files : Array[String]
} derive(Debug, Eq)

///|
struct ProjectFile {
  path : String
  content : String
} derive(Debug, Eq)

///|
fn ProjectFile::new(path~ : String, content~ : String) -> ProjectFile {
  { path, content }
}

///|
fn ProjectFile::path(self : ProjectFile) -> String {
  self.path
}

///|
fn ProjectFile::content(self : ProjectFile) -> String {
  self.content
}

///|
async fn write_project_skeleton(
  out_dir : String,
) -> Result[ProjectInitResult, Array[String]] {
  let root = normalize_project_root(out_dir)
  let problems : Array[String] = []
  let files : Array[String] = []
  ensure_directory(root, problems)
  for file in project_skeleton_files() {
    let path = join_path(root, file.path())
    ensure_directory(parent_directory(path), problems)
    if problems.is_empty() {
      let problem_count = problems.length()
      @fs.write_file(
        path,
        file.content(),
        create_mode=CreateOrTruncate,
        permission=0o644,
      ) catch {
        error => problems.push("could not write \{path}: \{error}")
      }
      if problems.length() == problem_count {
        files.push(path)
      }
    }
  }
  if problems.is_empty() {
    Ok({ root, files })
  } else {
    Err(problems)
  }
}

///|
fn normalize_project_root(path : String) -> String {
  let trimmed = path.trim_end(chars="/\\").to_owned()
  if trimmed.is_empty() {
    "lepusa-app"
  } else {
    trimmed
  }
}

///|
fn project_skeleton_files() -> Array[ProjectFile] {
  [
    ProjectFile::new(path="moon.mod", content=project_moon_mod()),
    ProjectFile::new(path="moon.pkg", content=project_moon_pkg()),
    ProjectFile::new(path="main.mbt", content=project_main_mbt()),
    ProjectFile::new(path="README.mbt.md", content=project_readme()),
  ]
}

///|
fn project_moon_mod() -> String {
  (
    #|name = "local/lepusa_app"
    #|version = "0.1.0"
    #|readme = "README.mbt.md"
    #|repository = ""
    #|license = "Apache-2.0"
    #|keywords = [ "desktop", "lepusa" ]
    #|description = "A standalone Lepusa desktop app."
    #|
    #|import {
    #|  "vectie/lepusa"
    #|}
    #|
    #|options(
    #|  "preferred-target": "native",
    #|)
    #|
  )
}

///|
fn project_moon_pkg() -> String {
  (
    #|import {
    #|  "vectie/lepusa"
    #|}
    #|
    #|options(
    #|  "is-main": true,
    #|)
    #|
  )
}

///|
fn project_main_mbt() -> String {
  (
    #|///|
    #|fn main {
    #|  let root = @lepusa.simple_cell(@lepusa.Html::text("<main>Hello Lepusa</main>"))
    #|  let app = @lepusa.new(root)
    #|    .window(title="Lepusa App", width=1000, height=720)
    #|    .with_startup(@lepusa.Cmd::effect("boot"))
    #|  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    #|    Ok(plan) =>
    #|      println(
    #|        "ready: windows=\{plan.window_count()} routes=\{plan.command_routes().length()}",
    #|      )
    #|    Err(problems) => {
    #|      for problem in problems {
    #|        println("[fail] \{problem}")
    #|      }
    #|    }
    #|  }
    #|}
    #|
  )
}

///|
fn project_readme() -> String {
  (
    #|# Lepusa App
    #|
    #|A standalone MoonBit desktop app scaffolded by `lepusa init`.
    #|
    #|```bash
    #|moon run . --target native
    #|```
    #|
  )
}
