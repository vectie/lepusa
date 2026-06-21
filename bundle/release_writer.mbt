///|
pub struct BundleReleaseWriteResult {
  root : String
  plan_path : String
  checklist_path : String
  plan : BundleReleasePlan
} derive(Debug, Eq)

///|
pub fn BundleReleaseWriteResult::root(
  self : BundleReleaseWriteResult,
) -> String {
  self.root
}

///|
pub fn BundleReleaseWriteResult::plan_path(
  self : BundleReleaseWriteResult,
) -> String {
  self.plan_path
}

///|
pub fn BundleReleaseWriteResult::checklist_path(
  self : BundleReleaseWriteResult,
) -> String {
  self.checklist_path
}

///|
pub fn BundleReleaseWriteResult::plan(
  self : BundleReleaseWriteResult,
) -> BundleReleasePlan {
  self.plan
}

///|
pub fn BundleReleaseWriteResult::files(
  self : BundleReleaseWriteResult,
) -> Array[String] {
  [self.plan_path, self.checklist_path]
}

///|
pub fn BundleReleaseWriteResult::ready(self : BundleReleaseWriteResult) -> Bool {
  self.plan.ready()
}

///|
pub fn BundleReleaseWriteResult::to_json(
  self : BundleReleaseWriteResult,
) -> String {
  [
    "{",
    "\"root\":\{self.root.json_string()},",
    "\"ready\":\{self.ready().json_bool()},",
    "\"files\":[\{self.files().map(fn(file) { file.json_string() }).join(",")}],",
    "\"plan\":\{self.plan.to_json()}",
    "}",
  ].join("")
}

///|
pub async fn write_release_plan(
  plan : BundleReleasePlan,
  out_dir : String,
) -> Result[BundleReleaseWriteResult, Array[String]] {
  let root = normalize_output_root(out_dir)
  let plan_path = join_path(root, "release-plan.json")
  let checklist_path = join_path(root, "release-checklist.md")
  let problems : Array[String] = []
  ensure_directory(root, problems)
  write_release_file(plan_path, plan.to_json() + "\n", problems)
  write_release_file(checklist_path, plan.checklist_markdown(), problems)
  if problems.is_empty() {
    Ok({ root, plan_path, checklist_path, plan })
  } else {
    Err(problems)
  }
}

///|
pub fn BundleReleasePlan::checklist_markdown(
  self : BundleReleasePlan,
) -> String {
  let manifest = self.manifest()
  let lines : Array[String] = [
    "# Lepusa Release Checklist",
    "",
    "- manifest: \{manifest.path()}",
    "- identifier: \{manifest.identifier()}",
    "- product: \{manifest.product_name()}",
    "- version: \{manifest.version()}",
    "- target: \{manifest.target()}",
    "- ready: \{self.ready()}",
    "- readiness: \{self.readiness_message()}",
    "",
    "## Steps",
    "",
  ]
  for step in self.steps() {
    let mark = if step.required() { "[ ]" } else { "[-]" }
    lines.push(
      "\{mark} \{step.name()} (\{step.kind().name()}, required=\{step.required()}, items=\{step.item_count()})",
    )
    if step.items().is_empty() {
      lines.push("  - no distribution entries")
    } else {
      for item in step.items() {
        lines.push("  - \{release_item_markdown(item)}")
      }
    }
    lines.push("")
  }
  lines.join("\n")
}

///|
async fn write_release_file(
  path : String,
  content : String,
  problems : Array[String],
) -> Unit {
  if !problems.is_empty() {
    return
  }
  ensure_directory(parent_directory(path), problems)
  if !problems.is_empty() {
    return
  }
  @fs.write_file(path, content, create_mode=CreateOrTruncate, permission=0o644) catch {
    error => problems.push("could not write release artifact \{path}: \{error}")
  }
}

///|
fn release_item_markdown(item : BundleDistributionEntry) -> String {
  let details : Array[String] = [
    "kind=\{item.kind()}",
    "name=\{item.name()}",
    "required=\{item.required()}",
  ]
  match item.path() {
    Some(path) => details.push("path=\{path}")
    None => ()
  }
  match item.source_path() {
    Some(path) => details.push("source=\{path}")
    None => ()
  }
  if item.description() != "" {
    details.push("description=\{item.description()}")
  }
  details.join(", ")
}
