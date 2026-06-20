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
