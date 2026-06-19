///|
struct PluginInitResult {
  root : String
  plugin_name : String
  files : Array[String]
} derive(Debug, Eq)

///|
async fn write_plugin_skeleton(
  plugin_name : String,
  out_dir : String,
) -> Result[PluginInitResult, Array[String]] {
  let normalized_name = normalize_plugin_name(plugin_name)
  if normalized_name == "" {
    return Err(["plugin name is required"])
  }
  let root = normalize_plugin_root(out_dir, normalized_name)
  let problems : Array[String] = []
  let files : Array[String] = []
  ensure_directory(root, problems)
  for file in plugin_skeleton_files(normalized_name) {
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
    Ok({ root, plugin_name: normalized_name, files })
  } else {
    Err(problems)
  }
}

///|
fn normalize_plugin_root(path : String, plugin_name : String) -> String {
  let trimmed = path.trim_end(chars="/\\").to_owned()
  if trimmed.is_empty() {
    "lepusa-plugin-\{plugin_name}"
  } else {
    trimmed
  }
}

///|
fn normalize_plugin_name(name : String) -> String {
  let mut normalized = ""
  let mut last_dash = false
  for char in name.to_lower() {
    if (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') {
      normalized = normalized + char.to_string()
      last_dash = false
    } else if char == '-' || char == '_' || char == ' ' {
      if normalized != "" && !last_dash {
        normalized = normalized + "-"
        last_dash = true
      }
    }
  }
  normalized.trim_end(chars="-").to_owned()
}

///|
fn plugin_skeleton_files(plugin_name : String) -> Array[ProjectFile] {
  [
    ProjectFile::new(path="moon.mod", content=plugin_moon_mod(plugin_name)),
    ProjectFile::new(path="moon.pkg", content=plugin_moon_pkg()),
    ProjectFile::new(path="plugin.mbt", content=plugin_main_mbt(plugin_name)),
    ProjectFile::new(path="README.mbt.md", content=plugin_readme(plugin_name)),
  ]
}

///|
fn plugin_moon_mod(plugin_name : String) -> String {
  let module_name = plugin_name.replace_all(old="-", new="_")
  "name = \"local/lepusa_plugin_\{module_name}\"\n" +
  (
    #|version = "0.1.0"
    #|readme = "README.mbt.md"
    #|repository = ""
    #|license = "Apache-2.0"
    #|keywords = [ "desktop", "lepusa", "plugin" ]
    #|description = "A standalone Lepusa plugin."
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
fn plugin_moon_pkg() -> String {
  (
    #|import {
    #|  "vectie/lepusa"
    #|}
    #|
  )
}

///|
fn plugin_main_mbt(plugin_name : String) -> String {
  let route = "\{plugin_name}.invoke"
  "///|\n" +
  "pub fn plugin() -> @lepusa.Plugin {\n" +
  "  @lepusa.Plugin::new(\"\{plugin_name}\").command_sync(\"invoke\")\n" +
  "}\n" +
  "\n" +
  "///|\n" +
  "pub fn register(\n" +
  "  registry : @lepusa.CommandRegistry,\n" +
  ") -> @lepusa.CommandRegistry {\n" +
  "  registry.register_fn(\n" +
  "    \"\{route}\",\n" +
  "    handler=fn(payload) { Ok(payload) },\n" +
  "  )\n" +
  "}\n" +
  "\n" +
  "///|\n" +
  "pub fn capability(window_label : String) -> @lepusa.Capability {\n" +
  "  @lepusa.Capability::new(\"\{plugin_name}\")\n" +
  "    .window(window_label)\n" +
  "    .command(\"\{route}\")\n" +
  "}\n"
}

///|
fn plugin_readme(plugin_name : String) -> String {
  "# Lepusa Plugin: \{plugin_name}\n" +
  (
    #|
    #|A standalone Lepusa plugin scaffolded by `lepusa plugin new`.
    #|
    #|The plugin exposes:
    #|
    #|- `plugin()` for app manifests.
    #|- `register(registry)` for native command dispatch.
    #|- `capability(window_label)` for scoped route access.
    #|
  )
}
