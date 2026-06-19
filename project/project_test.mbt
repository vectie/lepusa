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
