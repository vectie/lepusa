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
fn moonsuite_active_workspace_root() -> String {
  "."
}

///|
pub fn moonsuite_product_state_path_for_workspace_root(root : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, moonsuite_product_id()).state_path
}

///|
pub fn moonsuite_product_state_path() -> String {
  moonsuite_product_state_path_for_workspace_root(
    moonsuite_active_workspace_root(),
  )
}

///|
pub fn moonsuite_product_service_path_for_workspace_root(
  root : String,
) -> String {
  @moonsuite.product_home_for_workspace_root(root, moonsuite_product_id()).service_path
}

///|
pub fn moonsuite_product_service_path() -> String {
  moonsuite_product_service_path_for_workspace_root(
    moonsuite_active_workspace_root(),
  )
}

///|
pub fn moonsuite_product_runtime_path_for_workspace_root(
  root : String,
) -> String {
  @moonsuite.product_artifact_for_workspace_root(
    root,
    moonsuite_product_id(),
    "runtime",
  )
}

///|
pub fn moonsuite_product_runtime_path() -> String {
  moonsuite_product_runtime_path_for_workspace_root(
    moonsuite_active_workspace_root(),
  )
}

///|
pub fn moonsuite_product_update_metadata_path_for_workspace_root(
  root : String,
) -> String {
  @moonsuite.product_artifact_for_workspace_root(
    root,
    moonsuite_product_id(),
    "updates.json",
  )
}

///|
pub fn moonsuite_product_update_metadata_path() -> String {
  moonsuite_product_update_metadata_path_for_workspace_root(
    moonsuite_active_workspace_root(),
  )
}

///|
pub fn moonsuite_product_tmp_path_for_workspace_root(root : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, moonsuite_product_id()).tmp_path
}

///|
pub fn moonsuite_product_tmp_path() -> String {
  moonsuite_product_tmp_path_for_workspace_root(
    moonsuite_active_workspace_root(),
  )
}

///|
pub fn moonsuite_product_home_for_workspace_root(
  root : String,
) -> LepusaMoonSuiteProductHome {
  {
    product_id: moonsuite_product_id(),
    state_path: moonsuite_product_state_path_for_workspace_root(root),
    service_path: moonsuite_product_service_path_for_workspace_root(root),
    runtime_path: moonsuite_product_runtime_path_for_workspace_root(root),
    update_metadata_path: moonsuite_product_update_metadata_path_for_workspace_root(
      root,
    ),
    tmp_path: moonsuite_product_tmp_path_for_workspace_root(root),
  }
}

///|
pub fn moonsuite_product_home() -> LepusaMoonSuiteProductHome {
  moonsuite_product_home_for_workspace_root(moonsuite_active_workspace_root())
}
