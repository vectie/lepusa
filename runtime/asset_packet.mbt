///|
pub fn RuntimeAssetResponse::to_native_protocol_packet(
  self : RuntimeAssetResponse,
) -> Bytes {
  match self.body() {
    VirtualContent(content) =>
      native_asset_protocol_ok_packet("virtual", self.mime_type(), content)
    LocalFile(path) | PackagedFile(path) =>
      native_asset_protocol_ok_packet("file", self.mime_type(), path)
  }
}

///|
pub fn RuntimeAssetResponse::to_native_load_url(
  self : RuntimeAssetResponse,
) -> String {
  match self.body() {
    VirtualContent(content) => native_asset_data_url(self.mime_type(), content)
    LocalFile(path) | PackagedFile(path) => native_file_url(path)
  }
}

///|
pub fn NativeRuntime::initial_load_url(
  self : NativeRuntime,
  spec : RuntimeWebViewSpec,
) -> Result[String, String] {
  if native_protocol_load_url(spec.url(), spec.asset_protocol()) ||
    native_direct_load_url(spec.url()) {
    Ok(spec.url())
  } else {
    match self.host().snapshot() {
      Err(problems) =>
        Err(problems.get(0).unwrap_or("runtime session is invalid"))
      Ok(session) =>
        match session.resolve_asset(spec.url()) {
          Ok(asset) => Ok(asset.to_native_load_url())
          Err(problem) => Err(problem)
        }
    }
  }
}

///|
pub fn native_asset_load_url_from_json(json : String) -> Result[String, String] {
  try @json.parse(json) catch {
    error => Err("invalid asset response: \{error}")
  } noraise {
    Object(response) =>
      if native_asset_response_bool(response, "ok").unwrap_or(false) {
        match native_asset_response_object(response, "body") {
          Some(body) => {
            let kind = native_asset_response_string(body, "kind").unwrap_or("")
            match kind {
              "virtual" =>
                Ok(
                  native_asset_data_url(
                    native_asset_response_string(response, "mimeType").unwrap_or(
                      "text/plain",
                    ),
                    native_asset_response_string(body, "content").unwrap_or(""),
                  ),
                )
              "local-file" | "packaged-file" =>
                Ok(
                  native_file_url(
                    native_asset_response_string(body, "path").unwrap_or(""),
                  ),
                )
              _ => Err("unsupported asset kind: \{kind}")
            }
          }
          None => Err("asset response body is required")
        }
      } else {
        Err(
          native_asset_response_string(response, "error").unwrap_or(
            "asset resolution failed",
          ),
        )
      }
    _ => Err("asset response must be a json object")
  }
}

///|
pub fn native_direct_load_url(url : String) -> Bool {
  url.has_prefix("http://") ||
  url.has_prefix("https://") ||
  url.has_prefix("file://") ||
  url.has_prefix("data:")
}

///|
pub fn native_protocol_load_url(url : String, protocol : String) -> Bool {
  protocol != "" && url.has_prefix("\{protocol}://")
}

///|
pub fn native_asset_protocol_packet_from_json(json : String) -> Bytes {
  try @json.parse(json) catch {
    error =>
      native_asset_protocol_error_packet("invalid asset response: \{error}")
  } noraise {
    Object(response) =>
      if native_asset_response_bool(response, "ok").unwrap_or(false) {
        match native_asset_response_object(response, "body") {
          Some(body) => {
            let mime_type = native_asset_response_string(response, "mimeType").unwrap_or(
              "application/octet-stream",
            )
            match native_asset_response_string(body, "kind").unwrap_or("") {
              "virtual" =>
                native_asset_protocol_ok_packet(
                  "virtual",
                  mime_type,
                  native_asset_response_string(body, "content").unwrap_or(""),
                )
              "local-file" | "packaged-file" =>
                native_asset_protocol_ok_packet(
                  "file",
                  mime_type,
                  native_asset_response_string(body, "path").unwrap_or(""),
                )
              kind =>
                native_asset_protocol_error_packet(
                  "unsupported asset kind: \{kind}",
                )
            }
          }
          None =>
            native_asset_protocol_error_packet(
              "asset response body is required",
            )
        }
      } else {
        native_asset_protocol_error_packet(
          native_asset_response_string(response, "error").unwrap_or(
            "asset resolution failed",
          ),
        )
      }
    _ =>
      native_asset_protocol_error_packet("asset response must be a json object")
  }
}

///|
fn native_asset_data_url(mime_type : String, content : String) -> String {
  "data:\{mime_type};base64,\{@base64.encode(@utf8.encode(content).view())}"
}

///|
fn native_file_url(path : String) -> String {
  if path.has_prefix("file://") {
    path
  } else {
    "file://\{path}"
  }
}

///|
fn native_asset_protocol_ok_packet(
  kind : String,
  mime_type : String,
  body : String,
) -> Bytes {
  @utf8.encode("ok\n\{kind}\n\{mime_type}\n\{body}")
}

///|
fn native_asset_protocol_error_packet(message : String) -> Bytes {
  @utf8.encode("error\n\{message}")
}

///|
fn native_asset_response_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn native_asset_response_string(
  object : Map[String, Json],
  key : String,
) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn native_asset_response_bool(
  object : Map[String, Json],
  key : String,
) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}
