# Lepusa Store Plugin

`vectie/lepusa/plugins/store` provides scoped key-value commands backed by a
MoonBit `Store`.

```mbt check
///|
test "store plugin usage" {
  let store = Store::new()
  let registry = registry(store~)
  let grant = capability_for_window("main")
  let set = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="store",
      command="set",
      payload="{\"key\":\"theme\",\"value\":\"dark\"}",
    ),
    capabilities=[grant],
  )
  assert_true(set is InvokeOk("1", _))
  assert_eq(store.get("theme").unwrap_or(""), "dark")
}
```
