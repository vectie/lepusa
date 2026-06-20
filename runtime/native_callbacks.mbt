///|
pub fn NativeRuntime::bridge_dispatch_callback(
  self : NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(message : Bytes) { self.dispatch_bridge_script_bytes(message) }
}

///|
pub fn NativeRuntime::asset_protocol_resolver_callback(
  self : NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) { self.resolve_asset_protocol_packet_bytes(url) }
}
