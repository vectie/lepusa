///|
pub(all) struct LepusaMoonSuiteProductHome {
  product_id : String
  state_path : String
  service_path : String
  runtime_path : String
  update_metadata_path : String
  tmp_path : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn moonsuite_product_id() -> String {
  "lepusa"
}

///|
pub fn moonsuite_product_state_path() -> String {
  ".moonsuite/products/lepusa"
}

///|
pub fn moonsuite_product_service_path() -> String {
  "\{moonsuite_product_state_path()}/service.json"
}

///|
pub fn moonsuite_product_runtime_path() -> String {
  "\{moonsuite_product_state_path()}/runtime"
}

///|
pub fn moonsuite_product_update_metadata_path() -> String {
  "\{moonsuite_product_state_path()}/updates.json"
}

///|
pub fn moonsuite_product_tmp_path() -> String {
  ".tmp/products/lepusa"
}

///|
pub fn moonsuite_product_home() -> LepusaMoonSuiteProductHome {
  {
    product_id: moonsuite_product_id(),
    state_path: moonsuite_product_state_path(),
    service_path: moonsuite_product_service_path(),
    runtime_path: moonsuite_product_runtime_path(),
    update_metadata_path: moonsuite_product_update_metadata_path(),
    tmp_path: moonsuite_product_tmp_path(),
  }
}
