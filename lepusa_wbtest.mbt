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

///|
test "moonsuite product home resolves from suite hosted book root" {
  let suite_root = "/tmp/lepusa-suite"
  let book_root = suite_root + "/books/desktop-shell"
  let home = moonsuite_product_home_for_workspace_root(book_root)
  assert_eq(home.product_id, "lepusa")
  assert_eq(home.state_path, suite_root + "/.moonsuite/products/lepusa")
  assert_eq(
    home.service_path,
    suite_root + "/.moonsuite/products/lepusa/service.json",
  )
  assert_eq(
    home.runtime_path,
    suite_root + "/.moonsuite/products/lepusa/runtime",
  )
  assert_eq(
    home.update_metadata_path,
    suite_root + "/.moonsuite/products/lepusa/updates.json",
  )
  assert_eq(home.tmp_path, suite_root + "/.tmp/products/lepusa")
  assert_true(!home.state_path.contains("/books/desktop-shell/.moonsuite"))
  assert_true(!home.tmp_path.contains("/books/desktop-shell/.tmp"))
}
