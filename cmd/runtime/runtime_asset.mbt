///|
fn render_runtime_asset_text(
  manifest_path : String,
  text : String,
  url : String,
) -> RuntimeCliResult {
  let json = @json.parse(text) catch {
    error =>
      return runtime_fail(
        "Lepusa runtime asset\n[fail] invalid runtime json: \{error}\n",
      )
  }
  match json {
    Object(object) =>
      match optional_object(object, "runtime") {
        Some(runtime) =>
          runtime_ok(
            resolve_runtime_asset_json(
              bundle_root_for_manifest(manifest_path),
              runtime,
              url,
            ) +
            "\n",
          )
        None =>
          runtime_fail(
            "Lepusa runtime asset\n[fail] runtime object is required\n",
          )
      }
    _ =>
      runtime_fail(
        "Lepusa runtime asset\n[fail] runtime manifest must be a json object\n",
      )
  }
}

///|
fn resolve_runtime_asset_json(
  bundle_root : String,
  runtime : Map[String, Json],
  url : String,
) -> String {
  match parse_runtime_asset_url(url) {
    Err(problem) => runtime_asset_error_json(url, problem)
    Ok(parsed) => {
      let expected_scheme = optional_string(runtime, "assetProtocol").unwrap_or(
        "lepusa",
      )
      if parsed.scheme != expected_scheme {
        return runtime_asset_error_json(
          url,
          "asset scheme mismatch: \{parsed.scheme}",
        )
      }
      match parsed.authority {
        "runtime" => resolve_runtime_bridge_json(runtime, url, parsed.path)
        "inline" | "rabbita" =>
          resolve_runtime_virtual_json(runtime, url, parsed)
        "local" =>
          resolve_runtime_file_json(runtime, url, parsed, local_asset=true)
        "packaged" =>
          resolve_runtime_file_json(
            runtime,
            url,
            parsed,
            local_asset=false,
            bundle_root~,
          )
        value =>
          runtime_asset_error_json(url, "unknown asset authority: \{value}")
      }
    }
  }
}

///|
fn resolve_runtime_bridge_json(
  runtime : Map[String, Json],
  url : String,
  path : String,
) -> String {
  if path != "bridge.js" {
    return runtime_asset_error_json(url, "unknown runtime asset: \{path}")
  }
  match first_initialization_script(runtime) {
    Some(script) =>
      runtime_asset_ok_json(
        url,
        "application/javascript",
        "virtual",
        content=script,
      )
    None => runtime_asset_error_json(url, "runtime bridge script not found")
  }
}

///|
fn resolve_runtime_virtual_json(
  runtime : Map[String, Json],
  url : String,
  parsed : ParsedRuntimeAssetUrl,
) -> String {
  match parse_window_asset_path(parsed.path) {
    Err(problem) => runtime_asset_error_json(url, problem)
    Ok((window_label, path)) => {
      for item in optional_array(runtime, "virtualFiles").unwrap_or([]) {
        match item {
          Object(file) =>
            if optional_string(file, "windowLabel").unwrap_or("") ==
              window_label &&
              optional_string(file, "path").unwrap_or("") == path {
              return runtime_asset_ok_json(
                url,
                optional_string(file, "mimeType").unwrap_or(
                  mime_type_for_path(path),
                ),
                "virtual",
                content=optional_string(file, "content").unwrap_or(""),
              )
            }
          _ => ()
        }
      }
      runtime_asset_error_json(
        url,
        "virtual asset not found: \{window_label}/\{path}",
      )
    }
  }
}

///|
fn resolve_runtime_file_json(
  runtime : Map[String, Json],
  url : String,
  parsed : ParsedRuntimeAssetUrl,
  local_asset~ : Bool,
  bundle_root? : String = "",
) -> String {
  match parse_window_asset_path(parsed.path) {
    Err(problem) => runtime_asset_error_json(url, problem)
    Ok((window_label, path)) =>
      match protocol_root_for(runtime, window_label, packaged=!local_asset) {
        None =>
          if local_asset {
            runtime_asset_error_json(
              url,
              "local asset root not found: \{window_label}",
            )
          } else {
            runtime_asset_error_json(
              url,
              "packaged asset root not found: \{window_label}",
            )
          }
        Some(root) => {
          let asset_root = if local_asset {
            root
          } else {
            join_asset_path(bundle_root, root)
          }
          runtime_asset_ok_json(
            url,
            mime_type_for_path(path),
            if local_asset {
              "local-file"
            } else {
              "packaged-file"
            },
            path=join_asset_path(asset_root, path),
          )
        }
      }
  }
}

///|
struct ParsedRuntimeAssetUrl {
  scheme : String
  authority : String
  path : String
} derive(Debug, Eq)

