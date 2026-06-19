///|
pub struct RuntimeWebViewSpec {
  label : String
  title : String
  url : String
  width : Int
  height : Int
  resizable : Bool
  title_bar : @lepusa.TitleBarStyle
  devtools : Bool
  asset_protocol : String
  bridge_global_name : String
  native_hook : String
  event_dispatch_hook : String
  allowed_routes : Array[String]
  initialization_scripts : Array[String]
} derive(Debug, Eq)

///|
pub fn RuntimeHost::webviews(
  self : RuntimeHost,
) -> Result[Array[RuntimeWebViewSpec], Array[String]] {
  let specs : Array[RuntimeWebViewSpec] = []
  let problems : Array[String] = []
  for window in self.plan.windows() {
    match
      self.plan.bridge_script(
        config=@lepusa.BridgeConfig::new(window_label=window.label()),
      ) {
      Ok(bridge) =>
        specs.push(
          RuntimeWebViewSpec::from_window(
            window,
            devtools=self.plan.devtools(),
            asset_protocol=self.plan.asset_protocol(),
            bridge~,
          ),
        )
      Err(bridge_problems) =>
        for problem in bridge_problems {
          problems.push(problem)
        }
    }
  }
  if problems.is_empty() {
    Ok(specs)
  } else {
    Err(problems)
  }
}

///|
fn RuntimeWebViewSpec::from_window(
  window : @lepusa.ResolvedWindow,
  devtools~ : Bool,
  asset_protocol~ : String,
  bridge~ : @lepusa.BridgeScript,
) -> RuntimeWebViewSpec {
  {
    label: window.label(),
    title: window.title(),
    url: window.url(),
    width: window.width(),
    height: window.height(),
    resizable: window.resizable(),
    title_bar: window.title_bar(),
    devtools,
    asset_protocol,
    bridge_global_name: bridge.global_name(),
    native_hook: bridge.native_hook(),
    event_dispatch_hook: bridge.event_dispatch_hook(),
    allowed_routes: bridge.routes(),
    initialization_scripts: [bridge.source()],
  }
}

///|
pub fn RuntimeWebViewSpec::label(self : RuntimeWebViewSpec) -> String {
  self.label
}

///|
pub fn RuntimeWebViewSpec::title(self : RuntimeWebViewSpec) -> String {
  self.title
}

///|
pub fn RuntimeWebViewSpec::url(self : RuntimeWebViewSpec) -> String {
  self.url
}

///|
pub fn RuntimeWebViewSpec::width(self : RuntimeWebViewSpec) -> Int {
  self.width
}

///|
pub fn RuntimeWebViewSpec::height(self : RuntimeWebViewSpec) -> Int {
  self.height
}

///|
pub fn RuntimeWebViewSpec::resizable(self : RuntimeWebViewSpec) -> Bool {
  self.resizable
}

///|
pub fn RuntimeWebViewSpec::title_bar(
  self : RuntimeWebViewSpec,
) -> @lepusa.TitleBarStyle {
  self.title_bar
}

///|
pub fn RuntimeWebViewSpec::devtools(self : RuntimeWebViewSpec) -> Bool {
  self.devtools
}

///|
pub fn RuntimeWebViewSpec::asset_protocol(self : RuntimeWebViewSpec) -> String {
  self.asset_protocol
}

///|
pub fn RuntimeWebViewSpec::bridge_global_name(
  self : RuntimeWebViewSpec,
) -> String {
  self.bridge_global_name
}

///|
pub fn RuntimeWebViewSpec::native_hook(self : RuntimeWebViewSpec) -> String {
  self.native_hook
}

///|
pub fn RuntimeWebViewSpec::event_dispatch_hook(
  self : RuntimeWebViewSpec,
) -> String {
  self.event_dispatch_hook
}

///|
pub fn RuntimeWebViewSpec::allowed_routes(
  self : RuntimeWebViewSpec,
) -> Array[String] {
  self.allowed_routes.copy()
}

///|
pub fn RuntimeWebViewSpec::initialization_scripts(
  self : RuntimeWebViewSpec,
) -> Array[String] {
  self.initialization_scripts.copy()
}
