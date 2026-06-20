///|
test "project config parses app manifest boundary" {
  let config =
    #|{
    #|  "identifier": "dev.vectie.project",
    #|  "productName": "Project",
    #|  "version": "0.1.0",
    #|  "window": { "label": "main", "title": "Project" },
    #|  "plugins": [{ "name": "log" }],
    #|  "capabilities": [{
    #|    "name": "main",
    #|    "windows": ["main"],
    #|    "commands": ["log.write"]
    #|  }]
    #|}
    #|
  match ProjectConfig::parse(config) {
    Ok(project) =>
      match project.manifest().runtime_plan(project.root()) {
        Ok(plan) => {
          assert_eq(plan.windows().length(), 1)
          assert_true(project.registry().routes().contains("log.write"))
          assert_true(plan.window_command_routes("main").contains("log.write"))
        }
        Err(problems) => abort(problems.join(", "))
      }
    Err(problems) => abort(problems.join(", "))
  }
}

///|
async test "project config loads file relative resources" {
  let root = "/tmp/lepusa-project-load-\{@async.now().to_int()}"
  @fs.mkdir(root + "/dist", recursive=true, permission=0o755)
  @fs.write_file(
    root + "/dist/index.html",
    b"<main>loaded</main>",
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let config =
    #|{
    #|  "identifier": "dev.vectie.loaded",
    #|  "productName": "Loaded",
    #|  "version": "0.1.0",
    #|  "window": {
    #|    "label": "main",
    #|    "title": "Loaded",
    #|    "source": { "packaged": "dist" }
    #|  }
    #|}
    #|
  @fs.write_file(
    root + "/lepusa.json",
    @utf8.encode(config),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  match ProjectConfig::load(root + "/lepusa.json") {
    Ok(project) =>
      match project.manifest().bundle_plan(project.root(), target=Linux) {
        Ok(plan) => {
          assert_eq(plan.resources().length(), 1)
          assert_eq(plan.resources()[0].source_path(), root + "/dist")
          assert_eq(plan.resources()[0].path(), "loaded/lepusa/assets/main")
        }
        Err(problems) => abort(problems.join(", "))
      }
    Err(problems) => abort(problems.join(", "))
  }
}
