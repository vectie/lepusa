///|
pub struct AppStateEntry {
  key : String
  kind : String
  value : String
} derive(Debug, Eq)

///|
pub fn AppStateEntry::new(
  key~ : String,
  kind? : String = "",
  value? : String = "",
) -> AppStateEntry {
  { key, kind, value }
}

///|
pub fn AppStateEntry::key(self : AppStateEntry) -> String {
  self.key
}

///|
pub fn AppStateEntry::kind(self : AppStateEntry) -> String {
  self.kind
}

///|
pub fn AppStateEntry::value(self : AppStateEntry) -> String {
  self.value
}

///|
pub fn AppStateEntry::validate(self : AppStateEntry) -> Array[String] {
  let problems : Array[String] = []
  if self.key == "" {
    problems.push("app state key is required")
  }
  problems
}

///|
pub fn AppStateEntry::to_json(self : AppStateEntry) -> String {
  [
    "{",
    "\"key\":\{self.key.json_string()},",
    "\"kind\":\{self.kind.json_string()},",
    "\"value\":\{self.value.json_string()}",
    "}",
  ].join("")
}

///|
pub struct AppStateStore {
  entries : Map[String, AppStateEntry]
  order : Array[String]
}

///|
pub fn AppStateStore::new() -> AppStateStore {
  { entries: {}, order: [] }
}

///|
pub fn AppStateStore::put(
  self : AppStateStore,
  entry : AppStateEntry,
) -> Result[AppStateEntry, Array[String]] {
  let problems = entry.validate()
  if !problems.is_empty() {
    return Err(problems)
  }
  let key = entry.key()
  if !self.entries.contains(key) {
    self.order.push(key)
  }
  self.entries[key] = entry
  Ok(entry)
}

///|
pub fn AppStateStore::set(
  self : AppStateStore,
  key : String,
  kind? : String = "",
  value? : String = "",
) -> Result[AppStateEntry, Array[String]] {
  self.put(AppStateEntry::new(key~, kind~, value~))
}

///|
pub fn AppStateStore::get(self : AppStateStore, key : String) -> AppStateEntry? {
  self.entries.get(key)
}

///|
pub fn AppStateStore::contains(self : AppStateStore, key : String) -> Bool {
  self.entries.contains(key)
}

///|
pub fn AppStateStore::count(self : AppStateStore) -> Int {
  self.entries.length()
}

///|
pub fn AppStateStore::is_empty(self : AppStateStore) -> Bool {
  self.entries.is_empty()
}

///|
pub fn AppStateStore::keys(self : AppStateStore) -> Array[String] {
  self.order.copy()
}

