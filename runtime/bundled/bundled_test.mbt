///|
test "bundled runtime manifest summarizes launch data" {
  let manifest = sample_bundled_manifest()
  match BundledRuntimeManifest::parse("/app/lepusa/runtime.json", manifest) {
    Ok(runtime) => {
      assert_eq(runtime.bundle_root(), "/app")
      let summary = runtime.summary()
      assert_true(summary.contains("identifier: dev.vectie.runtime"))
      assert_true(summary.contains("product: Runtime App"))
      assert_true(summary.contains("target: linux"))
      assert_true(summary.contains("artifacts: 2"))
      assert_true(summary.contains("resources: 2"))
      assert_true(summary.contains("signing-configured: true"))
      assert_true(summary.contains("signing-prerequisites: 1"))
      assert_true(summary.contains("signing-steps: 1"))
      assert_true(
        summary.contains("first-window-url: lepusa://rabbita/main/index.html"),
      )
      assert_true(summary.contains("local-services: 1"))
      assert_true(summary.contains("service-supervisor: true"))
      assert_true(summary.contains("service-start-order: api"))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest exposes distribution envelope" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      assert_eq(runtime.artifact_jsons().length(), 2)
      assert_true(
        runtime.artifact_jsons()[0].contains("\"kind\":\"portable-directory\""),
      )
      assert_eq(runtime.resource_jsons().length(), 2)
      assert_true(runtime.resource_jsons()[0].contains("\"path\":\"assets\""))
      assert_true(runtime.signing_configured())
      assert_true(
        runtime.signing_json().contains("\"identity\":\"Developer ID\""),
      )
      assert_eq(runtime.signing_prerequisite_jsons().length(), 1)
      assert_true(
        runtime.signing_prerequisite_jsons()[0].contains("codesign identity"),
      )
      assert_eq(runtime.signing_step_jsons().length(), 1)
      assert_true(
        runtime.signing_step_jsons()[0].contains("\"tool\":\"codesign\""),
      )
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest exposes service plan" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) =>
      match runtime.service_plan() {
        Ok(plan) => {
          assert_eq(plan.services().length(), 1)
          assert_eq(plan.service_names()[0], "api")
          assert_eq(plan.startup_services().length(), 1)
          assert_eq(plan.startup_service_names()[0], "api")
          assert_true(plan.requires_supervisor())
          let supervisor = plan.supervisor_plan()
          assert_eq(supervisor.start_order().length(), 1)
          assert_eq(supervisor.start_order()[0], "api")
          assert_true(supervisor.startup_actions()[0] is StartLocalService(_))
          assert_true(
            supervisor.startup_actions()[1] is WaitLocalServiceReady(_),
          )
          assert_true(supervisor.shutdown_actions()[0] is StopLocalService(_))
          assert_true(plan.to_json().contains("\"requiresSupervisor\":true"))
        }
        Err(problem) => abort(problem)
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest builds target-aware run plan" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      assert_eq(runtime.target(), "linux")
      assert_eq(runtime.runtime_backend(), "headless")
      match runtime.run() {
        Ok(result) => {
          assert_true(result.status() is RunPrepared)
          let plan = result.plan()
          let report = result.report()
          assert_eq(plan.target(), "linux")
          assert_eq(plan.backend(), "linux")
          assert_eq(plan.webview_engine(), "WebKitGTK")
          assert_eq(plan.webviews().length(), 1)
          assert_true(plan.first_webview() is Some(_))
          assert_eq(plan.service_plan().startup_service_names()[0], "api")
          assert_eq(plan.startup_operation_count(), 2)
          assert_eq(plan.lifecycle_step_count(), 2)
          assert_eq(plan.sync_route_count(), 1)
          assert_eq(plan.async_route_count(), 0)
          assert_eq(report.target(), "linux")
          assert_eq(report.backend(), "linux")
          assert_eq(report.engine(), "WebKitGTK")
          assert_eq(report.status().name(), "prepared")
          assert_eq(report.first_window_title(), "Runtime App")
          assert_eq(
            report.first_window_url(),
            "lepusa://rabbita/main/index.html",
          )
          assert_eq(report.load_url(), "lepusa://rabbita/main/index.html")
          assert_eq(report.bridge_url(), "lepusa://runtime/bridge.js")
          assert_eq(report.local_services(), 1)
          assert_eq(report.service_start_order()[0], "api")
          assert_eq(report.startup_operations(), 2)
          assert_eq(report.bridge_sync_routes(), 1)
        }
        Err(problem) => abort(problem)
      }
      match runtime.run(mode=BundledOpenWindow) {
        Ok(result) =>
          match result.status() {
            RunUnsupported(message) =>
              assert_true(message.contains("WebKitGTK launch loop"))
            _ => abort("unexpected bundled launch status")
          }
        Err(problem) => abort(problem)
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime service plan validates service shape" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "localServices": [
    #|      { "name": "api", "command": ["moon", "run", "cmd/server"] }
    #|    ]
    #|  }
    #|}
  match BundledRuntimeManifest::parse("runtime.json", manifest) {
    Ok(runtime) =>
      match runtime.service_plan() {
        Ok(_) => abort("unexpected valid service plan")
        Err(problem) =>
          assert_eq(problem, "local service readiness url is required")
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest exposes first webview" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) =>
      match runtime.first_webview() {
        Ok(webview) => {
          assert_eq(webview.label(), "main")
          assert_eq(webview.title(), "Runtime App")
          assert_eq(webview.url(), "lepusa://rabbita/main/index.html")
          assert_eq(webview.width(), 1000)
          assert_eq(webview.height(), 720)
          assert_eq(webview.resizable(), true)
          assert_eq(webview.native_hook(), "__lepusaInvoke")
          assert_eq(webview.title_bar(), "native")
          assert_eq(webview.devtools(), false)
          assert_eq(webview.asset_protocol(), "lepusa")
          assert_eq(webview.bridge_global_name(), "lepusa")
          assert_eq(webview.event_dispatch_hook(), "__lepusaDispatchEvent")
          assert_eq(webview.allowed_routes()[0], "log.write")
          assert_eq(webview.initialization_scripts().length(), 1)
          assert_eq(runtime.webview_count(), 1)
        }
        Err(problem) => abort(problem)
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest emits bootstrap json" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      let bootstrap = runtime.bootstrap_json()
      assert_true(
        bootstrap.contains("\"manifestPath\":\"/app/lepusa/runtime.json\""),
      )
      assert_true(bootstrap.contains("\"bundleRoot\":\"/app\""))
      assert_true(bootstrap.contains("\"identifier\":\"dev.vectie.runtime\""))
      assert_true(bootstrap.contains("\"productName\":\"Runtime App\""))
      assert_true(bootstrap.contains("\"target\":\"linux\""))
      assert_true(bootstrap.contains("\"nativeBackend\":\"linux\""))
      assert_true(bootstrap.contains("\"webviewEngine\":\"WebKitGTK\""))
      assert_true(bootstrap.contains("\"runtime\":{"))
      assert_true(bootstrap.contains("\"webviewSpecs\""))
      assert_true(bootstrap.contains("\"allowedRoutes\":[\"log.write\"]"))
      assert_true(bootstrap.contains("\"capabilities\""))
      assert_true(bootstrap.contains("\"permissions\":[\"custom:log.write\"]"))
      assert_true(bootstrap.contains("\"startupOperations\""))
      assert_true(bootstrap.contains("\"kind\":\"start-service\""))
      assert_true(bootstrap.contains("\"kind\":\"run-effect\""))
      assert_true(bootstrap.contains("\"kind\":\"dispatch-event\""))
      assert_true(bootstrap.contains("\"script\":\"(() => {\\n"))
      assert_true(bootstrap.contains("\"lifecycleOperations\""))
      assert_true(bootstrap.contains("\"kind\":\"app-will-exit\""))
      assert_true(bootstrap.contains("\"bridgeRoutes\""))
      assert_true(bootstrap.contains("\"bridgeScheduler\""))
      assert_true(bootstrap.contains("\"mode\":\"sync-only\""))
      assert_true(bootstrap.contains("\"canLaunch\""))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest resolves protocol assets" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      let bridge = runtime.resolve_asset_json("lepusa://runtime/bridge.js")
      assert_true(bridge.contains("\"kind\":\"virtual\""))
      assert_true(bridge.contains("console.log"))
      let virtual_asset = runtime.resolve_asset_json(
        "lepusa://rabbita/main/index.html?v=1#top",
      )
      assert_true(virtual_asset.contains("\"mimeType\":\"text/html\""))
      assert_true(virtual_asset.contains("<main></main>"))
      let virtual_packet = @utf8.decode(
        runtime.resolve_asset_protocol_packet_bytes(
          @utf8.encode("lepusa://rabbita/main/index.html?v=1#top"),
        ),
      ) catch {
        _ => abort("unexpected invalid bundled asset packet")
      }
      assert_eq(virtual_packet, "ok\nvirtual\ntext/html\n<main></main>")
      match runtime.webviews() {
        Ok(webviews) =>
          match runtime.initial_load_url(webviews[0]) {
            Ok(load_url) =>
              assert_eq(load_url, "lepusa://rabbita/main/index.html")
            Err(problem) => abort(problem)
          }
        Err(problem) => abort(problem)
      }
      match runtime.webviews() {
        Ok(webviews) =>
          match
            runtime.webview_plan(
              webviews[0],
              initialization_script="/* bundled hook */",
            ) {
            Ok(webview) => {
              assert_eq(webview.label(), "main")
              assert_eq(webview.load_url(), "lepusa://rabbita/main/index.html")
              assert_eq(webview.initialization_script(), "/* bundled hook */")
              assert_eq(webview.asset_protocol(), "lepusa")
            }
            Err(problem) => abort(problem)
          }
        Err(problem) => abort(problem)
      }
      let local_asset = runtime.resolve_asset_json(
        "lepusa://local/static/app.css",
      )
      assert_true(local_asset.contains("\"path\":\"public/app.css\""))
      let packaged = runtime.resolve_asset_json(
        "lepusa://packaged/packaged/app.css",
      )
      assert_true(
        packaged.contains("\"path\":\"/app/lepusa/assets/packaged/app.css\""),
      )
      let unsafe_asset = runtime.resolve_asset_json(
        "lepusa://rabbita/main/../secret.txt",
      )
      assert_true(unsafe_asset.contains("\"ok\":false"))
      assert_true(unsafe_asset.contains("unsafe asset path"))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest owns bridge and asset callbacks" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      let dispatch = runtime.bridge_dispatch_callback()
      let message = "{\"id\":\"1\",\"window_label\":\"main\",\"plugin\":\"log\",\"command\":\"write\",\"payload\":\"{\\\"message\\\":\\\"ready\\\"}\"}"
      let script = @utf8.decode(dispatch(@utf8.encode(message))) catch {
        _ => abort("unexpected invalid bundled callback response")
      }
      assert_true(script.contains("__lepusaInvokeResponse"))
      assert_true(script.contains("\"id\":\"1\""))
      assert_true(script.contains("\\\"message\\\":\\\"ready\\\""))
      let resolve_asset = runtime.asset_protocol_resolver_callback()
      let packet = @utf8.decode(
        resolve_asset(@utf8.encode("lepusa://rabbita/main/index.html")),
      ) catch {
        _ => abort("unexpected invalid bundled asset callback response")
      }
      assert_eq(packet, "ok\nvirtual\ntext/html\n<main></main>")
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest prepares shared native run plans" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) =>
      match
        runtime.prepare_native_run_plan(target="linux", prepare_webview=fn(
          webview,
        ) {
          runtime.webview_plan(
            webview,
            initialization_script="/* bundled prepared hook */",
          )
        }) {
        Ok(plan) => {
          assert_eq(plan.bundled_webviews().length(), 1)
          assert_eq(plan.bundled_webviews()[0].label(), "main")
          assert_eq(plan.webview_count(), 1)
          assert_eq(
            plan.first_webview_url(),
            "lepusa://rabbita/main/index.html",
          )
          assert_eq(
            plan.first_webview_load_url(),
            "lepusa://rabbita/main/index.html",
          )
          assert_eq(plan.startup_operation_count(), 2)
          assert_eq(plan.lifecycle_step_count(), 2)
          assert_true(
            plan.bootstrap_json().contains("\"nativeBackend\":\"linux\""),
          )
          let supervisor = plan.service_supervisor_plan()
          assert_eq(supervisor.backend_name(), "linux")
          assert_eq(supervisor.webview_engine(), "WebKitGTK")
          assert_true(supervisor.requires_supervisor())
          assert_true(plan.service_supervisor_report().ok())
          match plan.first_webview() {
            Ok(webview) =>
              assert_eq(
                webview.initialization_script(),
                "/* bundled prepared hook */",
              )
            Err(problem) => abort(problem)
          }
          match plan.to_json() {
            Ok(artifact) => {
              assert_true(
                artifact.contains("\"kind\":\"bundled-native-run-plan\""),
              )
              assert_true(artifact.contains("\"source\":\"bundle\""))
              assert_true(artifact.contains("\"target\":\"linux\""))
              assert_true(artifact.contains("\"nativeBackend\":\"linux\""))
              assert_true(artifact.contains("\"launchSession\""))
              assert_true(artifact.contains("\"serviceSupervisor\""))
            }
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid bundled native run plan")
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled native run plans expose executable operation views" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      bundled_native_operation_manifest(),
    ) {
    Ok(runtime) =>
      match
        runtime.prepare_native_run_plan(target="linux", prepare_webview=fn(
          webview,
        ) {
          runtime.webview_plan(webview, initialization_script="")
        }) {
        Ok(plan) => {
          match plan.startup_executable_operations() {
            Ok(executable) => {
              assert_eq(executable.length(), 3)
              assert_eq(executable[0].kind(), "start-service")
              assert_eq(executable[0].service().unwrap().name(), "api")
              assert_eq(executable[1].kind(), "evaluate-script")
              assert_eq(executable[1].window_label().unwrap(), "main")
              assert_true(executable[1].to_json().contains("\"script\""))
              assert_eq(executable[2].kind(), "navigate-window")
              assert_eq(
                executable[2].navigation().unwrap().url(),
                "lepusa://rabbita/main/next.html",
              )
            }
            Err(problem) => abort(problem)
          }
          match plan.native_execution_plan() {
            Ok(execution) => {
              assert_eq(execution.startup_operations().length(), 3)
              assert_eq(
                execution.startup_operations()[1].kind(),
                "evaluate-script",
              )
              assert_true(
                execution.startup_operation_jsons()[2].contains(
                  "\"kind\":\"navigate-window\"",
                ),
              )
              assert_eq(execution.lifecycle_steps().length(), 2)
              assert_true(
                execution.lifecycle_steps()[1]
                .event_json()
                .contains("\"kind\":\"window-close-requested\""),
              )
            }
            Err(problem) => abort(problem)
          }
          match plan.launch_session() {
            Ok(session) => {
              assert_eq(session.webviews().length(), 1)
              assert_eq(session.execution().startup_operations().length(), 3)
              assert_true(session.service_supervisor().requires_supervisor())
              assert_false(session.bridge_scheduler().requires_async_dispatch())
              assert_true(session.to_json().contains("\"serviceSupervisor\""))
            }
            Err(problem) => abort(problem)
          }
          let scripts = plan.startup_evaluation_scripts()
          assert_eq(scripts.length(), 1)
          assert_eq(scripts[0].window_label(), "main")
          assert_true(scripts[0].script().contains("__lepusaDispatchEvent"))
          assert_true(scripts[0].script().contains("ready"))
          let navigations = plan.startup_navigations()
          assert_eq(navigations.length(), 1)
          assert_eq(navigations[0].window_label(), "main")
          assert_eq(navigations[0].url(), "lepusa://rabbita/main/next.html")
          match plan.native_lifecycle_steps() {
            Ok(steps) => {
              assert_eq(steps.length(), 2)
              assert_eq(steps[1].event().kind(), "window-close-requested")
              let lifecycle_executable = steps[1].executable_operations()
              assert_eq(lifecycle_executable.length(), 1)
              assert_eq(lifecycle_executable[0].kind(), "evaluate-script")
              let lifecycle_scripts = steps[1].evaluation_scripts()
              assert_eq(lifecycle_scripts.length(), 1)
              assert_true(lifecycle_scripts[0].script().contains("closing"))
              assert_eq(steps[1].navigations().length(), 0)
            }
            Err(problem) => abort(problem)
          }
        }
        Err(_) => abort("unexpected invalid bundled operation run plan")
      }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest selects lifecycle actions" {
  match
    BundledRuntimeManifest::parse(
      "/app/lepusa/runtime.json",
      sample_bundled_manifest(),
    ) {
    Ok(runtime) => {
      let startup = runtime.lifecycle_json(BundledLifecycleEvent::app_started())
      assert_true(startup.contains("\"name\":\"api\""))
      assert_true(startup.contains("\"name\":\"boot\""))
      let shutdown = runtime.lifecycle_json(
        BundledLifecycleEvent::app_will_exit(),
      )
      assert_true(shutdown.contains("\"name\":\"flush\""))
      assert_false(shutdown.contains("\"name\":\"api\""))
      match BundledLifecycleEvent::window_close_requested("main") {
        Ok(event) => {
          let close = runtime.lifecycle_json(event)
          assert_true(close.contains("\"label\":\"main\""))
          assert_true(close.contains("\"name\":\"closing\""))
        }
        Err(problem) => abort(problem)
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime manifest validates input shape" {
  assert_true(
    BundledRuntimeManifest::parse("runtime.json", "{}")
    is Err("runtime object is required"),
  )
  let invalid = BundledRuntimeManifest::parse("runtime.json", "{")
  assert_true(invalid is Err(_))
  assert_true(
    BundledLifecycleEvent::window_closed("")
    is Err("lifecycle window is required"),
  )
}

///|
async test "bundled runtime preserves official plugin state" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [
    #|      { "label": "main", "allowedRoutes": ["store.set", "store.get", "windowState.set", "windowState.get"] }
    #|    ],
    #|    "filesystemScopes": [],
    #|    "registeredRoutes": ["store.set", "store.get", "windowState.set", "windowState.get"]
    #|  }
    #|}
  match BundledRuntimeManifest::parse("runtime.json", manifest) {
    Ok(manifest) => {
      let runtime = BundledRuntime::new(manifest)
      let set = runtime.dispatch_json_async(
        id="set",
        window_label="main",
        route="store.set",
        payload="{\"key\":\"theme\",\"value\":\"dark\"}",
      )
      assert_true(set.contains("\"id\":\"set\""))
      let get = runtime.dispatch_json_async(
        id="get",
        window_label="main",
        route="store.get",
        payload="{\"key\":\"theme\"}",
      )
      assert_true(get.contains("\\\"value\\\":\\\"dark\\\""))
      assert_true(get.contains("\\\"found\\\":true"))
      let window_set = runtime.dispatch_json_async(
        id="window-set",
        window_label="main",
        route="windowState.set",
        payload="{\"window\":\"main\",\"width\":900,\"height\":640}",
      )
      assert_true(window_set.contains("\"id\":\"window-set\""))
      assert_true(window_set.contains("\\\"status\\\":\\\"set\\\""))
      let window_get = runtime.dispatch_json_async(
        id="window-get",
        window_label="main",
        route="windowState.get",
        payload="{\"window\":\"main\"}",
      )
      assert_true(window_get.contains("\\\"found\\\":true"))
      assert_true(window_get.contains("\\\\\\\"width\\\\\\\":900"))
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled runtime dispatches sync official plugins" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [
    #|      { "label": "main", "allowedRoutes": ["log.write", "fs.writeText"] }
    #|    ],
    #|    "filesystemScopes": [],
    #|    "registeredRoutes": ["log.write", "fs.writeText"]
    #|  }
    #|}
  match BundledRuntimeManifest::parse("runtime.json", manifest) {
    Ok(manifest) => {
      let sync_routes = manifest.registered_sync_routes()
      assert_eq(sync_routes.length(), 1)
      assert_eq(sync_routes[0], "log.write")
      let async_routes = manifest.registered_async_routes()
      assert_eq(async_routes.length(), 1)
      assert_eq(async_routes[0], "fs.writeText")
      let log = manifest.dispatch_json(
        id="log",
        window_label="main",
        route="log.write",
        payload="{\"message\":\"ready\"}",
      )
      assert_true(log.contains("\"id\":\"log\""))
      assert_true(log.contains("\\\"message\\\":\\\"ready\\\""))
      let async_only = manifest.dispatch_json(
        id="write",
        window_label="main",
        route="fs.writeText",
        payload="{\"scope\":\"data\",\"path\":\"note.txt\",\"content\":\"hello\"}",
      )
      assert_true(
        async_only.contains("command requires async dispatch: fs.writeText"),
      )
    }
    Err(problem) => abort(problem)
  }
}

///|
async test "bundled runtime owns bridge message transport" {
  let manifest =
    #|{
    #|  "runtime": {
    #|    "webviews": [
    #|      {
    #|        "label": "main",
    #|        "url": "lepusa://rabbita/main/index.html",
    #|        "nativeHook": "__lepusaInvoke",
    #|        "allowedRoutes": ["store.set", "store.get", "log.write", "fs.writeText"]
    #|      }
    #|    ],
    #|    "filesystemScopes": [],
    #|    "registeredRoutes": ["store.set", "store.get", "log.write", "fs.writeText"]
    #|  }
    #|}
  match BundledRuntimeManifest::parse("runtime.json", manifest) {
    Ok(manifest) => {
      let scheduler = manifest.bridge_scheduler()
      assert_true(scheduler.requires_async_dispatch())
      assert_false(scheduler.can_launch())
      assert_eq(scheduler.sync_routes().length(), 3)
      assert_eq(scheduler.async_routes().length(), 1)
      assert_eq(scheduler.async_routes()[0], "fs.writeText")
      let async_capable = manifest.bridge_scheduler(
        mode=NativeBridgeAsyncCapable,
      )
      assert_true(async_capable.can_launch())
      match manifest.bridge_response_hook(window_label="main") {
        Ok((window_label, hook)) => {
          assert_eq(window_label, "main")
          assert_eq(hook, "__lepusaInvokeResponse")
        }
        Err(problem) => abort(problem)
      }
      let runtime = BundledRuntime::new(manifest)
      let sync_message = "{\"id\":\"log\",\"window_label\":\"main\",\"plugin\":\"log\",\"command\":\"write\",\"payload\":\"{\\\"message\\\":\\\"ready\\\"}\"}"
      match runtime.dispatch_bridge_message_sync(sync_message) {
        Ok(dispatch) => {
          assert_eq(dispatch.window_label(), "main")
          assert_eq(dispatch.response_hook(), "__lepusaInvokeResponse")
          assert_true(dispatch.response_json().contains("\"id\":\"log\""))
          assert_true(
            dispatch
            .evaluation_script()
            .contains("globalThis[\"__lepusaInvokeResponse\"]"),
          )
        }
        Err(_) => abort("unexpected bundled sync bridge failure")
      }
      let sync_script = @utf8.decode(
        runtime.dispatch_bridge_script_bytes(@utf8.encode(sync_message)),
      ) catch {
        _ => abort("unexpected invalid bundled bridge script")
      }
      assert_true(
        sync_script.contains("globalThis[\"__lepusaInvokeResponse\"]"),
      )
      assert_true(sync_script.contains("\"id\":\"log\""))
      let set_message = "{\"id\":\"set\",\"window_label\":\"main\",\"plugin\":\"store\",\"command\":\"set\",\"payload\":\"{\\\"key\\\":\\\"theme\\\",\\\"value\\\":\\\"dark\\\"}\"}"
      let get_message = "{\"id\":\"get\",\"window_label\":\"main\",\"plugin\":\"store\",\"command\":\"get\",\"payload\":\"{\\\"key\\\":\\\"theme\\\"}\"}"
      let set_script = @utf8.decode(
        manifest.bridge_async_dispatch_callback()(@utf8.encode(set_message)),
      ) catch {
        _ => abort("unexpected invalid bundled async bridge script")
      }
      assert_true(set_script.contains("globalThis[\"__lepusaInvokeResponse\"]"))
      assert_true(set_script.contains("\"id\":\"set\""))
      match runtime.dispatch_bridge_message(set_message) {
        Ok(dispatch) =>
          assert_true(dispatch.response_json().contains("\"id\":\"set\""))
        Err(_) => abort("unexpected bundled async set failure")
      }
      match runtime.dispatch_bridge_message(get_message) {
        Ok(dispatch) => {
          assert_true(dispatch.response_json().contains("\"id\":\"get\""))
          assert_true(dispatch.response_json().contains("\\\"found\\\":true"))
          assert_true(
            dispatch.response_json().contains("\\\"value\\\":\\\"dark\\\""),
          )
        }
        Err(_) => abort("unexpected bundled async get failure")
      }
    }
    Err(problem) => abort(problem)
  }
}

///|
test "bundled bridge transport validates target window" {
  match
    BundledRuntimeManifest::parse(
      "runtime.json",
      (
        #|{
        #|  "runtime": {
        #|    "webviews": [
        #|      {
        #|        "label": "main",
        #|        "url": "lepusa://rabbita/main/index.html",
        #|        "allowedRoutes": ["log.write"]
        #|      }
        #|    ],
        #|    "registeredRoutes": ["log.write"]
        #|  }
        #|}
      ),
    ) {
    Ok(manifest) =>
      match
        manifest.prepare_bridge_message(
          "{\"id\":\"missing\",\"window_label\":\"other\",\"plugin\":\"log\",\"command\":\"write\"}",
        ) {
        Ok(_) => abort("unexpected bundled bridge prepare success")
        Err(problems) =>
          assert_eq(problems[0], "bundled bridge window not found: other")
      }
    Err(problem) => abort(problem)
  }
}

///|
fn sample_bundled_manifest() -> String {
  (
    #|{
    #|  "identifier": "dev.vectie.runtime",
    #|  "productName": "Runtime App",
    #|  "target": "linux",
    #|  "artifacts": [
    #|    {
    #|      "kind": "portable-directory",
    #|      "path": "dist/runtime-app"
    #|    },
    #|    {
    #|      "kind": "desktop-entry",
    #|      "path": "dist/runtime-app.desktop"
    #|    }
    #|  ],
    #|  "resources": [
    #|    { "kind": "asset-dir", "path": "assets" },
    #|    { "kind": "runtime-manifest", "path": "lepusa/runtime.json" }
    #|  ],
    #|  "signing": {
    #|    "identity": "Developer ID",
    #|    "notarize": false
    #|  },
    #|  "signingPrerequisites": [
    #|    "codesign identity Developer ID"
    #|  ],
    #|  "signingSteps": [
    #|    {
    #|      "name": "sign executable",
    #|      "tool": "codesign",
    #|      "command": "codesign --sign Developer ID runtime-app"
    #|    }
    #|  ],
    #|  "runtime": {
    #|    "assetProtocol": "lepusa",
    #|    "backend": "headless",
    #|    "bridgeUrl": "lepusa://runtime/bridge.js",
    #|    "webviews": [{
    #|      "label": "main",
    #|      "title": "Runtime App",
    #|      "url": "lepusa://rabbita/main/index.html",
    #|      "allowedRoutes": ["log.write"],
    #|      "initializationScripts": ["console.log(\"bridge\")"]
    #|    }],
    #|    "protocolMappings": [
    #|      { "windowLabel": "main", "scheme": "lepusa", "root": "memory:main" },
    #|      { "windowLabel": "static", "scheme": "lepusa", "root": "public" },
    #|      { "windowLabel": "packaged", "scheme": "lepusa", "root": "package:lepusa/assets/packaged" }
    #|    ],
    #|    "virtualFiles": [
    #|      {
    #|        "windowLabel": "main",
    #|        "path": "index.html",
    #|        "mimeType": "text/html",
    #|        "content": "<main></main>"
    #|      }
    #|    ],
    #|    "capabilities": [
    #|      {
    #|        "name": "main-log",
    #|        "windows": ["main"],
    #|        "permissions": ["custom:log.write"]
    #|      }
    #|    ],
    #|    "localServices": [
    #|      {
    #|        "name": "api",
    #|        "command": ["moon", "run", "cmd/server"],
    #|        "readinessUrl": "http://127.0.0.1:4317/ready"
    #|      }
    #|    ],
    #|    "startupActions": [
    #|      { "kind": "effect", "name": "boot" }
    #|    ],
    #|    "lifecycleHooks": [
    #|      {
    #|        "event": { "kind": "app-will-exit" },
    #|        "actions": [{ "kind": "effect", "name": "flush" }]
    #|      },
    #|      {
    #|        "event": { "kind": "window-close-requested", "label": "main" },
    #|        "actions": [{
    #|          "kind": "emit",
    #|          "target": { "kind": "window", "label": "main" },
    #|          "event": { "name": "closing" }
    #|        }]
    #|      }
    #|    ],
    #|    "commandRoutes": ["log.write"],
    #|    "registeredRoutes": ["log.write"]
    #|  }
    #|}
  )
}

///|
fn bundled_native_operation_manifest() -> String {
  sample_bundled_manifest().replace_all(
    old=(
      #|    "startupActions": [
      #|      { "kind": "effect", "name": "boot" }
      #|    ]
    ),
    new=(
      #|    "startupActions": [
      #|      {
      #|        "kind": "emit",
      #|        "target": { "kind": "window", "label": "main" },
      #|        "event": { "name": "ready", "payload": "{}" }
      #|      },
      #|      {
      #|        "kind": "navigate",
      #|        "windowLabel": "main",
      #|        "url": "lepusa://rabbita/main/next.html"
      #|      }
      #|    ]
    ),
  )
}
