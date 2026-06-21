///|
pub type StreamCommandHandler = (String, StreamSink) -> Result[Unit, String]

///|
pub struct StreamSink {
  route : String
  channel_id : String
  channels : ChannelTable
}

///|
fn StreamSink::new(
  route~ : String,
  channel_id~ : String,
  channels~ : ChannelTable,
) -> StreamSink {
  { route, channel_id, channels }
}

///|
pub fn StreamSink::route(self : StreamSink) -> String {
  self.route
}

///|
pub fn StreamSink::channel_id(self : StreamSink) -> String {
  self.channel_id
}

///|
pub fn StreamSink::channel(self : StreamSink) -> Channel? {
  self.channels.get(self.channel_id)
}

///|
pub fn StreamSink::handle(self : StreamSink) -> ResourceHandle? {
  match self.channel() {
    Some(channel) => Some(channel.resource().handle())
    None => None
  }
}

///|
pub fn StreamSink::closed(self : StreamSink) -> Bool {
  match self.channel() {
    Some(channel) => channel.closed() || channel.cancelled()
    None => true
  }
}

///|
pub fn StreamSink::send(
  self : StreamSink,
  payload : String,
) -> Result[ChannelMessage, String] {
  self.channels.send(self.channel_id, payload)
}

///|
pub fn StreamSink::fail(
  self : StreamSink,
  message : String,
) -> Result[ChannelMessage, String] {
  self.channels.fail(self.channel_id, message)
}

///|
pub fn StreamSink::end(self : StreamSink) -> Result[ChannelMessage, String] {
  self.channels.end(self.channel_id)
}

///|
pub fn StreamSink::cancel(self : StreamSink) -> Result[ChannelMessage, String] {
  self.channels.cancel(self.channel_id)
}

///|
pub fn StreamSink::to_json(self : StreamSink) -> String {
  [
    "{",
    "\"route\":\{self.route.json_string()},",
    "\"channelId\":\{self.channel_id.json_string()},",
    "\"handle\":\{stream_sink_handle_json(self)}",
    "}",
  ].join("")
}

///|
fn stream_sink_handle_json(sink : StreamSink) -> String {
  match sink.handle() {
    Some(handle) => handle.to_json()
    None => "null"
  }
}

///|
fn stream_response_payload(route : String, sink : StreamSink) -> String {
  [
    "{",
    "\"kind\":\"stream\",",
    "\"route\":\{route.json_string()},",
    "\"channelId\":\{sink.channel_id().json_string()},",
    "\"channel\":\{stream_sink_handle_json(sink)}",
    "}",
  ].join("")
}
