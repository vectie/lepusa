///|
pub(all) enum ChannelMessageKind {
  ChannelData
  ChannelError
  ChannelEnd
  ChannelCancel
} derive(Debug, Eq)

///|
pub fn ChannelMessageKind::name(self : ChannelMessageKind) -> String {
  match self {
    ChannelData => "data"
    ChannelError => "error"
    ChannelEnd => "end"
    ChannelCancel => "cancel"
  }
}

///|
pub struct ChannelMessage {
  channel_id : String
  sequence : Int
  kind : ChannelMessageKind
  payload : String
} derive(Debug, Eq)

///|
fn ChannelMessage::new(
  channel_id~ : String,
  sequence~ : Int,
  kind~ : ChannelMessageKind,
  payload? : String = "",
) -> ChannelMessage {
  { channel_id, sequence, kind, payload }
}

///|
pub fn ChannelMessage::channel_id(self : ChannelMessage) -> String {
  self.channel_id
}

///|
pub fn ChannelMessage::sequence(self : ChannelMessage) -> Int {
  self.sequence
}

///|
pub fn ChannelMessage::kind(self : ChannelMessage) -> ChannelMessageKind {
  self.kind
}

///|
pub fn ChannelMessage::payload(self : ChannelMessage) -> String {
  self.payload
}

///|
pub fn ChannelMessage::to_json(self : ChannelMessage) -> String {
  [
    "{",
    "\"channelId\":\{self.channel_id.json_string()},",
    "\"sequence\":\{self.sequence},",
    "\"kind\":\{self.kind.name().json_string()},",
    "\"payload\":\{self.payload.json_string()}",
    "}",
  ].join("")
}

///|
pub struct Channel {
  resource : ResourceEntry
  mut next_sequence : Int
  messages : Array[ChannelMessage]
  closed : Bool
  cancelled : Bool
} derive(Debug, Eq)

///|
fn Channel::new(resource : ResourceEntry) -> Channel {
  { resource, next_sequence: 1, messages: [], closed: false, cancelled: false }
}

///|
pub fn Channel::id(self : Channel) -> String {
  self.resource.id()
}

///|
pub fn Channel::resource(self : Channel) -> ResourceEntry {
  self.resource
}

///|
pub fn Channel::closed(self : Channel) -> Bool {
  self.closed
}

///|
pub fn Channel::cancelled(self : Channel) -> Bool {
  self.cancelled
}

///|
pub fn Channel::pending_count(self : Channel) -> Int {
  self.messages.length()
}

