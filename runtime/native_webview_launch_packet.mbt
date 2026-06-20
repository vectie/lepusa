///|
pub struct NativeWebViewLaunchPacket {
  label : Bytes
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
pub struct NativeWebViewLaunchContext {
  packet : NativeWebViewLaunchPacket
  bridge_scheduler : NativeBridgeScheduler
  async_bridge_executor : NativeBridgeAsyncExecutor
  bridge_loop : NativeBridgeLoopContract
} derive(Debug, Eq)

///|
pub fn NativeWebViewPlan::launch_packet(
  self : NativeWebViewPlan,
) -> NativeWebViewLaunchPacket {
  {
    label: @utf8.encode(self.label()),
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
pub fn NativeWebViewPlan::launch_context(
  self : NativeWebViewPlan,
  bridge_scheduler~ : NativeBridgeScheduler,
) -> NativeWebViewLaunchContext {
  {
    packet: self.launch_packet(),
    bridge_scheduler,
    async_bridge_executor: bridge_scheduler.async_executor(),
    bridge_loop: bridge_scheduler.bridge_loop_contract(),
  }
}

///|
pub fn NativeLaunchSession::first_launch_context(
  self : NativeLaunchSession,
) -> Result[NativeWebViewLaunchContext, String] {
  match self.first_webview() {
    Ok(webview) =>
      Ok(webview.launch_context(bridge_scheduler=self.bridge_scheduler()))
    Err(problem) => Err(problem)
  }
}

///|
pub fn NativeWebViewLaunchContext::packet(
  self : NativeWebViewLaunchContext,
) -> NativeWebViewLaunchPacket {
  self.packet
}

///|
pub fn NativeWebViewLaunchContext::bridge_scheduler(
  self : NativeWebViewLaunchContext,
) -> NativeBridgeScheduler {
  self.bridge_scheduler
}

///|
pub fn NativeWebViewLaunchContext::async_bridge_executor(
  self : NativeWebViewLaunchContext,
) -> NativeBridgeAsyncExecutor {
  self.async_bridge_executor
}

///|
pub fn NativeWebViewLaunchContext::bridge_loop_contract(
  self : NativeWebViewLaunchContext,
) -> NativeBridgeLoopContract {
  self.bridge_loop
}

///|
pub fn NativeWebViewLaunchContext::can_launch(
  self : NativeWebViewLaunchContext,
) -> Bool {
  self.bridge_scheduler.can_launch()
}

///|
pub fn NativeWebViewLaunchContext::launch_blocker(
  self : NativeWebViewLaunchContext,
  platform_name : String,
) -> String? {
  self.bridge_scheduler.launch_blocker(platform_name)
}

///|
pub fn NativeWebViewLaunchContext::to_json(
  self : NativeWebViewLaunchContext,
) -> String {
  [
    "{",
    "\"packet\":\{self.packet.to_json()},",
    "\"bridgeScheduler\":\{self.bridge_scheduler.to_json()},",
    "\"asyncBridgeExecutor\":\{self.async_bridge_executor.to_json()},",
    "\"bridgeLoop\":\{self.bridge_loop.to_json()}",
    "}",
  ].join("")
}

///|
pub fn NativeWebViewLaunchPacket::to_json(
  self : NativeWebViewLaunchPacket,
) -> String {
  [
    "{",
    "\"label\":\{self.label_text().json_string()},",
    "\"title\":\{self.title_text().json_string()},",
    "\"loadUrl\":\{self.load_url_text().json_string()},",
    "\"initializationScript\":\{self.initialization_script_text().json_string()},",
    "\"nativeHook\":\{self.native_hook_text().json_string()},",
    "\"assetProtocol\":\{self.asset_protocol_text().json_string()},",
    "\"width\":\{self.width},",
    "\"height\":\{self.height},",
    "\"resizable\":\{self.resizable}",
    "}",
  ].join("")
}

///|
pub fn NativeWebViewLaunchPacket::label(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.label
}

///|
pub fn NativeWebViewLaunchPacket::label_text(
  self : NativeWebViewLaunchPacket,
) -> String {
  @utf8.decode(self.label) catch {
    _ => ""
  }
}

///|
pub fn NativeWebViewLaunchPacket::title(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.title
}

///|
pub fn NativeWebViewLaunchPacket::title_text(
  self : NativeWebViewLaunchPacket,
) -> String {
  @utf8.decode(self.title) catch {
    _ => ""
  }
}

///|
pub fn NativeWebViewLaunchPacket::load_url(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.load_url
}

///|
pub fn NativeWebViewLaunchPacket::load_url_text(
  self : NativeWebViewLaunchPacket,
) -> String {
  @utf8.decode(self.load_url) catch {
    _ => ""
  }
}

///|
pub fn NativeWebViewLaunchPacket::initialization_script(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.initialization_script
}

///|
pub fn NativeWebViewLaunchPacket::initialization_script_text(
  self : NativeWebViewLaunchPacket,
) -> String {
  @utf8.decode(self.initialization_script) catch {
    _ => ""
  }
}

///|
pub fn NativeWebViewLaunchPacket::native_hook(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.native_hook
}

///|
pub fn NativeWebViewLaunchPacket::native_hook_text(
  self : NativeWebViewLaunchPacket,
) -> String {
  @utf8.decode(self.native_hook) catch {
    _ => ""
  }
}

///|
pub fn NativeWebViewLaunchPacket::asset_protocol(
  self : NativeWebViewLaunchPacket,
) -> Bytes {
  self.asset_protocol
}

///|
pub fn NativeWebViewLaunchPacket::asset_protocol_text(
  self : NativeWebViewLaunchPacket,
) -> String {
  @utf8.decode(self.asset_protocol) catch {
    _ => ""
  }
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
