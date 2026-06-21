///|
test "log plugin declares command and capability" {
  let declared = plugin()
  assert_eq(declared.name(), "log")
  assert_eq(declared.command_routes()[0], "log.write")
  let grant = capability_for_window("main")
  let registry = registry()
  assert_true(registry.contains("log.write"))
  let denied = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="other",
      plugin="log",
      command="write",
      payload="{\"message\":\"hello\"}",
    ),
    capabilities=[grant],
  )
  assert_eq(
    denied.error_message().unwrap_or(""),
    "permission denied: log.write",
  )
}

///|
test "log registry writes payloads into buffer" {
  let buffer = LogBuffer::new()
  let registry = registry(buffer~)
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="log",
      command="write",
      payload="{\"level\":\"warn\",\"message\":\"careful\",\"target\":\"main\"}",
    ),
    capabilities=[capability_for_window("main")],
  )
  assert_true(response is InvokeOk("1", _))
  assert_eq(buffer.entries().length(), 1)
  assert_eq(buffer.entries()[0].level(), "warn")
  assert_eq(buffer.entries()[0].message(), "careful")
  assert_eq(buffer.entries()[0].target(), "main")
  assert_true(
    response.payload().unwrap_or("").contains("\"message\":\"careful\""),
  )
}

///|
test "log registry supports string payloads" {
  let buffer = LogBuffer::new()
  let registry = registry(buffer~)
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="log",
      command="write",
      payload="\"hello\"",
    ),
    capabilities=[capability_for_window("main")],
  )
  assert_true(response is InvokeOk("1", _))
  assert_eq(buffer.entries()[0].level(), "info")
  assert_eq(buffer.entries()[0].message(), "hello")
}

///|
test "log registry validates payloads" {
  let registry = registry()
  let response = registry.dispatch(
    @lepusa.InvokeRequest::new(
      id="1",
      window_label="main",
      plugin="log",
      command="write",
      payload="{\"message\":\"\"}",
    ),
    capabilities=[capability()],
  )
  assert_eq(response.error_message().unwrap_or(""), "log message is required")
}
