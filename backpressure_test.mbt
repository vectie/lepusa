///|
test "backpressure policy validates queue bounds" {
  let unbounded = @lepusa.BackpressurePolicy::unbounded()
  assert_true(unbounded.is_unbounded())
  assert_false(unbounded.at_capacity(1000))
  assert_true(unbounded.to_json().contains("\"bounded\":false"))
  let bounded = @lepusa.BackpressurePolicy::bounded(
    max_pending=2,
    overflow=DropOldest,
  )
  assert_true(bounded.is_bounded())
  assert_false(bounded.at_capacity(1))
  assert_true(bounded.at_capacity(2))
  assert_true(bounded.overflow() is DropOldest)
  assert_eq(bounded.validate().length(), 0)
  assert_true(bounded.to_json().contains("\"overflow\":\"drop-oldest\""))
  let invalid = @lepusa.BackpressurePolicy::bounded(max_pending=0)
  assert_true(
    invalid.validate().contains("backpressure max pending must be positive"),
  )
}
