///|
test "store plugin declares commands and capability" {
  let declared = plugin()
  assert_eq(declared.name(), "store")
  assert_eq(declared.command_routes().length(), 5)
  assert_true(declared.command_routes().contains("store.get"))
  assert_true(declared.command_routes().contains("store.set"))
  assert_true(declared.command_routes().contains("store.delete"))
  assert_true(declared.command_routes().contains("store.clear"))
  assert_true(declared.command_routes().contains("store.keys"))
  let grant = capability_for_window("main")
  let registry = registry()
  assert_true(registry.contains("store.get"))
  let denied = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="other",
      plugin="store",
      command="get",
      payload="{\"key\":\"theme\"}",
    ),
    capabilities=[grant],
  )
  assert_true(denied is InvokeError("1", "permission denied: store.get"))
}

///|
test "store registry handles set get delete and keys" {
  let store = Store::new()
  let registry = registry(store~)
  let grant = capability_for_window("main")
  let set = registry.dispatch(
    request(command="set", payload="{\"key\":\"theme\",\"value\":\"dark\"}"),
    capabilities=[grant],
  )
  assert_true(set is InvokeOk("1", _))
  assert_eq(store.get("theme").unwrap_or(""), "dark")
  let get = registry.dispatch(
    request(command="get", payload="{\"key\":\"theme\"}"),
    capabilities=[grant],
  )
  assert_true(get is InvokeOk("1", _))
  assert_true(get.payload().unwrap_or("").contains("\"found\":true"))
  assert_true(get.payload().unwrap_or("").contains("\"value\":\"dark\""))
  ignore(
    registry.dispatch(
      request(command="set", payload="{\"key\":\"layout\",\"value\":\"wide\"}"),
      capabilities=[grant],
    ),
  )
  let keys = registry.dispatch(request(command="keys"), capabilities=[grant])
  assert_true(keys is InvokeOk("1", _))
  assert_true(keys.payload().unwrap_or("").contains("\"layout\""))
  assert_true(keys.payload().unwrap_or("").contains("\"theme\""))
  let deleted = registry.dispatch(
    request(command="delete", payload="\"theme\""),
    capabilities=[grant],
  )
  assert_true(deleted is InvokeOk("1", _))
  assert_true(deleted.payload().unwrap_or("").contains("\"deleted\":true"))
  assert_true(store.get("theme") is None)
  let clear = registry.dispatch(request(command="clear"), capabilities=[grant])
  assert_true(clear is InvokeOk("1", _))
  assert_true(clear.payload().unwrap_or("").contains("\"cleared\":1"))
  assert_eq(store.keys().length(), 0)
}

///|
test "store registry reports missing values and invalid payloads" {
  let registry = registry()
  let grant = capability()
  let missing = registry.dispatch(
    request(command="get", payload="{\"key\":\"missing\"}"),
    capabilities=[grant],
  )
  assert_true(missing is InvokeOk("1", _))
  assert_true(missing.payload().unwrap_or("").contains("\"found\":false"))
  let invalid = registry.dispatch(
    request(command="set", payload="{\"key\":\"\"}"),
    capabilities=[grant],
  )
  assert_true(invalid is InvokeError("1", "store key is required"))
}

///|
fn request(command~ : String, payload? : String = "") -> @lepusa.InvokeRequest {
  @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="store",
    command~,
    payload~,
  )
}
