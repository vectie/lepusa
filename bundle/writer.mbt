///|
pub struct BundleWriteResult {
  root : String
  files : Array[String]
  resources : Array[String]
  checks : Array[BundleWriteCheck]
} derive(Debug, Eq)

///|
pub(all) enum BundleWriteCheckKind {
  PlannedFileCheck
  PlannedResourceCheck
  RuntimeExecutableCheck
  RuntimeManifestCheck
  InitialContentCheck
  NativeLaunchSessionCheck
} derive(Debug, Eq)

///|
pub struct BundleWriteCheck {
  kind : BundleWriteCheckKind
  path : String
  ok : Bool
  message : String
} derive(Debug, Eq)

///|
pub fn BundleWriteResult::root(self : BundleWriteResult) -> String {
  self.root
}

///|
pub fn BundleWriteResult::files(self : BundleWriteResult) -> Array[String] {
  self.files
}

///|
pub fn BundleWriteResult::resources(self : BundleWriteResult) -> Array[String] {
  self.resources
}

///|
pub fn BundleWriteResult::checks(
  self : BundleWriteResult,
) -> Array[BundleWriteCheck] {
  self.checks.copy()
}

///|
pub fn BundleWriteResult::verified(self : BundleWriteResult) -> Bool {
  for check in self.checks {
    if !check.ok() {
      return false
    }
  }
  true
}

///|
pub fn BundleWriteCheck::new(
  kind~ : BundleWriteCheckKind,
  path~ : String,
  ok~ : Bool,
  message~ : String,
) -> BundleWriteCheck {
  { kind, path, ok, message }
}

///|
pub fn BundleWriteCheck::kind(self : BundleWriteCheck) -> BundleWriteCheckKind {
  self.kind
}

///|
pub fn BundleWriteCheck::path(self : BundleWriteCheck) -> String {
  self.path
}

///|
pub fn BundleWriteCheck::ok(self : BundleWriteCheck) -> Bool {
  self.ok
}

///|
pub fn BundleWriteCheck::message(self : BundleWriteCheck) -> String {
  self.message
}

///|
pub fn BundleWriteCheckKind::name(self : BundleWriteCheckKind) -> String {
  match self {
    PlannedFileCheck => "planned-file"
    PlannedResourceCheck => "planned-resource"
    RuntimeExecutableCheck => "runtime-executable"
    RuntimeManifestCheck => "runtime-manifest"
    InitialContentCheck => "initial-content"
    NativeLaunchSessionCheck => "native-launch-session"
  }
}

///|
pub async fn write_plan(
  plan : @lepusa.BundlePlan,
  out_dir : String,
) -> Result[BundleWriteResult, Array[String]] {
  match plan.files() {
    Ok(files) => {
      let root = normalize_output_root(out_dir)
      let problems : Array[String] = []
      let written : Array[String] = []
      let copied_resources : Array[String] = []
      ensure_directory(root, problems)
      for file in files {
        let path = join_path(root, file.path())
        ensure_directory(parent_directory(path), problems)
        if problems.is_empty() {
          let problem_count = problems.length()
          @fs.write_file(
            path,
            file.content(),
            create_mode=CreateOrTruncate,
            permission=0o644,
          ) catch {
            error => problems.push("could not write \{path}: \{error}")
          }
          if file.executable() {
            @fs.chmod(path, 0o755) catch {
              error =>
                problems.push("could not mark executable \{path}: \{error}")
            }
          }
          if problems.length() == problem_count {
            written.push(path)
          }
        }
      }
      for resource in plan.resources() {
        let path = join_path(root, resource.path())
        ensure_directory(parent_directory(path), problems)
        if problems.is_empty() {
          let problem_count = problems.length()
          copy_bundle_resource(resource, path, problems)
          if problems.length() == problem_count {
            copied_resources.push(path)
          }
        }
      }
      let runtime_executable = copy_bundle_runtime_executable(
        plan, root, problems,
      )
      match runtime_executable {
        Some(path) => written.push(path)
        None => ()
      }
      if problems.is_empty() {
        let checks = verify_written_plan(root, files, plan.resources())
        match runtime_executable {
          Some(path) => checks.push(verify_runtime_executable(path))
          None => ()
        }
        Ok({ root, files: written, resources: copied_resources, checks })
      } else {
        Err(problems)
      }
    }
    Err(problems) => Err(problems)
  }
}

///|
async fn verify_written_plan(
  root : String,
  files : Array[@lepusa.BundleFile],
  resources : Array[@lepusa.BundleResource],
) -> Array[BundleWriteCheck] {
  let checks : Array[BundleWriteCheck] = []
  for file in files {
    let path = join_path(root, file.path())
    checks.push(verify_planned_file(path, file))
    if file.path().has_suffix("lepusa/runtime.json") {
      checks.push(verify_runtime_manifest(path))
      checks.push(verify_initial_content(path))
      checks.push(verify_native_launch_session(path))
    }
  }
  for resource in resources {
    let path = join_path(root, resource.path())
    checks.push(verify_resource(path, resource))
  }
  checks
}

