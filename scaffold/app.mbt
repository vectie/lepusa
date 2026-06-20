///|
pub struct AppScaffoldResult {
  root : String
  files : Array[String]
} derive(Debug, Eq)

///|
pub fn AppScaffoldResult::root(self : AppScaffoldResult) -> String {
  self.root
}

///|
pub fn AppScaffoldResult::files(self : AppScaffoldResult) -> Array[String] {
  self.files
}

///|
struct ScaffoldFile {
  path : String
  content : String
} derive(Debug, Eq)

///|
fn ScaffoldFile::new(path~ : String, content~ : String) -> ScaffoldFile {
  { path, content }
}

///|
fn ScaffoldFile::path(self : ScaffoldFile) -> String {
  self.path
}

///|
fn ScaffoldFile::content(self : ScaffoldFile) -> String {
  self.content
}

///|
pub async fn write_app(
  out_dir : String,
) -> Result[AppScaffoldResult, Array[String]] {
  let root = normalize_project_root(out_dir)
  let problems : Array[String] = []
  let files : Array[String] = []
  ensure_directory(root, problems)
  for file in app_skeleton_files() {
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
fn app_skeleton_files() -> Array[ScaffoldFile] {
  [
    ScaffoldFile::new(path="moon.mod", content=project_moon_mod()),
    ScaffoldFile::new(path="moon.pkg", content=project_moon_pkg()),
    ScaffoldFile::new(path="lepusa.json", content=project_lepusa_json()),
    ScaffoldFile::new(path="main.mbt", content=project_main_mbt()),
    ScaffoldFile::new(path="README.mbt.md", content=project_readme()),
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
    #|  "vectie/lepusa@0.1.0"
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
    #|  "vectie/lepusa",
    #|  "vectie/lepusa/plugins/catalog"
    #|}
    #|
    #|options(
    #|  "is-main": true,
    #|)
    #|
  )
}

///|
fn project_lepusa_json() -> String {
  (
    #|{
    #|  "identifier": "dev.local.lepusa-app",
    #|  "productName": "Lepusa App",
    #|  "version": "0.1.0",
    #|  "rootHtml": "<main><h1>Lepusa App</h1><p>Count: 0</p><button data-route=\"core.invoke\">Increment</button></main>",
    #|  "runtime": {
    #|    "backend": "system-webview",
    #|    "assetProtocol": "lepusa",
    #|    "devtools": false
    #|  },
    #|  "window": {
    #|    "label": "main",
    #|    "title": "Lepusa App",
    #|    "width": 1000,
    #|    "height": 720,
    #|    "resizable": true
    #|  },
    #|  "plugins": [
    #|    {
    #|      "name": "core",
    #|      "commands": [
    #|        { "name": "invoke", "mode": "sync" },
    #|        { "name": "events", "mode": "stream" }
    #|      ]
    #|    },
    #|    {
    #|      "name": "log"
    #|    },
    #|    {
    #|      "name": "store"
    #|    }
    #|  ],
    #|  "capabilities": [
    #|    {
    #|      "name": "main",
    #|      "windows": ["main"],
    #|      "commands": [
    #|        "core.invoke",
    #|        "core.events",
    #|        "log.write",
    #|        "store.get",
    #|        "store.set",
    #|        "store.delete",
    #|        "store.clear",
    #|        "store.keys"
    #|      ]
    #|    }
    #|  ],
    #|  "startup": { "effect": "boot" },
    #|  "lifecycle": [
    #|    {
    #|      "event": "app-will-exit",
    #|      "command": { "effect": "shutdown" }
    #|    }
    #|  ]
    #|}
    #|
  )
}

///|
fn project_main_mbt() -> String {
  (
    #|///|
    #|struct Model {
    #|  count : Int
    #|} derive(Debug, Eq)
    #|
    #|///|
    #|enum Msg {
    #|  Increment
    #|  Reset
    #|} derive(Debug, Eq)
    #|
    #|///|
    #|fn update(msg : Msg, model : Model) -> (Model, @lepusa.Cmd) {
    #|  match msg {
    #|    Increment =>
    #|      ({ count: model.count + 1 }, @lepusa.Cmd::effect("counter.increment"))
    #|    Reset => ({ count: 0 }, @lepusa.Cmd::effect("counter.reset"))
    #|  }
    #|}
    #|
    #|///|
    #|fn view(_dispatch : @lepusa.Dispatch[Msg], model : Model) -> @lepusa.Html {
    #|  @lepusa.Html::text(
    #|    "<main><h1>Lepusa App</h1><p>Count: \{model.count}</p><button data-route=\"core.invoke\">Increment</button></main>",
    #|  )
    #|}
    #|
    #|///|
    #|fn main {
    #|  let (_, root) = @lepusa.cell_with_dispatch(
    #|    model={ count: 0 },
    #|    update=update,
    #|    view=view,
    #|  )
    #|  let registry = @catalog.register(
    #|    @catalog.register(@lepusa.CommandRegistry::new(), "log"),
    #|    "store",
    #|  )
    #|  let app = @lepusa.new(root)
    #|    .window(title="Lepusa App", width=1000, height=720)
    #|    .with_plugin(@catalog.plugin("log").unwrap())
    #|    .with_plugin(@catalog.plugin("store").unwrap())
    #|    .with_capability(
    #|      @lepusa.Capability::new("main")
    #|      .window("main")
    #|      .command("log.write")
    #|      .command("store.get")
    #|      .command("store.set")
    #|      .command("store.delete")
    #|      .command("store.clear")
    #|      .command("store.keys"),
    #|    )
    #|    .with_startup(@lepusa.Cmd::effect("boot"))
    #|  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    #|    Ok(plan) =>
    #|      println(
    #|        "ready: windows=\{plan.window_count()} routes=\{plan.command_routes().length()} handlers=\{registry.routes().length()}",
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
    #|The generated app uses `@lepusa/plugins/catalog` to declare official
    #|plugins and register their MoonBit-native handlers.
    #|
    #|```bash
    #|moon run . --target native
    #|```
    #|
  )
}
