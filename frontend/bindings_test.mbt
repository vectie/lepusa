///|
fn frontend_test_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync("read", permission=FileSystemRead)
      .command_async("write", permission=FileSystemWrite),
    )
    .with_plugin(
      @lepusa.Plugin::new("window-state").command_sync(
        "get-value",
        permission=Window,
      ),
    )
    .with_capability(
      @lepusa.Capability::new("core").window("main").permission(FileSystemRead),
    )
    .with_capability(
      @lepusa.Capability::new("write")
      .window("main")
      .permission(FileSystemWrite),
    )
    .with_capability(@lepusa.Capability::new("window").permission(Window))
  match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "frontend api bundle generates javascript from runtime command manifest" {
  match FrontendApiBundle::from_runtime_plan(frontend_test_plan()) {
    Ok(bundle) => {
      assert_eq(bundle.config().global_name(), "lepusa")
      assert_eq(bundle.command_manifest().entries().length(), 3)
      let js = bundle.javascript()
      assert_true(js.contains("export const commandManifest"))
      assert_true(js.contains("\"route\":\"core.read\""))
      assert_true(js.contains("export const routes"))
      assert_true(js.contains("export const core = commands[\"core\"];"))
      assert_false(js.contains("export const window-state"))
      assert_true(js.contains("scope[leaf] = makeInvoker(route);"))
      assert_true(js.contains("export default Object.freeze"))
    }
    Err(_) => abort("unexpected frontend bundle error")
  }
}

///|
test "frontend api bundle generates typescript declarations" {
  match FrontendApiBundle::from_runtime_plan(frontend_test_plan()) {
    Ok(bundle) => {
      let dts = bundle.typescript()
      assert_true(
        dts.contains(
          "export type LepusaRoute = \"core.read\" | \"core.write\" | \"window-state.get-value\";",
        ),
      )
      assert_true(dts.contains("export declare function invoke"))
      assert_true(dts.contains("export declare const commands: {"))
      assert_true(dts.contains("core: {"))
      assert_true(dts.contains("read: (payload?: LepusaPayload)"))
      assert_true(dts.contains("\"window-state\": {"))
      assert_true(dts.contains("\"get-value\": (payload?: LepusaPayload)"))
      assert_true(
        dts.contains("export declare const core: typeof commands[\"core\"];"),
      )
      assert_true(bundle.to_json().contains("\"typescript\""))
    }
    Err(_) => abort("unexpected frontend bundle error")
  }
}

///|
test "frontend api bundle can use launch manifests and validates config" {
  let plan = frontend_test_plan()
  match plan.launch_manifest() {
    Ok(manifest) =>
      match
        FrontendApiBundle::from_launch_manifest(
          manifest,
          config=FrontendApiConfig::new(global_name="lepusaNative"),
        ) {
        Ok(bundle) => {
          assert_true(
            bundle.javascript().contains("globalName = \"lepusaNative\""),
          )
          assert_true(bundle.typescript().contains("export default api;"))
        }
        Err(_) => abort("unexpected launch frontend bundle error")
      }
    Err(_) => abort("unexpected launch manifest error")
  }
  match
    FrontendApiBundle::from_runtime_plan(
      plan,
      config=FrontendApiConfig::new(global_name="", module_name=""),
    ) {
    Ok(_) => abort("unexpected valid config")
    Err(problems) => {
      assert_eq(problems.length(), 2)
      assert_eq(problems[0], "frontend api global name is required")
      assert_eq(problems[1], "frontend api module name is required")
    }
  }
}