///|
async fn verify_planned_file(
  path : String,
  file : @lepusa.BundleFile,
) -> BundleWriteCheck {
  let content = @fs.read_file(path) catch {
    error =>
      return BundleWriteCheck::new(
        kind=PlannedFileCheck,
        path~,
        ok=false,
        message="could not read planned file: \{error}",
      )
  }
  let actual = content.text()
  let ok = actual == file.content()
  BundleWriteCheck::new(
    kind=PlannedFileCheck,
    path~,
    ok~,
    message=if ok {
      if file.executable() {
        "executable planned file content matches"
      } else {
        "planned file content matches"
      }
    } else {
      "planned file content differs"
    },
  )
}

///|
async fn verify_runtime_manifest(path : String) -> BundleWriteCheck {
  let content = @fs.read_file(path) catch {
    error =>
      return BundleWriteCheck::new(
        kind=RuntimeManifestCheck,
        path~,
        ok=false,
        message="could not read runtime manifest: \{error}",
      )
  }
  let text = content.text()
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) =>
      match manifest.webviews() {
        Ok(webviews) => {
          let ok = !webviews.is_empty()
          BundleWriteCheck::new(
            kind=RuntimeManifestCheck,
            path~,
            ok~,
            message=if ok {
              "runtime manifest parses with webview data"
            } else {
              "runtime manifest has no webviews"
            },
          )
        }
        Err(problem) =>
          BundleWriteCheck::new(
            kind=RuntimeManifestCheck,
            path~,
            ok=false,
            message="runtime manifest webviews invalid: \{problem}",
          )
      }
    Err(problem) =>
      BundleWriteCheck::new(
        kind=RuntimeManifestCheck,
        path~,
        ok=false,
        message="runtime manifest parse failed: \{problem}",
      )
  }
}

///|
async fn verify_native_launch_session(path : String) -> BundleWriteCheck {
  let content = @fs.read_file(path) catch {
    error =>
      return BundleWriteCheck::new(
        kind=NativeLaunchSessionCheck,
        path~,
        ok=false,
        message="could not read runtime manifest: \{error}",
      )
  }
  let text = content.text()
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) =>
      match
        manifest.prepare_native_run_plan(target=manifest.target(), prepare_webview=fn(
          webview,
        ) {
          manifest.webview_plan(webview, initialization_script="")
        }) {
        Ok(plan) =>
          match plan.launch_session() {
            Ok(session) => {
              let capability = bundle_launch_capability(manifest.target())
              let blocker = session.launch_blocker_with_capability(
                bundle_target_display_name(manifest.target()),
                capability,
              )
              BundleWriteCheck::new(
                kind=NativeLaunchSessionCheck,
                path~,
                ok=blocker is None,
                message=match blocker {
                  None => "native launch session prepares"
                  Some(problem) => problem
                },
              )
            }
            Err(problem) =>
              BundleWriteCheck::new(
                kind=NativeLaunchSessionCheck,
                path~,
                ok=false,
                message="native launch session invalid: \{problem}",
              )
          }
        Err(problems) =>
          BundleWriteCheck::new(
            kind=NativeLaunchSessionCheck,
            path~,
            ok=false,
            message="native run plan invalid: \{problems.join("; ")}",
          )
      }
    Err(problem) =>
      BundleWriteCheck::new(
        kind=NativeLaunchSessionCheck,
        path~,
        ok=false,
        message="runtime manifest parse failed: \{problem}",
      )
  }
}

