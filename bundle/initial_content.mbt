///|
enum BundledContentResult {
  BundledContentChecked
  BundledContentSkipped
} derive(Debug, Eq)

///|
async fn verify_initial_content(path : String) -> BundleWriteCheck {
  let content = @fs.read_file(path) catch {
    error =>
      return BundleWriteCheck::new(
        kind=InitialContentCheck,
        path~,
        ok=false,
        message="could not read runtime manifest: \{error}",
      )
  }
  let text = content.text()
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) =>
      match verify_bundled_initial_content(manifest) {
        Ok((checked, skipped)) =>
          BundleWriteCheck::new(
            kind=InitialContentCheck,
            path~,
            ok=true,
            message="initial content checked=\{checked} skipped=\{skipped}",
          )
        Err(problem) =>
          BundleWriteCheck::new(
            kind=InitialContentCheck,
            path~,
            ok=false,
            message=problem,
          )
      }
    Err(problem) =>
      BundleWriteCheck::new(
        kind=InitialContentCheck,
        path~,
        ok=false,
        message="runtime manifest parse failed: \{problem}",
      )
  }
}

///|
async fn verify_bundled_initial_content(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[(Int, Int), String] {
  match manifest.webviews() {
    Ok(webviews) => {
      let mut checked = 0
      let mut skipped = 0
      for webview in webviews {
        match verify_bundled_webview_content(manifest, webview) {
          Ok(BundledContentChecked) => checked += 1
          Ok(BundledContentSkipped) => skipped += 1
          Err(problem) => return Err(problem)
        }
      }
      Ok((checked, skipped))
    }
    Err(problem) => Err("runtime manifest webviews invalid: \{problem}")
  }
}

///|
async fn verify_bundled_webview_content(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[BundledContentResult, String] {
  let url = webview.url()
  if url.has_prefix("http://") || url.has_prefix("https://") {
    return Ok(BundledContentSkipped)
  }
  if url.has_prefix("data:") {
    if url.trim() == "data:" {
      Err("window \{webview.label()} has blank data url")
    } else {
      Ok(BundledContentChecked)
    }
  } else if url.has_prefix("file://") {
    verify_bundled_file_content(webview.label(), url[7:].to_owned())
  } else {
    verify_bundled_asset_content(
      webview.label(),
      url,
      manifest.resolve_asset_json(url),
    )
  }
}

///|
async fn verify_bundled_asset_content(
  window_label : String,
  url : String,
  asset_json : String,
) -> Result[BundledContentResult, String] {
  try @json.parse(asset_json) catch {
    error => Err("window \{window_label} asset response invalid: \{error}")
  } noraise {
    Object(response) =>
      if bundled_asset_bool(response, "ok").unwrap_or(false) {
        match bundled_asset_object(response, "body") {
          Some(body) =>
            match bundled_asset_string(body, "kind").unwrap_or("") {
              "virtual" => {
                let content = bundled_asset_string(body, "content").unwrap_or(
                  "",
                )
                if content.trim() == "" {
                  Err("window \{window_label} has blank virtual asset: \{url}")
                } else {
                  Ok(BundledContentChecked)
                }
              }
              "local-file" | "packaged-file" =>
                verify_bundled_file_content(
                  window_label,
                  bundled_asset_string(body, "path").unwrap_or(""),
                )
              kind =>
                Err("window \{window_label} asset kind unsupported: \{kind}")
            }
          None => Err("window \{window_label} asset response body is required")
        }
      } else {
        Err(
          "window \{window_label} asset failed: " +
          bundled_asset_string(response, "error").unwrap_or(
            "asset resolution failed",
          ),
        )
      }
    _ => Err("window \{window_label} asset response must be a json object")
  }
}

///|
async fn verify_bundled_file_content(
  window_label : String,
  path : String,
) -> Result[BundledContentResult, String] {
  if path == "" {
    return Err("window \{window_label} file path is required")
  }
  let text = @fs.read_file(path).text() catch {
    error =>
      return Err("window \{window_label} file is unreadable: \{path}: \{error}")
  }
  if text.trim() == "" {
    Err("window \{window_label} file is blank: \{path}")
  } else {
    Ok(BundledContentChecked)
  }
}

///|
fn bundled_asset_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn bundled_asset_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn bundled_asset_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}
