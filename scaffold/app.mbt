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
  write_app_with_workspace(out_dir, lepusa_root="")
}

///|
pub async fn write_app_with_workspace(
  out_dir : String,
  lepusa_root~ : String,
) -> Result[AppScaffoldResult, Array[String]] {
  let root = normalize_project_root(out_dir)
  let problems : Array[String] = []
  let files : Array[String] = []
  ensure_directory(root, problems)
  for file in app_skeleton_files(lepusa_root~) {
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
fn app_skeleton_files(lepusa_root? : String = "") -> Array[ScaffoldFile] {
  let files = [
    ScaffoldFile::new(path="moon.mod", content=project_moon_mod()),
    ScaffoldFile::new(path="lepusa.json", content=project_lepusa_json()),
    ScaffoldFile::new(path="src/moon.pkg", content=project_moon_pkg()),
    ScaffoldFile::new(path="src/main.mbt", content=project_main_mbt()),
    ScaffoldFile::new(path="README.mbt.md", content=project_readme()),
  ]
  let root = lepusa_root.trim().to_owned()
  if root != "" {
    files.push(
      ScaffoldFile::new(path="moon.work", content=project_moon_work(root)),
    )
  }
  files
}

///|
fn project_moon_work(lepusa_root : String) -> String {
  (
    #|members = [
    #|  ".",
  ) +
  "  \{moon_work_string(lepusa_root)},\n" +
  (
    #|]
    #|
  )
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
    #|  "vectie/lepusa/desktop",
    #|  "vectie/lepusa/ui"
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
    #|  "rootHtml": "<main><h1>Lepusa App</h1><p>Count: 0</p><button>Increment</button></main>",
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
    #|    Increment => ({ count: model.count + 1 }, @lepusa.none)
    #|    Reset => ({ count: 0 }, @lepusa.none)
    #|  }
    #|}
    #|
    #|///|
    #|fn encode(msg : Msg) -> String {
    #|  match msg {
    #|    Increment => "{\"kind\":\"increment\"}"
    #|    Reset => "{\"kind\":\"reset\"}"
    #|  }
    #|}
    #|
    #|///|
    #|fn decode(payload : String) -> Result[Msg, String] {
    #|  match payload {
    #|    "{\"kind\":\"increment\"}" => Ok(Increment)
    #|    "{\"kind\":\"reset\"}" => Ok(Reset)
    #|    _ => Err("unknown counter message")
    #|  }
    #|}
    #|
    #|///|
    #|fn view(emit : @ui.ViewEmit[Msg], model : Model) -> @lepusa.Html {
    #|  @ui.main_([
    #|    @ui.h1([@ui.text("Lepusa App")]),
    #|    @ui.p([@ui.text("Count: \{model.count}")], attrs=[@ui.class_name("metric")]),
    #|    @ui.p([@ui.text("Starting")], attrs=[@ui.id("status")]),
    #|    @ui.button("Increment", attrs=[emit(Increment)]),
    #|    @ui.button("Reset", attrs=[emit(Reset)]),
    #|    @ui.text_listener("ready", "#status"),
    #|  ])
    #|}
    #|
    #|///|
    #|fn main {
    #|  ignore([Increment, Reset])
    #|  let program = @ui.UiProgram::new(
    #|    model={ count: 0 },
    #|    update=update,
    #|    view=view,
    #|    encode=encode,
    #|    decode=decode,
    #|    route="counter.dispatch",
    #|    render_event="counter.render",
    #|  )
    #|  let project = @desktop.DesktopProject::new(
    #|    @lepusa.AppMetadata::new(
    #|      identifier="dev.local.lepusa-app",
    #|      product_name="Lepusa App",
    #|      version="0.1.0",
    #|    ),
    #|    program.cell(),
    #|  )
    #|    .window(title="Lepusa App", width=1000, height=720)
    #|    .with_plugin(program.plugin())
    #|    .with_capability(program.capability_for_window())
    #|    .with_registry(program.registry())
    #|    .with_sync_plugins()
    #|    .with_startup(
    #|      @lepusa.Cmd::batch([
    #|        @lepusa.Cmd::effect("boot"),
    #|        @lepusa.Cmd::emit(@lepusa.Event::new("ready", payload="{\"message\":\"Ready\"}")),
    #|      ]),
    #|    )
    #|  match project.runtime_host() {
    #|    Ok(_) => {
    #|      match project.runtime_plan() {
    #|        Ok(plan) =>
    #|          println(
    #|            "ready: windows=\{plan.window_count()} routes=\{plan.command_routes().length()} handlers=\{project.kit().registered_routes().length()}",
    #|          )
    #|        Err(problems) => {
    #|          for problem in problems {
    #|            println("[fail] \{problem}")
    #|          }
    #|        }
    #|      }
    #|    }
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
    #|The generated app uses `@lepusa/ui.UiProgram` for model/update/view UI
    #|and `@lepusa/desktop.DesktopProject` to keep custom UI handlers,
    #|official desktop plugins, capabilities, runtime hosts, and bundle plans
    #|aligned. It starts from `with_sync_plugins()` so the default app stays
    #|launchable on native loops before async bridge scheduling is required.
    #|
    #|```bash
    #|moon run src --target native
    #|```
    #|
  )
}