///|
pub fn AppStateStore::entries(self : AppStateStore) -> Array[AppStateEntry] {
  let entries : Array[AppStateEntry] = []
  for key in self.order {
    match self.entries.get(key) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
pub fn AppStateStore::remove(
  self : AppStateStore,
  key : String,
) -> Result[AppStateEntry, String] {
  match self.entries.get(key) {
    Some(entry) => {
      self.entries.remove(key)
      self.remove_ordered_key(key)
      Ok(entry)
    }
    None => Err("app state not found: \{key}")
  }
}

///|
pub fn AppStateStore::clear(self : AppStateStore) -> Array[AppStateEntry] {
  let entries = self.entries()
  self.entries.clear()
  self.order.clear()
  entries
}

///|
pub fn AppStateStore::to_json(self : AppStateStore) -> String {
  [
    "{",
    "\"entries\":[\{self.entries().map(fn(entry) { entry.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn AppStateStore::remove_ordered_key(
  self : AppStateStore,
  key : String,
) -> Unit {
  match self.order.search(key) {
    Some(index) => ignore(self.order.remove(index))
    None => ()
  }
}

///|
pub struct AppManager {
  plan : RuntimePlan
  registry : CommandRegistry
  resources : ResourceTable
  channels : ChannelTable
  events : EventBus
  state : AppStateStore
}

///|
pub fn AppManager::new(
  plan : RuntimePlan,
  registry? : CommandRegistry = CommandRegistry::new(),
) -> AppManager {
  {
    plan,
    registry,
    resources: ResourceTable::new(),
    channels: ChannelTable::new(),
    events: EventBus::new(),
    state: AppStateStore::new(),
  }
}

///|
pub fn App::manager(
  self : App,
  config? : RuntimeConfig = RuntimeConfig::system_webview(),
  registry? : CommandRegistry = CommandRegistry::new(),
) -> Result[AppManager, Array[String]] {
  match self.runtime_plan(config~) {
    Ok(plan) => Ok(AppManager::new(plan, registry~))
    Err(problems) => Err(problems)
  }
}

///|
pub fn AppManager::plan(self : AppManager) -> RuntimePlan {
  self.plan
}

///|
pub fn AppManager::registry(self : AppManager) -> CommandRegistry {
  self.registry
}

///|
pub fn AppManager::command_routes(self : AppManager) -> Array[String] {
  self.plan.command_routes()
}

///|
pub fn AppManager::registered_routes(self : AppManager) -> Array[String] {
  self.registry.routes()
}

///|
pub fn AppManager::window_count(self : AppManager) -> Int {
  self.plan.window_count()
}

///|
pub fn AppManager::plugin_count(self : AppManager) -> Int {
  self.plan.plugin_count()
}

///|
pub fn AppManager::capability_count(self : AppManager) -> Int {
  self.plan.capability_count()
}

///|
pub fn AppManager::resource_count(self : AppManager) -> Int {
  self.resources.count() + self.channels.count()
}

///|
pub fn AppManager::channel_count(self : AppManager) -> Int {
  self.channels.count()
}

///|
pub fn AppManager::listener_count(self : AppManager) -> Int {
  self.events.listener_count()
}

///|
pub fn AppManager::state_count(self : AppManager) -> Int {
  self.state.count()
}

///|
pub fn AppManager::resources(self : AppManager) -> Array[ResourceEntry] {
  let entries = self.resources.entries()
  for channel in self.channels.resource_entries() {
    entries.push(channel)
  }
  entries
}

///|
pub fn AppManager::resource(self : AppManager, id : String) -> ResourceEntry? {
  match self.resources.get(id) {
    Some(entry) => Some(entry)
    None =>
      match self.channels.get(id) {
        Some(channel) => Some(channel.resource())
        None => None
      }
  }
}

///|
pub fn AppManager::open_resource(
  self : AppManager,
  descriptor : ResourceDescriptor,
) -> Result[ResourceEntry, Array[String]] {
  self.resources.open(descriptor)
}

///|
pub fn AppManager::close_resource(
  self : AppManager,
  id : String,
) -> Result[ResourceEntry, String] {
  if self.channels.contains(id) {
    self.channels.close(id)
  } else {
    self.resources.close(id)
  }
}

///|
pub fn AppManager::open_channel(
  self : AppManager,
  owner? : String = "",
  name? : String = "",
  metadata? : String = "",
) -> Result[Channel, Array[String]] {
  self.channels.open(owner~, name~, metadata~)
}

///|
pub fn AppManager::channel(self : AppManager, id : String) -> Channel? {
  self.channels.get(id)
}

///|
pub fn AppManager::send_channel(
  self : AppManager,
  id : String,
  payload : String,
) -> Result[ChannelMessage, String] {
  self.channels.send(id, payload)
}

///|
pub fn AppManager::fail_channel(
  self : AppManager,
  id : String,
  message : String,
) -> Result[ChannelMessage, String] {
  self.channels.fail(id, message)
}

///|
pub fn AppManager::end_channel(
  self : AppManager,
  id : String,
) -> Result[ChannelMessage, String] {
  self.channels.end(id)
}

///|
pub fn AppManager::cancel_channel(
  self : AppManager,
  id : String,
) -> Result[ChannelMessage, String] {
  self.channels.cancel(id)
}

///|
pub fn AppManager::drain_channel(
  self : AppManager,
  id : String,
) -> Result[Array[ChannelMessage], String] {
  self.channels.drain(id)
}

///|
pub fn AppManager::listen(
  self : AppManager,
  name : String,
  target? : EventTarget = AppTarget,
  once? : Bool = false,
) -> Result[EventListener, Array[String]] {
  self.events.listen(name, target~, once~)
}

///|
pub fn AppManager::once(
  self : AppManager,
  name : String,
  target? : EventTarget = AppTarget,
) -> Result[EventListener, Array[String]] {
  self.events.once(name, target~)
}

///|
pub fn AppManager::emit(
  self : AppManager,
  event : Event,
  target? : EventTarget = AppTarget,
) -> Result[Array[EventDelivery], Array[String]] {
  self.events.emit(event, target~)
}

///|
pub fn AppManager::unlisten(
  self : AppManager,
  id : String,
) -> Result[EventListener, String] {
  self.events.unlisten(id)
}

///|
pub fn AppManager::manage_state(
  self : AppManager,
  key : String,
  kind? : String = "",
  value? : String = "",
) -> Result[AppStateEntry, Array[String]] {
  self.state.set(key, kind~, value~)
}

///|
pub fn AppManager::state(self : AppManager, key : String) -> AppStateEntry? {
  self.state.get(key)
}

///|
pub fn AppManager::remove_state(
  self : AppManager,
  key : String,
) -> Result[AppStateEntry, String] {
  self.state.remove(key)
}

///|
pub fn AppManager::dispatch(
  self : AppManager,
  request : InvokeRequest,
) -> InvokeResponse {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return InvokeResponse::invalid_request(request.id(), request_problems[0])
  }
  let route = request.route()
  match self.plan.command_permission(route) {
    None => InvokeResponse::unknown_command(request.id(), route)
    Some(permission) =>
      self.registry.dispatch_with_permission(
        request,
        permission~,
        capabilities=self.plan.capabilities(),
      )
  }
}

///|
pub async fn AppManager::dispatch_async(
  self : AppManager,
  request : InvokeRequest,
) -> InvokeResponse {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return InvokeResponse::invalid_request(request.id(), request_problems[0])
  }
  let route = request.route()
  match self.plan.command_permission(route) {
    None => InvokeResponse::unknown_command(request.id(), route)
    Some(permission) =>
      self.registry.dispatch_with_permission_async(
        request,
        permission~,
        capabilities=self.plan.capabilities(),
      )
  }
}

///|
pub fn AppManager::to_json(self : AppManager) -> String {
  [
    "{",
    "\"backend\":\{self.plan.backend().name().json_string()},",
    "\"assetProtocol\":\{self.plan.asset_protocol().json_string()},",
    "\"windows\":\{self.window_count()},",
    "\"plugins\":\{self.plugin_count()},",
    "\"capabilities\":\{self.capability_count()},",
    "\"commands\":[\{self.command_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"registeredCommands\":[\{self.registered_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"resources\":[\{self.resources().map(fn(entry) { entry.to_json() }).join(",")}],",
    "\"channels\":\{self.channels.to_json()},",
    "\"events\":\{self.events.to_json()},",
    "\"state\":\{self.state.to_json()}",
    "}",
  ].join("")
}