///|
fn parse_runtime_asset_url(
  url : String,
) -> Result[ParsedRuntimeAssetUrl, String] {
  match url.find("://") {
    None => Err("asset url must include scheme")
    Some(index) => {
      let scheme = url[:index].to_owned()
      let rest = url[index + 3:].to_owned()
      match rest.find("/") {
        None => Ok({ scheme, authority: rest, path: "" })
        Some(path_index) =>
          Ok({
            scheme,
            authority: rest[:path_index].to_owned(),
            path: strip_asset_suffix(rest[path_index + 1:].to_owned()),
          })
      }
    }
  }
}

///|
fn strip_asset_suffix(path : String) -> String {
  let without_query = match path.find("?") {
    None => path
    Some(index) => path[:index].to_owned()
  }
  match without_query.find("#") {
    None => without_query
    Some(index) => without_query[:index].to_owned()
  }
}

///|
fn parse_window_asset_path(path : String) -> Result[(String, String), String] {
  match path.find("/") {
    None => Err("asset path must include window label")
    Some(index) => {
      let window_label = path[:index].to_owned()
      let asset_path = path[index + 1:].to_owned()
      if window_label == "" {
        Err("asset window label is required")
      } else if !is_safe_asset_path(asset_path) {
        Err("unsafe asset path: \{asset_path}")
      } else {
        Ok((window_label, asset_path))
      }
    }
  }
}

///|
fn is_safe_asset_path(path : String) -> Bool {
  if path == "" || path.has_prefix("/") || path.has_prefix("\\") {
    return false
  }
  for segment in path.split("/") {
    if segment == "" || segment == "." || segment == ".." {
      return false
    }
    if segment.contains("\\") {
      return false
    }
  }
  true
}

///|
fn first_initialization_script(runtime : Map[String, Json]) -> String? {
  for item in optional_array(runtime, "webviews").unwrap_or([]) {
    match item {
      Object(webview) =>
        match optional_array(webview, "initializationScripts") {
          Some(scripts) =>
            match scripts.get(0) {
              Some(String(script)) => return Some(script)
              _ => ()
            }
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn protocol_root_for(
  runtime : Map[String, Json],
  label : String,
  packaged~ : Bool,
) -> String? {
  for item in optional_array(runtime, "protocolMappings").unwrap_or([]) {
    match item {
      Object(mapping) =>
        if optional_string(mapping, "windowLabel").unwrap_or("") == label {
          let root = optional_string(mapping, "root").unwrap_or("")
          if packaged && root.has_prefix("package:") {
            return Some(root[8:].to_owned())
          } else if !packaged &&
            !root.has_prefix("memory:") &&
            !root.has_prefix("package:") {
            return Some(root)
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn bundle_root_for_manifest(path : String) -> String {
  let dir = parent_directory(path)
  if dir == "lepusa" || dir.has_suffix("/lepusa") || dir.has_suffix("\\lepusa") {
    parent_directory(dir)
  } else {
    dir
  }
}

///|
fn parent_directory(path : String) -> String {
  let trimmed = path.trim_end(chars="/\\").to_owned()
  let mut last = -1
  for i in 0..<trimmed.length() {
    let char = trimmed[i]
    if char == '/' || char == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    trimmed[:last].to_owned()
  }
}

///|
fn join_asset_path(root : String, path : String) -> String {
  let root = root.trim_end(chars="/\\").to_owned()
  if root == "" || root == "." {
    path
  } else {
    "\{root}/\{path}"
  }
}

///|
fn mime_type_for_path(path : String) -> String {
  if path.has_suffix(".html") || path.has_suffix(".htm") {
    "text/html"
  } else if path.has_suffix(".js") || path.has_suffix(".mjs") {
    "application/javascript"
  } else if path.has_suffix(".css") {
    "text/css"
  } else if path.has_suffix(".json") {
    "application/json"
  } else if path.has_suffix(".svg") {
    "image/svg+xml"
  } else if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".jpg") || path.has_suffix(".jpeg") {
    "image/jpeg"
  } else if path.has_suffix(".wasm") {
    "application/wasm"
  } else {
    "application/octet-stream"
  }
}

///|
fn runtime_asset_ok_json(
  url : String,
  mime_type : String,
  kind : String,
  content? : String = "",
  path? : String = "",
) -> String {
  let body = if kind == "virtual" {
    "\"body\":{\"kind\":\"virtual\",\"content\":\{content.json_string()}}"
  } else {
    "\"body\":{\"kind\":\{kind.json_string()},\"path\":\{path.json_string()}}"
  }
  [
    "{",
    "\"ok\":true,",
    "\"url\":\{url.json_string()},",
    "\"mimeType\":\{mime_type.json_string()},",
    body,
    "}",
  ].join("")
}

///|
fn runtime_asset_error_json(url : String, problem : String) -> String {
  [
    "{",
    "\"ok\":false,",
    "\"url\":\{url.json_string()},",
    "\"error\":\{problem.json_string()}",
    "}",
  ].join("")
}

///|
fn String::json_string(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
