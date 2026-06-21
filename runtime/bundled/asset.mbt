///|
pub fn BundledRuntimeManifest::resolve_asset_json(
  self : BundledRuntimeManifest,
  url : String,
) -> String {
  match parse_runtime_asset_url(url) {
    Err(problem) => runtime_asset_error_json(url, problem)
    Ok(parsed) => {
      let expected_scheme = optional_string(self.runtime, "assetProtocol").unwrap_or(
        "lepusa",
      )
      if parsed.scheme != expected_scheme {
        return runtime_asset_error_json(
          url,
          "asset scheme mismatch: \{parsed.scheme}",
        )
      }
      match parsed.authority {
        "runtime" => self.resolve_runtime_bridge_json(url, parsed.path)
        "inline" | "rabbita" => self.resolve_virtual_json(url, parsed)
        "local" => self.resolve_file_json(url, parsed, local_asset=true)
        "packaged" => self.resolve_file_json(url, parsed, local_asset=false)
        value =>
          runtime_asset_error_json(url, "unknown asset authority: \{value}")
      }
    }
  }
}

///|
pub fn BundledRuntimeManifest::resolve_window_asset_json(
  self : BundledRuntimeManifest,
  window_label~ : String,
  url : String,
) -> String {
  if window_label == "" {
    return runtime_asset_error_json(
      url, "asset request window label is required",
    )
  }
  match parse_runtime_asset_url(url) {
    Err(problem) => runtime_asset_error_json(url, problem)
    Ok(parsed) => {
      let expected_scheme = optional_string(self.runtime, "assetProtocol").unwrap_or(
        "lepusa",
      )
      if parsed.scheme != expected_scheme {
        return runtime_asset_error_json(
          url,
          "asset scheme mismatch: \{parsed.scheme}",
        )
      }
      if parsed.authority == "runtime" {
        return self.resolve_runtime_bridge_json(url, parsed.path)
      }
      match parse_window_asset_path(parsed.path) {
        Err(problem) => runtime_asset_error_json(url, problem)
        Ok((asset_window, _)) =>
          if asset_window != window_label {
            runtime_asset_error_json(
              url,
              "asset request for window \{window_label} cannot load window \{asset_window} asset",
            )
          } else {
            self.resolve_asset_json(url)
          }
      }
    }
  }
}

///|
fn BundledRuntimeManifest::resolve_runtime_bridge_json(
  self : BundledRuntimeManifest,
  url : String,
  path : String,
) -> String {
  if path != "bridge.js" {
    return runtime_asset_error_json(url, "unknown runtime asset: \{path}")
  }
  match self.first_initialization_script() {
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
fn BundledRuntimeManifest::resolve_virtual_json(
  self : BundledRuntimeManifest,
  url : String,
  parsed : ParsedRuntimeAssetUrl,
) -> String {
  match parse_window_asset_path(parsed.path) {
    Err(problem) => runtime_asset_error_json(url, problem)
    Ok((window_label, path)) => {
      for item in optional_array(self.runtime, "virtualFiles").unwrap_or([]) {
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
fn BundledRuntimeManifest::resolve_file_json(
  self : BundledRuntimeManifest,
  url : String,
  parsed : ParsedRuntimeAssetUrl,
  local_asset~ : Bool,
) -> String {
  match parse_window_asset_path(parsed.path) {
    Err(problem) => runtime_asset_error_json(url, problem)
    Ok((window_label, path)) =>
      match self.protocol_root_for(window_label, packaged=!local_asset) {
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
            join_asset_path(self.bundle_root, root)
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
fn BundledRuntimeManifest::first_initialization_script(
  self : BundledRuntimeManifest,
) -> String? {
  for item in optional_array(self.runtime, "webviews").unwrap_or([]) {
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
fn BundledRuntimeManifest::protocol_root_for(
  self : BundledRuntimeManifest,
  label : String,
  packaged~ : Bool,
) -> String? {
  for item in optional_array(self.runtime, "protocolMappings").unwrap_or([]) {
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
