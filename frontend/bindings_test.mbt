///|
fn frontend_test_plan() -> @lepusa.RuntimePlan {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync(
        "read",
        permission=FileSystemRead,
        request=@lepusa.IpcSchema::object(
          "ReadTextRequest", "{ readonly path: string }",
        ),
        response=@lepusa.IpcSchema::string(),
      )
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
      assert_true(js.contains("export const isInvokeError"))
      assert_true(js.contains("export const emit = (name, payload = null)"))
      assert_true(js.contains("export const emitTo = (target, name"))
      assert_true(js.contains("options = {}) => getApi().invoke"))
      assert_true(
        js.contains("makeInvoker = (route) => (payload = null, options = {})"),
      )
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
      assert_true(dts.contains("export type LepusaInvokeOptions"))
      assert_true(dts.contains("export type LepusaCommandPayloads = {"))
      assert_true(dts.contains("\"core.read\": { readonly path: string };"))
      assert_true(dts.contains("\"core.read\": string;"))
      assert_true(
        dts.contains(
          "payload?: LepusaPayloadFor<Route>, options?: LepusaInvokeOptions",
        ),
      )
      assert_true(dts.contains("export type LepusaInvokeErrorCode"))
      assert_true(
        dts.contains("export interface LepusaInvokeError extends Error"),
      )
      assert_true(
        dts.contains(
          "export declare function isInvokeError(error: unknown): error is LepusaInvokeError;",
        ),
      )
      assert_true(
        dts.contains(
          "export declare function emit(name: string, payload?: LepusaPayload): Promise<number>;",
        ),
      )
      assert_true(dts.contains("export type LepusaEventTarget"))
      assert_true(dts.contains("export declare function emitTo"))
      assert_true(dts.contains("export declare const commands: {"))
      assert_true(dts.contains("core: {"))
      assert_true(
        dts.contains(
          "read: (payload?: { readonly path: string }, options?: LepusaInvokeOptions) => Promise<string>;",
        ),
      )
      assert_true(dts.contains("\"window-state\": {"))
      assert_true(
        dts.contains(
          "\"get-value\": (payload?: unknown, options?: LepusaInvokeOptions) => Promise<unknown>;",
        ),
      )
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
  match plan.launch_manifest(registered_routes=plan.command_routes()) {
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

///|
test "frontend api bundle filters denied event and unregistered routes" {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(label="main", source=@lepusa.Source::html("<main></main>"))
    .with_plugin(
      @lepusa.Plugin::new("core")
      .command_sync("read")
      .command_sync("admin")
      .command_event("changed"),
    )
    .with_capability(
      @lepusa.Capability::new("main")
      .window("main")
      .command("core.read")
      .command("core.changed"),
    )
  let plan = match app.runtime_plan(config=@lepusa.RuntimeConfig::headless()) {
    Ok(plan) => plan
    Err(_) => abort("unexpected invalid frontend filter plan")
  }
  match FrontendApiBundle::from_runtime_plan(plan) {
    Ok(bundle) => {
      let js = bundle.javascript()
      assert_true(js.contains("\"route\":\"core.read\""))
      assert_false(js.contains("\"route\":\"core.admin\""))
      assert_false(js.contains("\"route\":\"core.changed\""))
      assert_eq(bundle.command_manifest().entries().length(), 1)
    }
    Err(_) => abort("unexpected filtered frontend bundle error")
  }
  match plan.launch_manifest(registered_routes=["core.read"]) {
    Ok(open_manifest) =>
      match FrontendApiBundle::from_launch_manifest(open_manifest) {
        Ok(bundle) => assert_eq(bundle.command_manifest().entries().length(), 1)
        Err(_) => abort("unexpected registered launch frontend bundle error")
      }
    Err(_) => abort("unexpected launch manifest error")
  }
  match plan.launch_manifest(registered_routes=[]) {
    Ok(registered_manifest) =>
      match FrontendApiBundle::from_launch_manifest(registered_manifest) {
        Ok(bundle) => {
          assert_eq(bundle.command_manifest().entries().length(), 0)
          assert_true(bundle.typescript().contains("Record<string, never>"))
        }
        Err(_) =>
          abort("unexpected empty registered launch frontend bundle error")
      }
    Err(_) => abort("unexpected registered launch manifest error")
  }
}
