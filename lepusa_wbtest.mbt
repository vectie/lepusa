///|
test "empty command batches collapse to none" {
  assert_true(Cmd::batch([]) is None)
  assert_eq(Cmd::batch([None]).is_empty(), true)
}
