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
