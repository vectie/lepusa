///|
test "ipc schemas expose stable names typescript and json" {
  let request = @lepusa.IpcSchema::object(
    "SetTitleRequest",
    "{ readonly title: string }",
    description="window title payload",
  )
  assert_eq(request.name(), "SetTitleRequest")
  assert_eq(request.typescript(), "{ readonly title: string }")
  assert_eq(request.description(), "window title payload")
  assert_eq(request.validate().is_empty(), true)
  assert_true(request.to_json().contains("\"name\":\"SetTitleRequest\""))
  assert_true(
    request.to_json().contains("\"typescript\":\"{ readonly title: string }\""),
  )
  let list = @lepusa.IpcSchema::array(@lepusa.IpcSchema::string())
  assert_eq(list.name(), "string[]")
  assert_eq(list.typescript(), "ReadonlyArray<string>")
}

///|
test "ipc schemas validate required public metadata" {
  let missing_name = @lepusa.IpcSchema::new(name="", typescript="string")
  assert_eq(missing_name.validate()[0], "ipc schema name is required")
  let missing_type = @lepusa.IpcSchema::new(name="Bad", typescript="")
  assert_eq(
    missing_type.validate()[0],
    "ipc schema TypeScript type is required",
  )
}

///|
test "ipc schemas validate runtime payload categories" {
  assert_true(@lepusa.IpcSchema::any().accepts_payload("raw text"))
  assert_true(@lepusa.IpcSchema::string().accepts_payload("raw text"))
  assert_true(@lepusa.IpcSchema::unit().accepts_payload(""))
  assert_true(@lepusa.IpcSchema::unit().accepts_payload("null"))
  assert_false(@lepusa.IpcSchema::unit().accepts_payload("{}"))
  assert_true(@lepusa.IpcSchema::json().accepts_payload("{\"ok\":true}"))
  assert_false(@lepusa.IpcSchema::json().accepts_payload("not-json"))
  assert_true(@lepusa.IpcSchema::boolean().accepts_payload("true"))
  assert_false(@lepusa.IpcSchema::boolean().accepts_payload("\"true\""))
  assert_true(@lepusa.IpcSchema::number().accepts_payload("12"))
  assert_false(@lepusa.IpcSchema::number().accepts_payload("\"12\""))
  assert_true(
    @lepusa.IpcSchema::array(@lepusa.IpcSchema::string()).accepts_payload(
      "[\"a\",\"b\"]",
    ),
  )
  assert_false(
    @lepusa.IpcSchema::array(@lepusa.IpcSchema::string()).accepts_payload("{}"),
  )
  let object = @lepusa.IpcSchema::object(
    "Request", "{ readonly value: string }",
  )
  assert_true(object.accepts_payload("{\"value\":\"ok\"}"))
  assert_false(object.accepts_payload("[\"value\"]"))
  assert_true(
    object
    .validate_payload("[\"value\"]")
    .unwrap_or("")
    .contains("expected object payload"),
  )
}

///|
test "plugin commands carry request and response schemas" {
  let plugin = @lepusa.Plugin::new("window").command_sync(
    "setTitle",
    permission=Window,
    request=@lepusa.IpcSchema::object(
      "SetTitleRequest", "{ readonly title: string }",
    ),
    response=@lepusa.IpcSchema::unit(),
  )
  let command = plugin.commands()[0]
  assert_eq(command.request_schema().name(), "SetTitleRequest")
  assert_eq(command.response_schema().typescript(), "void")
  assert_eq(plugin.validate().is_empty(), true)
}
