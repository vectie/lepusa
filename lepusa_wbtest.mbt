///|
test "empty command batches collapse to none" {
  assert_true(Cmd::batch([]) is None)
  assert_eq(Cmd::batch([None]).is_empty(), true)
}

///|
test "root package exposes moonsuite product home contract" {
  let home = moonsuite_product_home()
  assert_eq(home.product_id, "lepusa")
  assert_eq(home.state_path, ".moonsuite/products/lepusa")
  assert_eq(home.service_path, ".moonsuite/products/lepusa/service.json")
  assert_eq(home.runtime_path, ".moonsuite/products/lepusa/runtime")
  assert_eq(
    home.update_metadata_path,
    ".moonsuite/products/lepusa/updates.json",
  )
  assert_eq(home.tmp_path, ".tmp/products/lepusa")
}
