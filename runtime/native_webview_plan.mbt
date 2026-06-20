///|
pub struct NativeWebViewPlan {
  label : String
  title : String
  url : String
  load_url : String
  initialization_script : String
  native_hook : String
  asset_protocol : String
  width : Int
  height : Int
  resizable : Bool
} derive(Debug, Eq)

///|
pub fn NativeWebViewPlan::new(
  label~ : String,
  title~ : String,
  url~ : String,
  load_url~ : String,
  initialization_script~ : String,
  native_hook~ : String,
  asset_protocol~ : String,
  width~ : Int,
  height~ : Int,
  resizable~ : Bool,
) -> NativeWebViewPlan {
  {
    label,
    title,
    url,
    load_url,
    initialization_script,
    native_hook,
    asset_protocol,
    width,
    height,
    resizable,
  }
}

///|
pub fn NativeRuntime::webview_plan(
  self : NativeRuntime,
  spec : RuntimeWebViewSpec,
  initialization_script~ : String,
) -> Result[NativeWebViewPlan, String] {
  match self.initial_load_url(spec) {
    Ok(load_url) =>
      Ok(
        NativeWebViewPlan::new(
          label=spec.label(),
          title=spec.title(),
          url=spec.url(),
          load_url~,
          initialization_script~,
          native_hook=spec.native_hook(),
          asset_protocol=spec.asset_protocol(),
          width=spec.width(),
          height=spec.height(),
          resizable=spec.resizable(),
        ),
      )
    Err(problem) => Err(problem)
  }
}

///|
pub fn NativeWebViewPlan::label(self : NativeWebViewPlan) -> String {
  self.label
}

///|
pub fn NativeWebViewPlan::title(self : NativeWebViewPlan) -> String {
  self.title
}

///|
pub fn NativeWebViewPlan::url(self : NativeWebViewPlan) -> String {
  self.url
}

///|
pub fn NativeWebViewPlan::load_url(self : NativeWebViewPlan) -> String {
  self.load_url
}

///|
pub fn NativeWebViewPlan::initialization_script(
  self : NativeWebViewPlan,
) -> String {
  self.initialization_script
}

///|
pub fn NativeWebViewPlan::native_hook(self : NativeWebViewPlan) -> String {
  self.native_hook
}

///|
pub fn NativeWebViewPlan::asset_protocol(self : NativeWebViewPlan) -> String {
  self.asset_protocol
}

///|
pub fn NativeWebViewPlan::width(self : NativeWebViewPlan) -> Int {
  self.width
}

///|
pub fn NativeWebViewPlan::height(self : NativeWebViewPlan) -> Int {
  self.height
}

///|
pub fn NativeWebViewPlan::resizable(self : NativeWebViewPlan) -> Bool {
  self.resizable
}
