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
