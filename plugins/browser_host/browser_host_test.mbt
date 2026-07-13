///|
fn request(command : String, payload : String) -> @lepusa.InvokeRequest {
  @lepusa.InvokeRequest::new(
    id="invoke-1",
    window_label="main",
    plugin="browserHost",
    command~,
    payload~,
  )
}

///|
fn command_payload() -> String {
  let payload =
    #|{"request_id":"host-action-1","session_id":"session-1","action_id":"action-1","code_revision":"code-1","authority_envelope_id":"authority-1","capability_digest":"capability-1","semantic_target":"role=button[name='Run']","allowed_origins":[],"origin_class":"OpaqueLocalPreview","network_policy":"Offline"}
  payload
}

///|
test "browser host route is capability gated and preserves terminal idempotency" {
  let state = BrowserHostState::new()
  let registry = registry(state~)
  let denied = registry.dispatch(request("execute", command_payload()), capabilities=[])
  assert_eq(
    denied.error_message().unwrap_or(""),
    "permission denied: browserHost.execute",
  )
  let grant = capability_for_window("main")
  let ready = registry.dispatch(request("execute", command_payload()), capabilities=[
    grant,
  ])
  assert_true(
    ready.payload().unwrap_or("").contains("ready-in-originating-frame"),
  )
  let result =
    #|{"request_id":"host-action-1","session_id":"session-1","action_id":"action-1","code_revision":"code-1","authority_envelope_id":"authority-1","capability_digest":"capability-1","host_receipt_id":"native-receipt-1","before_state_digest":"before-1","after_state_digest":"after-1"}
  let completed = registry.dispatch(request("complete", result), capabilities=[
    grant,
  ])
  let duplicate = registry.dispatch(request("complete", result), capabilities=[
    grant,
  ])
  assert_true(completed.payload() == duplicate.payload())
  assert_true(
    completed.payload().unwrap_or("").contains("completed-in-originating-frame"),
  )
  assert_true(
    completed.payload().unwrap_or("").contains("lepusa-native-host-action-1"),
  )
  assert_true(
    plugin().command_routes().contains("browserHost.captureScreenshot"),
  )
}

///|
test "browser host completion rejects mismatched MoonClaw identity" {
  let registry = registry()
  let grant = capability_for_window("main")
  ignore(
    registry.dispatch(request("execute", command_payload()), capabilities=[
      grant,
    ]),
  )
  let mismatch =
    #|{"request_id":"host-action-1","session_id":"other","action_id":"action-1","code_revision":"code-1","authority_envelope_id":"authority-1","capability_digest":"capability-1","host_receipt_id":"native-receipt-1","before_state_digest":"before-1","after_state_digest":"after-1"}
  let response = registry.dispatch(request("complete", mismatch), capabilities=[
    grant,
  ])
  assert_eq(
    response.error_message().unwrap_or(""),
    "browser host result session_id mismatch",
  )
}
