///|
pub(all) enum TitleBarStyle {
  Native
  Transparent
  Hidden
} derive(Debug, Eq)

///|
pub struct WindowConfig {
  label : String
  title : String
  width : Int
  height : Int
  resizable : Bool
  title_bar : TitleBarStyle
  source : Source?
} derive(Debug, Eq)

///|
pub fn WindowConfig::new(
  label? : String = "main",
  title? : String = "Lepusa",
  width? : Int = 1000,
  height? : Int = 720,
  resizable? : Bool = true,
  title_bar? : TitleBarStyle = Native,
  source? : Source,
) -> WindowConfig {
  { label, title, width, height, resizable, title_bar, source }
}

///|
pub fn WindowConfig::with_source(
  self : WindowConfig,
  source : Source,
) -> WindowConfig {
  { ..self, source: Some(source) }
}

///|
pub struct ResolvedWindow {
  label : String
  title : String
  width : Int
  height : Int
  resizable : Bool
  title_bar : TitleBarStyle
  source : ResolvedSource
} derive(Debug, Eq)

///|
pub fn ResolvedWindow::label(self : ResolvedWindow) -> String {
  self.label
}

///|
pub fn ResolvedWindow::title(self : ResolvedWindow) -> String {
  self.title
}

///|
pub fn ResolvedWindow::width(self : ResolvedWindow) -> Int {
  self.width
}

///|
pub fn ResolvedWindow::height(self : ResolvedWindow) -> Int {
  self.height
}

///|
pub fn ResolvedWindow::resizable(self : ResolvedWindow) -> Bool {
  self.resizable
}

///|
pub fn ResolvedWindow::title_bar(self : ResolvedWindow) -> TitleBarStyle {
  self.title_bar
}

///|
pub fn ResolvedWindow::url(self : ResolvedWindow) -> String {
  self.source.url()
}

///|
pub fn ResolvedWindow::source(self : ResolvedWindow) -> ResolvedSource {
  self.source
}

///|
pub fn WindowConfig::resolve(
  self : WindowConfig,
  asset_protocol? : String = "lepusa",
) -> Result[ResolvedWindow, Array[String]] {
  let problems = self.validate()
  if !problems.is_empty() {
    return Err(problems)
  }
  match self.source {
    Some(source) =>
      match source.resolve(window_label=self.label, asset_protocol~) {
        Ok(resolved_source) =>
          Ok({
            label: self.label,
            title: self.title,
            width: self.width,
            height: self.height,
            resizable: self.resizable,
            title_bar: self.title_bar,
            source: resolved_source,
          })
        Err(problem) => Err([problem])
      }
    None => Err(["window source is required"])
  }
}

///|
pub fn WindowConfig::validate(self : WindowConfig) -> Array[String] {
  let problems : Array[String] = []
  if self.label == "" {
    problems.push("window label is required")
  }
  if self.title == "" {
    problems.push("window title is required")
  }
  if self.width <= 0 {
    problems.push("window width must be positive")
  }
  if self.height <= 0 {
    problems.push("window height must be positive")
  }
  match self.source {
    None => problems.push("window source is required")
    Some(source) =>
      if source.is_empty() {
        problems.push("window source must not be empty")
      }
  }
  problems
}
