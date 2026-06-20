///|
pub struct NativeWebViewLaunchPacket {
  title : Bytes
  load_url : Bytes
  initialization_script : Bytes
  native_hook : Bytes
  asset_protocol : Bytes
  width : Int
  height : Int
  resizable : Int
} derive(Debug, Eq)

///|
pub fn NativeWebViewPlan::launch_packet(
  self : NativeWebViewPlan,
) -> NativeWebViewLaunchPacket {
  {
    title: @utf8.encode(self.title()),
    load_url: @utf8.encode(self.load_url()),
    initialization_script: @utf8.encode(self.initialization_script()),
    native_hook: @utf8.encode(self.native_hook()),
    asset_protocol: @utf8.encode(self.asset_protocol()),
    width: self.width(),
    height: self.height(),
    resizable: if self.resizable() {
      1
    } else {
      0
    },
  }
}

///|
pub fn NativeWebViewLaunchPacket::title(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.title
}

///|
pub fn NativeWebViewLaunchPacket::load_url(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.load_url
}

///|
pub fn NativeWebViewLaunchPacket::initialization_script(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.initialization_script
}

///|
pub fn NativeWebViewLaunchPacket::native_hook(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.native_hook
}

///|
pub fn NativeWebViewLaunchPacket::asset_protocol(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.asset_protocol
}

///|
pub fn NativeWebViewLaunchPacket::width(
  self : NativeWebViewLaunchPacket,
) -> Int {
  self.width
}

///|
pub fn NativeWebViewLaunchPacket::height(
  self : NativeWebViewLaunchPacket,
) -> Int {
  self.height
}

///|
pub fn NativeWebViewLaunchPacket::resizable(
  self : NativeWebViewLaunchPacket,
) -> Int {
  self.resizable
}
