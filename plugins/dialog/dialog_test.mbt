///|
test "dialog plugin declares async dialog commands" {
  let declared = plugin()
  assert_eq(declared.name(), "dialog")
  assert_eq(declared.command_routes().length(), 3)
  assert_true(declared.command_routes().contains("dialog.message"))
  assert_true(declared.command_routes().contains("dialog.confirm"))
  assert_true(declared.command_routes().contains("dialog.prompt"))
  let commands = declared.commands()
  assert_true(commands[0].mode() is Async)
  assert_true(commands[0].permission() is Dialog)
  assert_true(commands[1].permission() is Dialog)
}

///|
test "dialog capabilities grant dialog permission by window" {
  let grant = capability_for_window("main")
  assert_true(grant.allows(window_label="main", permission=Dialog))
  assert_false(grant.allows(window_label="settings", permission=Dialog))
  assert_false(grant.allows(window_label="main", permission=Clipboard))
}

///|
async test "dialog registry returns deterministic responses" {
  let registry = registry(policy=DialogPolicy::new(confirm_default=true))
  assert_true(registry.contains("dialog.message"))
  assert_true(registry.contains("dialog.confirm"))
  assert_true(registry.contains("dialog.prompt"))
  assert_eq(registry.async_routes().length(), 3)
  let grant = capability_for_window("main")
  let message_request = @lepusa.InvokeRequest::new(
    id="1",
    window_label="main",
    plugin="dialog",
    command="message",
    payload="{\"title\":\"Notice\",\"message\":\"Saved\"}",
  )
  let message = registry.dispatch_async(message_request, capabilities=[grant])
  assert_true(
    message.payload().unwrap_or("").contains("\"status\":\"acknowledged\""),
  )
  let confirm_request = @lepusa.InvokeRequest::new(
    id="2",
    window_label="main",
    plugin="dialog",
    command="confirm",
    payload="{\"message\":\"Continue?\"}",
  )
  let confirm = registry.dispatch_async(confirm_request, capabilities=[grant])
  assert_true(confirm.payload().unwrap_or("").contains("\"confirmed\":true"))
  let prompt_request = @lepusa.InvokeRequest::new(
    id="3",
    window_label="main",
    plugin="dialog",
    command="prompt",
    payload="{\"message\":\"Name\",\"defaultValue\":\"Lepusa\"}",
  )
  let prompt = registry.dispatch_async(prompt_request, capabilities=[grant])
  assert_true(prompt.payload().unwrap_or("").contains("\"value\":\"Lepusa\""))
}
