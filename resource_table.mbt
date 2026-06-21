///|
pub struct ResourceDescriptor {
  kind : String
  owner : String
  name : String
  metadata : String
} derive(Debug, Eq)

///|
pub fn ResourceDescriptor::new(
  kind~ : String,
  owner? : String = "",
  name? : String = "",
  metadata? : String = "",
) -> ResourceDescriptor {
  { kind, owner, name, metadata }
}

///|
pub fn ResourceDescriptor::kind(self : ResourceDescriptor) -> String {
  self.kind
}

///|
pub fn ResourceDescriptor::owner(self : ResourceDescriptor) -> String {
  self.owner
}

///|
pub fn ResourceDescriptor::name(self : ResourceDescriptor) -> String {
  self.name
}

///|
pub fn ResourceDescriptor::metadata(self : ResourceDescriptor) -> String {
  self.metadata
}

///|
pub fn ResourceDescriptor::validate(self : ResourceDescriptor) -> Array[String] {
  let problems : Array[String] = []
  if self.kind == "" {
    problems.push("resource kind is required")
  }
  problems
}

///|
pub fn ResourceDescriptor::to_json(self : ResourceDescriptor) -> String {
  [
    "{",
    "\"kind\":\{self.kind.json_string()},",
    "\"owner\":\{self.owner.json_string()},",
    "\"name\":\{self.name.json_string()},",
    "\"metadata\":\{self.metadata.json_string()}",
    "}",
  ].join("")
}

///|
pub struct ResourceHandle {
  id : String
  kind : String
  owner : String
  name : String
} derive(Debug, Eq)

///|
pub fn ResourceHandle::new(
  id~ : String,
  kind~ : String,
  owner? : String = "",
  name? : String = "",
) -> ResourceHandle {
  { id, kind, owner, name }
}

///|
pub fn ResourceHandle::from_entry(entry : ResourceEntry) -> ResourceHandle {
  ResourceHandle::new(
    id=entry.id(),
    kind=entry.kind(),
    owner=entry.owner(),
    name=entry.name(),
  )
}

///|
pub fn ResourceHandle::id(self : ResourceHandle) -> String {
  self.id
}

///|
pub fn ResourceHandle::kind(self : ResourceHandle) -> String {
  self.kind
}

///|
pub fn ResourceHandle::owner(self : ResourceHandle) -> String {
  self.owner
}

///|
pub fn ResourceHandle::name(self : ResourceHandle) -> String {
  self.name
}

///|
pub fn ResourceHandle::validate(self : ResourceHandle) -> Array[String] {
  let problems : Array[String] = []
  if self.id == "" {
    problems.push("resource handle id is required")
  }
  if self.kind == "" {
    problems.push("resource handle kind is required")
  }
  problems
}

///|
pub fn ResourceHandle::to_json(self : ResourceHandle) -> String {
  [
    "{",
    "\"id\":\{self.id.json_string()},",
    "\"kind\":\{self.kind.json_string()},",
    "\"owner\":\{self.owner.json_string()},",
    "\"name\":\{self.name.json_string()}",
    "}",
  ].join("")
}

///|
pub struct ResourceEntry {
  id : String
  sequence : Int
  kind : String
  owner : String
  name : String
  metadata : String
  closed : Bool
} derive(Debug, Eq)

///|
fn ResourceEntry::new(
  id~ : String,
  sequence~ : Int,
  descriptor : ResourceDescriptor,
) -> ResourceEntry {
  {
    id,
    sequence,
    kind: descriptor.kind(),
    owner: descriptor.owner(),
    name: descriptor.name(),
    metadata: descriptor.metadata(),
    closed: false,
  }
}

///|
pub fn ResourceEntry::id(self : ResourceEntry) -> String {
  self.id
}

///|
pub fn ResourceEntry::sequence(self : ResourceEntry) -> Int {
  self.sequence
}

///|
pub fn ResourceEntry::kind(self : ResourceEntry) -> String {
  self.kind
}

///|
pub fn ResourceEntry::owner(self : ResourceEntry) -> String {
  self.owner
}

///|
pub fn ResourceEntry::name(self : ResourceEntry) -> String {
  self.name
}

///|
pub fn ResourceEntry::metadata(self : ResourceEntry) -> String {
  self.metadata
}

///|
pub fn ResourceEntry::closed(self : ResourceEntry) -> Bool {
  self.closed
}

///|
pub fn ResourceEntry::descriptor(self : ResourceEntry) -> ResourceDescriptor {
  ResourceDescriptor::new(
    kind=self.kind,
    owner=self.owner,
    name=self.name,
    metadata=self.metadata,
  )
}

///|
pub fn ResourceEntry::handle(self : ResourceEntry) -> ResourceHandle {
  ResourceHandle::from_entry(self)
}

///|
pub fn ResourceEntry::to_json(self : ResourceEntry) -> String {
  [
    "{",
    "\"id\":\{self.id.json_string()},",
    "\"sequence\":\{self.sequence},",
    "\"kind\":\{self.kind.json_string()},",
    "\"owner\":\{self.owner.json_string()},",
    "\"name\":\{self.name.json_string()},",
    "\"metadata\":\{self.metadata.json_string()},",
    "\"closed\":\{resource_bool_json(self.closed)}",
    "}",
  ].join("")
}

///|
fn ResourceEntry::as_closed(self : ResourceEntry) -> ResourceEntry {
  { ..self, closed: true }
}

///|
pub struct ResourceTable {
  mut next_sequence : Int
  id_prefix : String
  entries : Map[String, ResourceEntry]
  order : Array[String]
}

///|
pub fn ResourceTable::new() -> ResourceTable {
  ResourceTable::with_prefix("resource")
}

