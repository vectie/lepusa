///|
fn wb_bridge_test_host() -> @runtime.RuntimeHost {
  let root = @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
  let app = @lepusa.new(root)
    .window(title="macOS", source=@lepusa.Source::html("<main>macOS</main>"))
    .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
    .with_capability(
      @lepusa.Capability::new("core").window("main").command("core.invoke"),
    )
  match app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview()) {
    Ok(plan) => {
      let registry = @lepusa.CommandRegistry::new().register_fn("core.invoke", handler=fn(
        payload,
      ) {
        Ok("{\"seen\":\{payload}}")
      })
      @runtime.RuntimeHost::new(plan, registry~)
    }
    Err(_) => abort("unexpected invalid runtime plan")
  }
}

///|
test "macos bridge callback dispatches native runtime messages" {
  match runtime(wb_bridge_test_host()) {
    Ok(runtime) =>
      match prepare_run(runtime) {
        Ok(plan) => {
          let webview = match plan.first_webview() {
            Ok(webview) => webview
            Err(problem) => abort(problem)
          }
          assert_eq(webview.native_hook(), "__lepusaInvoke")
          let dispatch = runtime_dispatch(runtime)
          let message = "{\"id\":\"42\",\"window_label\":\"main\",\"plugin\":\"core\",\"command\":\"invoke\",\"payload\":\"true\"}"
          let script = @utf8.decode(dispatch(@utf8.encode(message))) catch {
            _ => abort("unexpected invalid utf8 response script")
          }
          assert_true(script.contains("globalThis[\"__lepusaInvokeResponse\"]"))
          assert_true(script.contains("\"id\":\"42\""))
          assert_true(script.contains("\"payload\":\"{\\\"seen\\\":true}\""))
        }
        Err(_) => abort("unexpected invalid macOS run plan")
      }
    Err(_) => abort("unexpected invalid macOS native runtime")
  }
}

///|
test "macos bridge callback dispatches bundled sync messages" {
  match
    @bundled.BundledRuntimeManifest::parse(
      "/Example.app/Contents/Resources/lepusa/runtime.json",
      wb_bundled_macos_manifest(),
    ) {
    Ok(manifest) =>
      match prepare_bundled_run(manifest) {
        Ok(_) => {
          let dispatch = bundled_dispatch(manifest)
          let message = "{\"id\":\"43\",\"window_label\":\"main\",\"plugin\":\"log\",\"command\":\"write\",\"payload\":\"{\\\"message\\\":\\\"ready\\\"}\"}"
          let script = @utf8.decode(dispatch(@utf8.encode(message))) catch {
            _ => abort("unexpected invalid utf8 response script")
          }
          assert_true(script.contains("globalThis[\"__lepusaInvokeResponse\"]"))
          assert_true(script.contains("\"id\":\"43\""))
          assert_true(script.contains("\\\"message\\\":\\\"ready\\\""))
        }
        Err(_) => abort("unexpected invalid bundled macOS plan")
      }
    Err(problem) => abort(problem)
  }
}

///|
test "macos protocol packet encodes virtual assets" {
  let json =
    #|{
    #|  "ok": true,
    #|  "url": "lepusa://runtime/bridge.js",
    #|  "mimeType": "application/javascript",
    #|  "body": { "kind": "virtual", "content": "console.log(\"ready\")" }
    #|}
  let packet = @utf8.decode(macos_protocol_packet_from_asset_json(json)) catch {
    _ => abort("unexpected invalid virtual packet")
  }
  assert_true(packet.has_prefix("ok\nvirtual\napplication/javascript\n"))
  assert_true(packet.contains("console.log"))
}

///|
test "macos protocol packet encodes file assets and errors" {
  let file_json =
    #|{
    #|  "ok": true,
    #|  "url": "lepusa://packaged/main/app.css",
    #|  "mimeType": "text/css",
    #|  "body": { "kind": "packaged-file", "path": "/tmp/app.css" }
    #|}
  let file_packet = @utf8.decode(
    macos_protocol_packet_from_asset_json(file_json),
  ) catch {
    _ => abort("unexpected invalid file packet")
  }
  assert_eq(file_packet, "ok\nfile\ntext/css\n/tmp/app.css")
  let error_packet = @utf8.decode(
    macos_protocol_packet_from_asset_json(
      "{\"ok\":false,\"error\":\"missing\"}",
    ),
  ) catch {
    _ => abort("unexpected invalid error packet")
  }
  assert_eq(error_packet, "error\nmissing")
}

///|
fn wb_bundled_macos_manifest() -> String {
  (
    #|{
    #|  "identifier": "dev.vectie.bundle",
    #|  "productName": "Bundled App",
    #|  "target": "macos",
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "macos",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Bundled App",
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "nativeHook": "__lepusaInvoke",
    #|      "initializationScripts": ["console.log(\"bridge ready\")"],
    #|      "allowedRoutes": ["log.write"]
    #|    }],
    #|    "protocolMappings": [
    #|      { "windowLabel": "main", "scheme": "lepusa", "root": "memory:main" }
    #|    ],
    #|    "virtualFiles": [
    #|      {
    #|        "windowLabel": "main",
    #|        "path": "index.html",
    #|        "mimeType": "text/html",
    #|        "content": "<main>bundled</main>"
    #|      }
    #|    ],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  )
}
