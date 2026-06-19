///|
pub struct BundledWebView {
  label : String
  title : String
  url : String
  width : Int
  height : Int
  resizable : Bool
  native_hook : String
  initialization_scripts : Array[String]
} derive(Debug, Eq)

///|
pub fn BundledRuntimeManifest::first_webview(
  self : BundledRuntimeManifest,
) -> Result[BundledWebView, String] {
  match self.webviews() {
    Ok(webviews) =>
      match webviews.get(0) {
        Some(webview) => Ok(webview)
        None => Err("runtime webviews must include at least one window")
      }
    Err(problem) => Err(problem)
  }
}

///|
pub fn BundledRuntimeManifest::webviews(
  self : BundledRuntimeManifest,
) -> Result[Array[BundledWebView], String] {
  let parsed : Array[BundledWebView] = []
  let values = optional_array(self.runtime, "webviews").unwrap_or([])
  if values.is_empty() {
    return Err("runtime webviews must include at least one window")
  }
  for value in values {
    match value {
      Object(webview) =>
        match self.parse_webview(webview) {
          Ok(parsed_webview) => parsed.push(parsed_webview)
          Err(problem) => return Err(problem)
        }
      _ => return Err("runtime webview must be a json object")
    }
  }
  Ok(parsed)
}

///|
fn BundledRuntimeManifest::parse_webview(
  self : BundledRuntimeManifest,
  webview : Map[String, Json],
) -> Result[BundledWebView, String] {
  match optional_string(webview, "url") {
    Some(url) if url != "" =>
      Ok({
        label: optional_string(webview, "label").unwrap_or("main"),
        title: optional_string(webview, "title").unwrap_or(
          optional_string(self.bundle, "productName").unwrap_or("Lepusa"),
        ),
        url,
        width: optional_int(webview, "width").unwrap_or(1000),
        height: optional_int(webview, "height").unwrap_or(720),
        resizable: optional_bool(webview, "resizable").unwrap_or(true),
        native_hook: optional_string(webview, "nativeHook").unwrap_or(
          "__lepusaInvoke",
        ),
        initialization_scripts: optional_string_array(
          webview, "initializationScripts",
        ),
      })
    _ => Err("runtime webview url is required")
  }
}

///|
pub fn BundledRuntimeManifest::webview_count(
  self : BundledRuntimeManifest,
) -> Int {
  optional_array(self.runtime, "webviews").unwrap_or([]).length()
}

///|
pub fn BundledWebView::label(self : BundledWebView) -> String {
  self.label
}

///|
pub fn BundledWebView::title(self : BundledWebView) -> String {
  self.title
}

///|
pub fn BundledWebView::url(self : BundledWebView) -> String {
  self.url
}

///|
pub fn BundledWebView::width(self : BundledWebView) -> Int {
  self.width
}

///|
pub fn BundledWebView::height(self : BundledWebView) -> Int {
  self.height
}

///|
pub fn BundledWebView::resizable(self : BundledWebView) -> Bool {
  self.resizable
}

///|
pub fn BundledWebView::native_hook(self : BundledWebView) -> String {
  self.native_hook
}

///|
pub fn BundledWebView::initialization_scripts(
  self : BundledWebView,
) -> Array[String] {
  self.initialization_scripts.copy()
}

///|
fn optional_int(object : Map[String, Json], key : String) -> Int? {
  match object.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn optional_string_array(
  object : Map[String, Json],
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  match object.get(key) {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(value) => values.push(value)
          _ => ()
        }
      }
    _ => ()
  }
  values
}
