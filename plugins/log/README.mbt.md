# Lepusa Log Plugin

`vectie/lepusa/plugins/log` provides the first official plugin shape:
declaration, scoped capability helpers, and command registry wiring.

```mbt check
///|
test "log plugin usage" {
  let buffer = @log.LogBuffer::new()
  let registry = @log.registry(buffer~)
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="log",
      command="write",
      payload="{\"message\":\"ready\"}",
    ),
    capabilities=[@log.capability_for_window("main")],
  )
  assert_true(response is InvokeOk("1", _))
  assert_eq(buffer.entries()[0].message(), "ready")
}
```
