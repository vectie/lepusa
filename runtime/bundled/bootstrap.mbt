///|
pub fn BundledRuntimeManifest::bootstrap_json(
  self : BundledRuntimeManifest,
) -> String {
  [
    "{",
    "\"manifestPath\":\{self.path.json_string()},",
    "\"bundleRoot\":\{self.bundle_root.json_string()},",
    "\"identifier\":\{optional_string(self.bundle, "identifier").unwrap_or("").json_string()},",
    "\"productName\":\{optional_string(self.bundle, "productName").unwrap_or("").json_string()},",
    "\"target\":\{optional_string(self.bundle, "target").unwrap_or("").json_string()},",
    "\"runtime\":\{json_object_string(self.runtime)}",
    "}",
  ].join("")
}
