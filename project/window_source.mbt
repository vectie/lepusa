///|
fn project_windows_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> Array[@lepusa.WindowConfig] {
  match optional_config_array(object, "windows") {
    Some(items) => {
      let windows : Array[@lepusa.WindowConfig] = []
      for item in items {
        match item {
          Object(window_object) =>
            windows.push(
              window_config_from_object(window_object, base_dir~, problems),
            )
          _ => problems.push("project windows entries must be objects")
        }
      }
      windows
    }
    None =>
      match optional_config_object(object, "window") {
        Some(window_object) =>
          [window_config_from_object(window_object, base_dir~, problems)]
        None => {
          problems.push("project window is required")
          []
        }
      }
  }
}

///|
fn runtime_config_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.RuntimeConfig {
  let backend = optional_config_string(object, "backend").unwrap_or(
    "system-webview",
  )
  let devtools = optional_config_bool(object, "devtools").unwrap_or(false)
  let asset_protocol = optional_config_string(object, "assetProtocol").unwrap_or(
    "lepusa",
  )
  match backend {
    "system-webview" =>
      @lepusa.RuntimeConfig::system_webview(devtools~, asset_protocol~)
    "headless" => @lepusa.RuntimeConfig::headless()
    value => {
      problems.push("unknown runtime backend: \{value}")
      @lepusa.RuntimeConfig::system_webview()
    }
  }
}

///|
fn window_config_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.WindowConfig {
  let label = optional_config_string(object, "label").unwrap_or("main")
  let title = optional_config_string(object, "title").unwrap_or("Lepusa")
  let width = optional_config_int(object, "width").unwrap_or(1000)
  let height = optional_config_int(object, "height").unwrap_or(720)
  let resizable = optional_config_bool(object, "resizable").unwrap_or(true)
  let window = @lepusa.WindowConfig::new(
    label~,
    title~,
    width~,
    height~,
    resizable~,
  )
  match optional_config_object(object, "source") {
    Some(source_object) =>
      window.with_source(source_from_object(source_object, base_dir~, problems))
    None => window
  }
}

///|
fn source_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Source {
  match optional_config_string(object, "html") {
    Some(html) => return @lepusa.Source::html(html)
    None => ()
  }
  match optional_config_string(object, "localPath") {
    Some(path) => return @lepusa.Source::local_path(config_path(base_dir, path))
    None => ()
  }
  match optional_config_string(object, "packaged") {
    Some(path) => return @lepusa.Source::packaged(config_path(base_dir, path))
    None => ()
  }
  match optional_config_string(object, "url") {
    Some(url) => return @lepusa.Source::url(url)
    None => ()
  }
  match optional_config_object(object, "localhost") {
    Some(localhost) => return localhost_source_from_object(localhost, problems)
    None => ()
  }
  problems.push(
    "project source must include html, localPath, packaged, url, or localhost",
  )
  @lepusa.Source::html("<main></main>")
}

///|
fn localhost_source_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.Source {
  let port = required_config_int(object, "port", problems)
  let host = optional_config_string(object, "host").unwrap_or("127.0.0.1")
  let path = optional_config_string(object, "path").unwrap_or("/")
  let readiness_path = optional_config_string(object, "readinessPath")
  let command = optional_config_string_array(object, "command", problems).unwrap_or([],
  )
  @lepusa.Source::localhost(port~, host~, path~, readiness_path?, command~)
}
