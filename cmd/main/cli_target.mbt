///|
fn parse_bundle_target(
  target : String?,
) -> Result[@lepusa.BundleTarget, String] {
  let target = match target {
    None => @lepusa.MacOS
    Some("macos") => MacOS
    Some("windows") => Windows
    Some("linux") => Linux
    Some(value) => return Err("unknown bundle target: \{value}")
  }
  Ok(target)
}