///|
pub fn ResourceTable::with_prefix(id_prefix : String) -> ResourceTable {
  let id_prefix = if id_prefix == "" { "resource" } else { id_prefix }
  { next_sequence: 1, id_prefix, entries: {}, order: [] }
}

///|
pub fn ResourceTable::id_prefix(self : ResourceTable) -> String {
  self.id_prefix
}

///|
pub fn ResourceTable::open(
  self : ResourceTable,
  descriptor : ResourceDescriptor,
) -> Result[ResourceEntry, Array[String]] {
  let problems = descriptor.validate()
  if !problems.is_empty() {
    return Err(problems)
  }
  let sequence = self.next_sequence
  self.next_sequence += 1
  let id = "\{self.id_prefix}-\{sequence}"
  let entry = ResourceEntry::new(id~, sequence~, descriptor)
  self.entries[id] = entry
  self.order.push(id)
  Ok(entry)
}

///|
pub fn ResourceTable::get(self : ResourceTable, id : String) -> ResourceEntry? {
  self.entries.get(id)
}

///|
pub fn ResourceTable::handle(
  self : ResourceTable,
  id : String,
) -> ResourceHandle? {
  match self.get(id) {
    Some(entry) => Some(entry.handle())
    None => None
  }
}

///|
pub fn ResourceTable::handles(self : ResourceTable) -> Array[ResourceHandle] {
  self.entries().map(fn(entry) { entry.handle() })
}

///|
pub fn ResourceTable::handles_by_kind(
  self : ResourceTable,
  kind : String,
) -> Array[ResourceHandle] {
  self.entries_by_kind(kind).map(fn(entry) { entry.handle() })
}

///|
pub fn ResourceTable::handles_by_owner(
  self : ResourceTable,
  owner : String,
) -> Array[ResourceHandle] {
  self.entries_by_owner(owner).map(fn(entry) { entry.handle() })
}

///|
pub fn ResourceTable::contains(self : ResourceTable, id : String) -> Bool {
  self.entries.contains(id)
}

///|
pub fn ResourceTable::count(self : ResourceTable) -> Int {
  self.entries.length()
}

///|
pub fn ResourceTable::is_empty(self : ResourceTable) -> Bool {
  self.entries.is_empty()
}

///|
pub fn ResourceTable::ids(self : ResourceTable) -> Array[String] {
  self.order.copy()
}

///|
pub fn ResourceTable::entries(self : ResourceTable) -> Array[ResourceEntry] {
  let entries : Array[ResourceEntry] = []
  for id in self.order {
    match self.entries.get(id) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
pub fn ResourceTable::entries_by_kind(
  self : ResourceTable,
  kind : String,
) -> Array[ResourceEntry] {
  self.entries().filter(fn(entry) { entry.kind() == kind })
}

///|
pub fn ResourceTable::entries_by_owner(
  self : ResourceTable,
  owner : String,
) -> Array[ResourceEntry] {
  self.entries().filter(fn(entry) { entry.owner() == owner })
}

///|
pub fn ResourceTable::close(
  self : ResourceTable,
  id : String,
) -> Result[ResourceEntry, String] {
  match self.entries.get(id) {
    Some(entry) => {
      self.entries.remove(id)
      self.remove_ordered_id(id)
      Ok(entry.as_closed())
    }
    None => Err("resource not found: \{id}")
  }
}

///|
pub fn ResourceTable::close_handle(
  self : ResourceTable,
  handle : ResourceHandle,
) -> Result[ResourceEntry, String] {
  let problems = handle.validate()
  if !problems.is_empty() {
    return Err(problems[0])
  }
  match self.get(handle.id()) {
    Some(entry) =>
      if entry.kind() != handle.kind() {
        Err(
          "resource kind mismatch for \{handle.id()}: expected \{handle.kind()} got \{entry.kind()}",
        )
      } else {
        self.close(handle.id())
      }
    None => Err("resource not found: \{handle.id()}")
  }
}

///|
pub fn ResourceTable::close_kind(
  self : ResourceTable,
  kind : String,
) -> Array[ResourceEntry] {
  let entries = self.entries_by_kind(kind)
  self.close_entries(entries)
}

///|
pub fn ResourceTable::close_owner(
  self : ResourceTable,
  owner : String,
) -> Array[ResourceEntry] {
  let entries = self.entries_by_owner(owner)
  self.close_entries(entries)
}

///|
pub fn ResourceTable::close_all(self : ResourceTable) -> Array[ResourceEntry] {
  let entries = self.entries()
  self.close_entries(entries)
}

///|
pub fn ResourceTable::leak_report(self : ResourceTable) -> ResourceLeakReport {
  ResourceLeakReport::new(resources=self.entries())
}

///|
pub fn ResourceTable::cleanup_report(
  self : ResourceTable,
) -> ResourceCleanupReport {
  let closed = self.close_all()
  ResourceCleanupReport::new(closed~, remaining=self.entries())
}

///|
pub fn ResourceTable::to_json(self : ResourceTable) -> String {
  [
    "{",
    "\"idPrefix\":\{self.id_prefix.json_string()},",
    "\"nextSequence\":\{self.next_sequence},",
    "\"resources\":[\{self.entries().map(fn(entry) { entry.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn ResourceTable::close_entries(
  self : ResourceTable,
  entries : Array[ResourceEntry],
) -> Array[ResourceEntry] {
  let closed : Array[ResourceEntry] = []
  for entry in entries {
    self.entries.remove(entry.id())
    self.remove_ordered_id(entry.id())
    closed.push(entry.as_closed())
  }
  closed
}

///|
fn ResourceTable::remove_ordered_id(self : ResourceTable, id : String) -> Unit {
  match self.order.search(id) {
    Some(index) => ignore(self.order.remove(index))
    None => ()
  }
}

///|
fn resource_bool_json(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}