///|
async fn copy_bundle_runtime_executable(
  plan : @lepusa.BundlePlan,
  root : String,
  problems : Array[String],
) -> String? {
  match bundled_runtime_destination_path(plan) {
    Some(destination) => {
      let source = bundled_runtime_source_path()
      let source_exists = @xfs.is_file(source) catch { _ => false }
      if !source_exists {
        return None
      }
      let path = join_path(root, destination)
      copy_bundle_file(source, path, problems)
      if problems.is_empty() {
        @fs.chmod(path, 0o755) catch {
          error =>
            problems.push("could not mark runtime executable \{path}: \{error}")
        }
      }
      if problems.is_empty() {
        Some(path)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn bundled_runtime_destination_path(plan : @lepusa.BundlePlan) -> String? {
  if !bundle_target_matches_host_runtime(plan.target()) {
    return None
  }
  Some(plan.runtime_executable_path())
}

///|
fn bundled_runtime_source_path() -> String {
  "_build/native/debug/build/cmd/runtime/runtime.exe"
}

///|
fn bundle_target_matches_host_runtime(target : @lepusa.BundleTarget) -> Bool {
  match target {
    MacOS => @macos_backend.available()
    Windows => @windows_backend.available()
    Linux => @linux_backend.available()
  }
}

///|
fn verify_runtime_executable(path : String) -> BundleWriteCheck {
  let ok = @xfs.is_file(path) catch { _ => false }
  BundleWriteCheck::new(
    kind=RuntimeExecutableCheck,
    path~,
    ok~,
    message=if ok {
      "runtime executable is bundled"
    } else {
      "runtime executable is missing"
    },
  )
}

///|
fn bundle_launch_capability(target : String) -> @runtime.NativeLaunchCapability {
  match target {
    "macos" => @macos_backend.launch_capability()
    "linux" => @linux_backend.launch_capability()
    "windows" => @windows_backend.launch_capability()
    _ =>
      @runtime.NativeLaunchCapability::new(
        webview_creation=false,
        async_bridge_drain=false,
        webview_creation_message="native launch target is unsupported: \{target}",
      )
  }
}

///|
fn bundle_target_display_name(target : String) -> String {
  match target {
    "macos" => "macOS"
    "windows" => "Windows"
    "linux" => "Linux"
    _ => target
  }
}

///|
async fn verify_resource(
  path : String,
  resource : @lepusa.BundleResource,
) -> BundleWriteCheck {
  let ok = match resource.kind() {
    AssetResource => @fs.exists(path) catch { _ => false }
    _ => @xfs.is_file(path) catch { _ => false }
  }
  BundleWriteCheck::new(
    kind=PlannedResourceCheck,
    path~,
    ok~,
    message=if ok { "resource exists" } else { "resource is missing" },
  )
}

///|
async fn copy_bundle_resource(
  resource : @lepusa.BundleResource,
  destination : String,
  problems : Array[String],
) -> Unit {
  if resource.kind() is AssetResource {
    copy_bundle_asset_directory(resource.source_path(), destination, problems)
    return
  }
  let content = @fs.read_file(resource.source_path()) catch {
    error => {
      problems.push(
        "could not read bundle resource \{resource.source_path()}: \{error}",
      )
      return
    }
  }
  @fs.write_file(
    destination,
    content,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    error =>
      problems.push("could not write bundle resource \{destination}: \{error}")
  }
}

///|
async fn copy_bundle_asset_directory(
  source : String,
  destination : String,
  problems : Array[String],
) -> Unit {
  let is_dir = @xfs.is_dir(source) catch {
    _ => {
      problems.push("could not inspect bundle asset \{source}")
      return
    }
  }
  if !is_dir {
    copy_bundle_file(source, destination, problems)
    return
  }
  ensure_directory(destination, problems)
  if !problems.is_empty() {
    return
  }
  let entries = @xfs.read_dir(source) catch {
    _ => {
      problems.push("could not read bundle asset directory \{source}")
      return
    }
  }
  for entry in entries {
    copy_bundle_asset_directory(
      join_path(source, entry),
      join_path(destination, entry),
      problems,
    )
  }
}

///|
async fn copy_bundle_file(
  source : String,
  destination : String,
  problems : Array[String],
) -> Unit {
  let content = @fs.read_file(source) catch {
    error => {
      problems.push("could not read bundle resource \{source}: \{error}")
      return
    }
  }
  ensure_directory(parent_directory(destination), problems)
  if !problems.is_empty() {
    return
  }
  @fs.write_file(
    destination,
    content,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    error =>
      problems.push("could not write bundle resource \{destination}: \{error}")
  }
}

///|
fn normalize_output_root(path : String) -> String {
  let trimmed = path.trim_end(chars="/\\").to_owned()
  if trimmed.is_empty() {
    "_build/lepusa-bundle"
  } else {
    trimmed
  }
}

///|
async fn ensure_directory(path : String, problems : Array[String]) -> Unit {
  let exists = @fs.exists(path) catch { _ => false }
  if path == "" || path == "." || exists {
    return
  }
  @fs.mkdir(path, recursive=true, permission=0o755) catch {
    error => problems.push("could not create directory \{path}: \{error}")
  }
}

///|
fn join_path(base : String, path : String) -> String {
  if base == "" || base == "." {
    path
  } else if path == "" {
    base
  } else {
    "\{base}/\{path}"
  }
}

///|
fn parent_directory(path : String) -> String {
  let normalized = path.trim_end(chars="/\\").to_owned()
  match normalized.rev_find("/") {
    Some(index) => if index == 0 { "/" } else { normalized[:index].to_owned() }
    None => "."
  }
}
