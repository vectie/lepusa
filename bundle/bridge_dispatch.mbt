///|
async fn verify_bridge_dispatch(path : String) -> BundleWriteCheck {
  let content = @fs.read_file(path) catch {
    error =>
      return BundleWriteCheck::new(
        kind=BridgeDispatchCheck,
        path~,
        ok=false,
        message="could not read runtime manifest: \{error}",
      )
  }
  let text = content.text()
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) =>
      match select_bridge_smoke_route(manifest) {
        Ok(Some(smoke)) => run_bridge_smoke(manifest, smoke, path)
        Ok(None) =>
          BundleWriteCheck::new(
            kind=BridgeDispatchCheck,
            path~,
            ok=true,
            message="bridge dispatch skipped: no built-in sync route",
          )
        Err(problem) =>
          BundleWriteCheck::new(
            kind=BridgeDispatchCheck,
            path~,
            ok=false,
            message=problem,
          )
      }
    Err(problem) =>
      BundleWriteCheck::new(
        kind=BridgeDispatchCheck,
        path~,
        ok=false,
        message="runtime manifest parse failed: \{problem}",
      )
  }
}

///|
struct BridgeSmokeRoute {
  window_label : String
  route : String
  payload : String
} derive(Debug, Eq)

///|
fn run_bridge_smoke(
  manifest : @bundled.BundledRuntimeManifest,
  smoke : BridgeSmokeRoute,
  path : String,
) -> BundleWriteCheck {
  let runtime = @bundled.BundledRuntime::new(manifest)
  let message = bridge_smoke_message(smoke)
  match runtime.dispatch_bridge_message_sync(message) {
    Ok(dispatch) => {
      let ok = dispatch
        .response_json()
        .contains("\"id\":\"bundle-bridge-smoke\"") &&
        !dispatch.response_json().contains("\"error\":") &&
        dispatch.evaluation_script().contains(dispatch.response_hook())
      BundleWriteCheck::new(
        kind=BridgeDispatchCheck,
        path~,
        ok~,
        message=if ok {
          "bridge dispatch verified: \{smoke.route}"
        } else {
          "bridge dispatch returned unusable response: \{smoke.route}"
        },
      )
    }
    Err(problems) =>
      BundleWriteCheck::new(
        kind=BridgeDispatchCheck,
        path~,
        ok=false,
        message="bridge dispatch failed: \{problems.join("; ")}",
      )
  }
}

///|
fn select_bridge_smoke_route(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[BridgeSmokeRoute?, String] {
  match manifest.webviews() {
    Err(problem) => Err("runtime manifest webviews invalid: \{problem}")
    Ok(webviews) => {
      let sync_routes = manifest.registered_sync_routes()
      for webview in webviews {
        for route in sync_routes {
          match bridge_smoke_payload(route) {
            Some(payload) =>
              if webview.allowed_routes().contains(route) {
                return Ok(
                  Some({ window_label: webview.label(), route, payload }),
                )
              }
            None => ()
          }
        }
      }
      Ok(None)
    }
  }
}

///|
fn bridge_smoke_message(smoke : BridgeSmokeRoute) -> String {
  match route_parts(smoke.route) {
    Some((plugin, command)) =>
      [
        "{",
        "\"id\":\"bundle-bridge-smoke\",",
        "\"window_label\":\{smoke.window_label.json_string()},",
        "\"plugin\":\{plugin.json_string()},",
        "\"command\":\{command.json_string()},",
        "\"payload\":\{smoke.payload.json_string()}",
        "}",
      ].join("")
    None => ""
  }
}

///|
fn bridge_smoke_payload(route : String) -> String? {
  match route {
    "app.info" | "app.name" | "app.version" | "app.identifier" => Some("{}")
    "autoLaunch.status" => Some("{}")
    "clipboard.readText" => Some("{}")
    "deepLink.getInitialUrls" => Some("{}")
    "log.write" => Some("{\"message\":\"bundle bridge smoke\"}")
    "notification.permissionState" => Some("{}")
    "process.info" | "process.cwd" => Some("{}")
    "serviceDiscovery.list" | "serviceDiscovery.status" => Some("{}")
    "singleInstance.status" => Some("{}")
    "store.keys" => Some("{}")
    "windowState.get" => Some("{\"window\":\"main\"}")
    _ => None
  }
}

///|
fn route_parts(route : String) -> (String, String)? {
  let parts : Array[String] = []
  for part in route.split(".") {
    parts.push(part.to_owned())
  }
  if parts.length() == 2 && parts[0] != "" && parts[1] != "" {
    Some((parts[0], parts[1]))
  } else {
    None
  }
}
