///|
test "file dialog native packets preserve selected and cancelled responses" {
  guard decode_native_pick_packet(
      b"ok\n{\"action\":\"openDirectory\",\"status\":\"selected\",\"native\":true,\"cancelled\":false,\"path\":\"/tmp/library\"}",
      action="openDirectory",
    )
    is Ok(selected) else {
    fail("expected selected native picker packet")
  }
  assert_true(selected.contains("\"status\":\"selected\""))
  assert_true(selected.contains("\"path\":\"/tmp/library\""))
  guard decode_native_pick_packet(
      b"ok\n{\"action\":\"openDirectory\",\"status\":\"cancelled\",\"native\":true,\"cancelled\":true}",
      action="openDirectory",
    )
    is Ok(cancelled) else {
    fail("expected cancelled native picker packet")
  }
  assert_true(cancelled.contains("\"status\":\"cancelled\""))
  assert_true(cancelled.contains("\"cancelled\":true"))
}
