///|
pub fn RuntimeHost::launch_manifest(
  self : RuntimeHost,
) -> Result[@lepusa.RuntimeLaunchManifest, Array[String]] {
  self.plan.launch_manifest(registered_routes=self.registry.routes())
}
