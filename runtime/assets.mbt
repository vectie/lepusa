///|
pub(all) enum RuntimeAssetBody {
  VirtualContent(String)
  LocalFile(String)
  PackagedFile(String)
} derive(Debug, Eq)

///|
pub struct RuntimeAssetResponse {
  url : String
  mime_type : String
  body : RuntimeAssetBody
} derive(Debug, Eq)

///|
struct ParsedAssetUrl {
  scheme : String
  authority : String
  path : String
} derive(Debug, Eq)

///|
pub fn RuntimeAssetResponse::url(self : RuntimeAssetResponse) -> String {
  self.url
}

///|
pub fn RuntimeAssetResponse::mime_type(self : RuntimeAssetResponse) -> String {
  self.mime_type
}

///|
pub fn RuntimeAssetResponse::body(
  self : RuntimeAssetResponse,
) -> RuntimeAssetBody {
  self.body
}

///|
pub fn RuntimeAssetResponse::to_json(self : RuntimeAssetResponse) -> String {
  [
    "{",
    "\"ok\":true,",
    "\"url\":\{self.url.json_string()},",
    "\"mimeType\":\{self.mime_type.json_string()},",
    "\"body\":\{self.body.to_json()}",
    "}",
  ].join("")
}

///|
pub fn RuntimeAssetBody::to_json(self : RuntimeAssetBody) -> String {
  match self {
    VirtualContent(content) =>
      [
        "{",
        "\"kind\":\"virtual\",",
        "\"content\":\{content.json_string()}",
        "}",
      ].join("")
    LocalFile(path) =>
      ["{", "\"kind\":\"local-file\",", "\"path\":\{path.json_string()}", "}"].join(
        "",
      )
    PackagedFile(path) =>
      [
        "{",
        "\"kind\":\"packaged-file\",",
        "\"path\":\{path.json_string()}",
        "}",
      ].join("")
  }
}

///|
pub fn RuntimeSession::bridge_url(self : RuntimeSession) -> String {
  "\{self.asset_protocol}://runtime/bridge.js"
}

///|
pub fn RuntimeHost::resolve_asset_json(
  self : RuntimeHost,
  url : String,
) -> String {
  match self.snapshot() {
    Ok(session) => session.resolve_asset_json(url)
    Err(problems) =>
      runtime_asset_error_json(
        url,
        problems.get(0).unwrap_or("runtime session is invalid"),
      )
  }
}

///|
pub fn RuntimeSession::resolve_asset_json(
  self : RuntimeSession,
  url : String,
) -> String {
  match self.resolve_asset(url) {
    Ok(response) => response.to_json()
    Err(problem) => runtime_asset_error_json(url, problem)
  }
}

///|
pub fn RuntimeSession::resolve_asset(
  self : RuntimeSession,
  url : String,
) -> Result[RuntimeAssetResponse, String] {
  match parse_asset_url(url) {
    Err(problem) => Err(problem)
    Ok(parsed) =>
      if parsed.scheme != self.asset_protocol {
        Err("asset scheme mismatch: \{parsed.scheme}")
      } else if parsed.authority == "runtime" {
        self.resolve_runtime_asset(url, parsed.path)
      } else if parsed.authority == "inline" || parsed.authority == "rabbita" {
        self.resolve_virtual_asset(url, parsed)
      } else if parsed.authority == "local" {
        self.resolve_local_asset(url, parsed)
      } else if parsed.authority == "packaged" {
        self.resolve_packaged_asset(url, parsed)
      } else {
        Err("unknown asset authority: \{parsed.authority}")
      }
  }
}

///|
fn RuntimeSession::resolve_runtime_asset(
  self : RuntimeSession,
  url : String,
  path : String,
) -> Result[RuntimeAssetResponse, String] {
  if path == "bridge.js" {
    Ok({
      url,
      mime_type: "application/javascript",
      body: VirtualContent(self.bridge_source),
    })
  } else {
    Err("unknown runtime asset: \{path}")
  }
}

///|
fn RuntimeSession::resolve_virtual_asset(
  self : RuntimeSession,
  url : String,
  parsed : ParsedAssetUrl,
) -> Result[RuntimeAssetResponse, String] {
  match parse_window_asset_path(parsed.path) {
    Err(problem) => Err(problem)
    Ok((window_label, path)) => {
      for file in self.virtual_files {
        if file.window_label() == window_label && file.path() == path {
          return Ok({
            url,
            mime_type: mime_type_for_path(path),
            body: VirtualContent(file.content()),
          })
        }
      }
      Err("virtual asset not found: \{window_label}/\{path}")
    }
  }
}

///|
fn RuntimeSession::resolve_local_asset(
  self : RuntimeSession,
  url : String,
  parsed : ParsedAssetUrl,
) -> Result[RuntimeAssetResponse, String] {
  match parse_window_asset_path(parsed.path) {
    Err(problem) => Err(problem)
    Ok((window_label, path)) =>
      match self.local_root_for(window_label) {
        None => Err("local asset root not found: \{window_label}")
        Some(root) =>
          Ok({
            url,
            mime_type: mime_type_for_path(path),
            body: LocalFile(join_asset_path(root, path)),
          })
      }
  }
}

///|
fn RuntimeSession::resolve_packaged_asset(
  self : RuntimeSession,
  url : String,
  parsed : ParsedAssetUrl,
) -> Result[RuntimeAssetResponse, String] {
  match parse_window_asset_path(parsed.path) {
    Err(problem) => Err(problem)
    Ok((window_label, path)) =>
      match self.packaged_root_for(window_label) {
        None => Err("packaged asset root not found: \{window_label}")
        Some(root) =>
          Ok({
            url,
            mime_type: mime_type_for_path(path),
            body: PackagedFile(join_asset_path(root, path)),
          })
      }
  }
}

///|
fn RuntimeSession::local_root_for(
  self : RuntimeSession,
  label : String,
) -> String? {
  for mapping in self.protocol_mappings {
    if mapping.window_label() == label &&
      !mapping.root().has_prefix("memory:") &&
      !mapping.root().has_prefix("rabbita:") &&
      !mapping.root().has_prefix("package:") {
      return Some(mapping.root())
    }
  }
  None
}

///|
fn RuntimeSession::packaged_root_for(
  self : RuntimeSession,
  label : String,
) -> String? {
  for mapping in self.protocol_mappings {
    if mapping.window_label() == label && mapping.root().has_prefix("package:") {
      return Some(mapping.root()[8:].to_owned())
    }
  }
  None
}

///|
fn parse_asset_url(url : String) -> Result[ParsedAssetUrl, String] {
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
fn join_asset_path(root : String, path : String) -> String {
  let root = root.trim_end(chars="/\\").to_owned()
  if root == "" {
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
fn runtime_asset_error_json(url : String, problem : String) -> String {
  [
    "{",
    "\"ok\":false,",
    "\"url\":\{url.json_string()},",
    "\"error\":\{problem.json_string()}",
    "}",
  ].join("")
}
