///|
test "empty command batches collapse to none" {
  assert_true(Cmd::batch([]) is Cmd::None)
  assert_eq(Cmd::batch([Cmd::None]).is_empty(), true)
}