///|
pub fn Channel::to_json(self : Channel) -> String {
  [
    "{",
    "\"resource\":\{self.resource.to_json()},",
    "\"nextSequence\":\{self.next_sequence},",
    "\"closed\":\{channel_bool_json(self.closed)},",
    "\"cancelled\":\{channel_bool_json(self.cancelled)},",
    "\"messages\":[\{self.messages.map(fn(message) { message.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub struct ChannelTable {
  resources : ResourceTable
  channels : Map[String, Channel]
  order : Array[String]
}

///|
pub fn ChannelTable::new() -> ChannelTable {
  { resources: ResourceTable::with_prefix("channel"), channels: {}, order: [] }
}

///|
pub fn ChannelTable::open(
  self : ChannelTable,
  owner? : String = "",
  name? : String = "",
  metadata? : String = "",
) -> Result[Channel, Array[String]] {
  match
    self.resources.open(
      ResourceDescriptor::new(kind="channel", owner~, name~, metadata~),
    ) {
    Ok(resource) => {
      let channel = Channel::new(resource)
      self.channels[channel.id()] = channel
      self.order.push(channel.id())
      Ok(channel)
    }
    Err(problems) => Err(problems)
  }
}

///|
pub fn ChannelTable::get(self : ChannelTable, id : String) -> Channel? {
  self.channels.get(id)
}

///|
pub fn ChannelTable::contains(self : ChannelTable, id : String) -> Bool {
  self.channels.contains(id)
}

///|
pub fn ChannelTable::count(self : ChannelTable) -> Int {
  self.channels.length()
}

///|
pub fn ChannelTable::ids(self : ChannelTable) -> Array[String] {
  self.order.copy()
}

///|
pub fn ChannelTable::channels(self : ChannelTable) -> Array[Channel] {
  let channels : Array[Channel] = []
  for id in self.order {
    match self.channels.get(id) {
      Some(channel) => channels.push(channel)
      None => ()
    }
  }
  channels
}

///|
pub fn ChannelTable::resource_entries(
  self : ChannelTable,
) -> Array[ResourceEntry] {
  self.resources.entries()
}

///|
pub fn ChannelTable::send(
  self : ChannelTable,
  id : String,
  payload : String,
) -> Result[ChannelMessage, String] {
  self.emit(id, ChannelData, payload)
}

///|
pub fn ChannelTable::fail(
  self : ChannelTable,
  id : String,
  message : String,
) -> Result[ChannelMessage, String] {
  self.emit(id, ChannelError, message)
}

///|
pub fn ChannelTable::end(
  self : ChannelTable,
  id : String,
) -> Result[ChannelMessage, String] {
  self.emit_terminal(id, ChannelEnd, "")
}

///|
pub fn ChannelTable::cancel(
  self : ChannelTable,
  id : String,
) -> Result[ChannelMessage, String] {
  self.emit_terminal(id, ChannelCancel, "")
}

///|
pub fn ChannelTable::drain(
  self : ChannelTable,
  id : String,
) -> Result[Array[ChannelMessage], String] {
  match self.channels.get(id) {
    Some(channel) => {
      let messages = channel.messages.copy()
      channel.messages.clear()
      self.channels[id] = channel
      Ok(messages)
    }
    None => Err("channel not found: \{id}")
  }
}

///|
pub fn ChannelTable::close(
  self : ChannelTable,
  id : String,
) -> Result[ResourceEntry, String] {
  match self.resources.close(id) {
    Ok(resource) => {
      self.channels.remove(id)
      self.remove_ordered_id(id)
      Ok(resource)
    }
    Err(_) => Err("channel not found: \{id}")
  }
}

///|
pub fn ChannelTable::close_all(self : ChannelTable) -> Array[ResourceEntry] {
  self.channels.clear()
  self.order.clear()
  self.resources.close_all()
}

///|
pub fn ChannelTable::to_json(self : ChannelTable) -> String {
  [
    "{",
    "\"channels\":[\{self.channels().map(fn(channel) { channel.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn ChannelTable::emit(
  self : ChannelTable,
  id : String,
  kind : ChannelMessageKind,
  payload : String,
) -> Result[ChannelMessage, String] {
  match self.channels.get(id) {
    Some(channel) =>
      if channel.closed() || channel.cancelled() {
        Err("channel is closed: \{id}")
      } else {
        let message = channel.next_message(kind, payload)
        channel.messages.push(message)
        self.channels[id] = channel
        Ok(message)
      }
    None => Err("channel not found: \{id}")
  }
}

///|
fn ChannelTable::emit_terminal(
  self : ChannelTable,
  id : String,
  kind : ChannelMessageKind,
  payload : String,
) -> Result[ChannelMessage, String] {
  match self.channels.get(id) {
    Some(channel) =>
      if channel.closed() || channel.cancelled() {
        Err("channel is closed: \{id}")
      } else {
        let message = channel.next_message(kind, payload)
        channel.messages.push(message)
        let terminal = match kind {
          ChannelCancel => { ..channel, cancelled: true }
          _ => { ..channel, closed: true }
        }
        self.channels[id] = terminal
        Ok(message)
      }
    None => Err("channel not found: \{id}")
  }
}

///|
fn Channel::next_message(
  self : Channel,
  kind : ChannelMessageKind,
  payload : String,
) -> ChannelMessage {
  let sequence = self.next_sequence
  self.next_sequence += 1
  ChannelMessage::new(channel_id=self.id(), sequence~, kind~, payload~)
}

///|
fn ChannelTable::remove_ordered_id(self : ChannelTable, id : String) -> Unit {
  match self.order.search(id) {
    Some(index) => ignore(self.order.remove(index))
    None => ()
  }
}

///|
fn channel_bool_json(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}
