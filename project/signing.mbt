///|
fn signing_config_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.SigningConfig {
  let identity = optional_config_string(object, "identity")
  let team_id = optional_config_string(object, "teamId")
  let entitlements_path = optional_config_string(object, "entitlements").map(fn(
    path,
  ) {
    config_path(base_dir, path)
  })
  let notarization_profile = optional_config_string(
    object, "notarizationProfile",
  )
  let timestamp_url = optional_config_string(object, "timestampUrl")
  let signing = @lepusa.SigningConfig::new(
    identity?,
    entitlements_path?,
    team_id?,
    notarization_profile?,
    timestamp_url?,
  )
  for problem in signing.validate() {
    problems.push(problem)
  }
  signing
}
