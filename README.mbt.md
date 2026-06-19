# Lepusa

Lepusa is a standalone MoonBit desktop application framework.

The core decision is to build a MoonBit-owned, Tauri-shaped framework on top of
system WebViews, with an app-authoring style close to Rabbita. Tauri and Lepus
are references to learn from, not runtime layers that app authors must carry.

Start with:

- [Research Decision](docs/DESKTOP_FRAMEWORK_RESEARCH.md)
- [Architecture Plan](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)

## Intended Shape

```text
MoonBit app code
  -> Rabbita-style Lepusa app syntax
  -> typed command + event IPC
  -> capability-scoped platform plugins
  -> system WebView runtime
  -> platform bundles for macOS, Windows, and Linux
```

The first implementation slice already owns the public MoonBit foundation:

- Rabbita-style `cell_with_dispatch` and `new(cell)` app construction
- `WindowConfig`, `Source`, `Plugin`, `Capability`, `Cmd`, `Event`, and typed
  IPC request/response contracts
- `ProjectManifest` validation plus `LaunchPlan`, `RuntimePlan`, and
  `BundlePlan` generation as the boundaries native runtime and platform
  bundler code will consume next
- `@lepusa/runtime` host/session snapshots that native WebView backends can
  consume without reinterpreting app configuration

The common authoring path is intentionally small:

```moonbit nocheck
///|
fn main {
  let (dispatch, cell) = @lepusa.cell_with_dispatch(
    model=init_model(),
    update~,
    view=(dispatch, model) => render_app(dispatch, model),
  )
  let app = @lepusa.new(cell)
    .with_startup(load_initial_state(dispatch))
    .on_shutdown(persist_state(dispatch))
    .window(title="Hello Lepusa", width=1000, height=720)
  match app.launch_plan() {
    Ok(plan) => boot_native_runtime(plan)
    Err(problems) => fail_fast(problems)
  }
}
```

For backend and packaging work, the app model can be lowered without pulling in
product-specific code:

```moonbit nocheck
///|
let runtime = app.runtime_plan(config=@lepusa.RuntimeConfig::system_webview())

///|
let bundle = @lepusa.BundleConfig::new(
  @lepusa.AppMetadata::new(
    identifier="dev.example.app",
    product_name="Example App",
    version="0.1.0",
  ),
)
```

For reusable project configuration, use `ProjectManifest`:

```moonbit nocheck
///|
let manifest = @lepusa.ProjectManifest::new(metadata)
  .with_window(
    @lepusa.WindowConfig::new(source=@lepusa.Source::local_path("dist")),
  )
  .with_plugin(@lepusa.Plugin::new("core").command_sync("invoke"))
  .with_capability(
    @lepusa.Capability::new("main").window("main").command("core.invoke"),
  )

///|
let runtime = manifest.runtime_plan(root)

///|
let bundle = manifest.bundle_plan(root, target=@lepusa.MacOS)
```

## CLI

The native CLI is intentionally small while the runtime backend is being built:

```bash
moon run cmd/main --target native -- doctor
moon run cmd/main --target native -- plan
moon run cmd/main --target native -- manifest
moon run cmd/main --target native -- native-plan macos
moon run cmd/main --target native -- bridge
moon run cmd/main --target native -- dev
moon run cmd/main --target native -- init _build/lepusa-app
moon run cmd/main --target native -- plan --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- manifest --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- native-plan linux --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- dev --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- plugin new file-dialog _build/lepusa-plugin-file-dialog
moon run cmd/main --target native -- bundle-plan macos
moon run cmd/main --target native -- bundle-write linux _build/lepusa-bundle --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- build macos _build/lepusa-build --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bundle windows _build/lepusa-bundle-win
```

These commands exercise the public planning contracts and give the native
runtime and bundler work concrete outputs to consume.

`lepusa doctor` checks the portable runtime plan and reports host WebView
availability for the platform backend descriptors: WKWebView on macOS, WebView2
on Windows, and WebKitGTK on Linux.

`lepusa plan` includes resolved WebView load URLs, so backend work can consume
`RuntimePlan::windows()` directly.

Generated bridges only expose command routes granted to the current window by
capabilities. `RuntimePlan::command_routes()` still reports all declared plugin
routes for metadata and bundling.

Lifecycle hooks lower to the same backend action model as startup commands, so
platform backends can handle shutdown and window-close events without reading
application construction state.

When a window omits `source`, `App` lowers the root `Cell` into a generated
Rabbita-style HTML document served from the runtime manifest as a virtual file.

`lepusa init` writes a standalone MoonBit project skeleton that imports
`vectie/lepusa` directly. It is intentionally small: `moon.mod`, `moon.pkg`,
`lepusa.json`, `main.mbt`, and `README.mbt.md`.

`lepusa.json` is the app-neutral project boundary. It describes metadata,
runtime backend, windows, plugin command routes, command permission
requirements, capability grants, bundle icon resources, and bundle signing
prerequisites. Native CLI commands consume the nearest `lepusa.json` from the
current directory, or a file passed with `--project`.
Official plugins can be declared by name, for example
`{ "name": "autoLaunch" }`, `{ "name": "clipboard" }`,
`{ "name": "deepLink" }`, `{ "name": "dialog" }`, `{ "name": "fileDialog" }`,
`{ "name": "localhost" }`, `{ "name": "notification" }`, `{ "name": "log" }`,
`{ "name": "opener" }`, `{ "name": "process" }`, `{ "name": "shell" }`,
`{ "name": "singleInstance" }`, `{ "name": "store" }`,
`{ "name": "tray" }`, or `{ "name": "fs" }`;
Lepusa expands those declarations to the package's
official command contract. Custom plugins can still provide an explicit
`commands` array.
Projects can also declare `filesystemScopes`, named roots that are carried into
runtime sessions and native launch manifests for backend enforcement.
It also describes runtime behavior through `startup` and `lifecycle` commands:
`effect`, `emit`, `navigate`, and `batch` map directly to the portable
`RuntimeAction` model consumed by native backends.
When a project declares official `log` or `store` plugins, the CLI binds their
MoonBit-native handlers into the project `RuntimeHost` without adding
moon-suite-specific behavior.

`lepusa plugin new` writes a standalone plugin skeleton with plugin metadata,
native command registration, and a scoped capability helper.

`BundlePlan::signing_prerequisites()` exposes target-specific distribution
requirements for macOS, Windows, and Linux. The generated bundle runtime file
includes those prerequisites so future signing, notarization, and installer
steps can consume one bundle contract.

`BundlePlan::resources()` exposes planned bundle resource mappings such as the
application icon. The generated bundle runtime file includes these mappings
under `resources`, and `lepusa bundle-write` copies them as file data next to
generated bundle files without re-reading project configuration.

`@lepusa/plugins/log` is the first official plugin package. It declares
`log.write`, provides scoped capability helpers, and can register a command
handler backed by an in-memory `LogBuffer`:

```moonbit nocheck
///|
let buffer = @log.LogBuffer::new()

///|
let registry = @log.registry(buffer~)

///|
let app = @lepusa.new(root)
  .with_plugin(@log.plugin())
  .with_capability(@log.capability_for_window("main"))
```

`@lepusa/plugins/store` follows the same shape for scoped key-value state. It
declares `store.get`, `store.set`, `store.delete`, `store.clear`, and
`store.keys`, backed by a MoonBit `Store`.

`@lepusa/plugins/fs` defines the official filesystem command contract and
scoped path policy. It declares async routes such as `fs.readText`,
`fs.writeText`, `fs.list`, and `fs.metadata`, plus split read/write capability
helpers. The package validates named scopes and relative paths; native backends
own the actual OS filesystem implementation behind those routes.
Core `FileSystemScope` values carry named roots through `ProjectManifest`,
`RuntimePlan`, `RuntimeSession`, and `RuntimeLaunchManifest`.

`@lepusa/plugins/file_dialog` defines file picker routes such as
`fileDialog.openFile` and `fileDialog.saveFile`, plus scoped default-directory
policy that points dialogs at declared filesystem scopes without widening core
filesystem access.

`@lepusa/plugins/localhost` defines local service lifecycle routes such as
`localhost.status`, `localhost.start`, `localhost.stop`, and
`localhost.waitUntilReady`, plus service metadata policy. Native backends own
process supervision and readiness probing.

`@lepusa/plugins/deep_link` defines app URL scheme routes such as
`deepLink.getInitialUrls`, `deepLink.onOpenUrl`, and `deepLink.openUrl`, plus
scheme/host policy metadata. Native backends own OS registration and dispatch.

`@lepusa/plugins/single_instance` defines app lock and launch handoff routes
such as `singleInstance.acquire`, `singleInstance.focus`, and
`singleInstance.onSecondLaunch`, plus instance-key policy metadata. Native
backends own cross-process locking and platform window activation.

`@lepusa/plugins/tray` defines system tray routes such as `tray.setIcon`,
`tray.setMenu`, `tray.setVisible`, and `tray.onMenuItemClick`, plus menu item
policy metadata. Native backends own status icon creation and OS menu behavior.

`@lepusa/plugins/auto_launch` defines launch-at-login routes such as
`autoLaunch.status`, `autoLaunch.enable`, `autoLaunch.disable`, and
`autoLaunch.setEnabled`, plus startup registration policy metadata. Native
backends own platform login item, registry, service, or desktop-entry behavior.

`@lepusa/plugins/dialog` defines platform-neutral dialog routes:
`dialog.message`, `dialog.confirm`, and `dialog.prompt`. Native backends own the
actual OS dialog implementation.

`@lepusa/plugins/clipboard` and `@lepusa/plugins/notification` declare the
platform-neutral clipboard and notification routes. Native backends own system
clipboard and OS notification integration.

`@lepusa/plugins/opener` declares platform-neutral URL and path opener routes:
`opener.openUrl`, `opener.openPath`, and `opener.revealPath`. Native backends
own the platform-specific open/reveal implementation.

`@lepusa/plugins/shell` declares explicit shell execution and process lifecycle
routes. Native backends own execution, process tracking, and platform-specific
restrictions.

`@lepusa/plugins/process` declares process metadata, environment, and control
routes behind split `process.info`, `process.environment`, and
`process.control` permissions. Native backends own the OS process behavior.

`@lepusa/plugins/catalog` centralizes official plugin lookup for framework
tooling. Project parsing uses it to expand name-only official plugin
declarations and bind pure MoonBit handlers where they exist.

`lepusa manifest` emits the portable native-runner JSON from
`RuntimeHost::launch_manifest()`: WebView boot data, bridge hook names,
document-start scripts, protocol mappings, inline virtual files with MIME
types, declared command routes, and registered native routes.

`lepusa native-plan [macos|windows|linux]` emits the selected backend's
`NativeRunnerPlan::bootstrap_json()`, including the portable runtime manifest,
per-window WebView specs, and startup operations that a platform runner needs.

`@lepusa/runtime` turns a `RuntimePlan` into a `RuntimeSession`: resolved
window frames, protocol mappings, virtual files, generated bridge source, and
command dispatch through the declared capabilities.
`NativeRunnerPlan` keeps full per-window `RuntimeWebViewSpec` records alongside
the portable launch manifest so backend implementations can create windows
without re-deriving bridge hooks or initialization scripts.
It also exposes lifecycle steps from the current `RuntimeSession`, giving native
backends shutdown and window-event operations without retaining app construction
state.

`RuntimeSession::resolve_asset(url)` is the pure custom-protocol boundary for
native WebViews. It resolves `lepusa://runtime/bridge.js`, inline/Rabbita
virtual files, and safe local asset paths without doing platform file IO.

`RuntimeHost::dispatch_json(input)` is the native hook boundary for WebView IPC.
It decodes the bridge request object, verifies the route is declared by the
runtime plan, checks capabilities through the command registry, and returns the
JSON response shape expected by `window.lepusa`.

`lepusa invoke <window> <plugin.command> [payload] --project lepusa.json`
executes the same host dispatch path from the CLI. It is a native smoke-test
tool for project configuration, official plugin registration, and capability
grants.

The generated bridge also exposes `window.lepusa.listen(name, handler)` and
installs `globalThis.__lepusaDispatchEvent(event)` for native-to-frontend
events.

`RuntimePlan::actions(cmd)` lowers `Cmd::emit`, `Cmd::navigate`, and
`Cmd::effect` into backend-executable `RuntimeAction` values. Startup actions
are included in `RuntimePlan::launch_manifest()`.

`RuntimeHost::webviews()` produces per-window boot specs for native backends:
window frame data, load URL, asset protocol, native hook name, and document
start scripts.

`lepusa bridge` emits the JavaScript bridge that frontends load as
`window.lepusa`, including `invoke(route, payload)` and route namespaces such as
`lepusa.core.invoke(payload)`.

`lepusa dev` lowers the current project into a runtime development plan:
resolved WebViews, asset protocol, capability-filtered routes, runtime session,
and startup operations. This is the stable boundary the platform-specific
window loops will execute.

`RuntimeHost::runner_plan()` is the platform-neutral native-loop contract:
launch manifest, resolved WebViews, stepped runtime session, and startup
operations in one object. Platform packages map this plan to WKWebView,
WebView2, or WebKitGTK without rebuilding app state.

`@lepusa/runtime` also exposes `NativeBackend`, the shared lowering boundary
for platform packages. `@lepusa/runtime/macos`, `@lepusa/runtime/windows`, and
`@lepusa/runtime/linux` now provide small backend descriptors and host
availability checks for WKWebView, WebView2, and WebKitGTK while reusing the
same portable runner plan.

`Source::localhost(...)` supports gateway-style apps that load a local HTTP
service and optionally declare the sidecar command plus readiness URL metadata.
This data appears in `RuntimeSession::local_services()` and launch-manifest
`localServices` for native runners to supervise.

`lepusa bundle-plan` now also validates concrete bundle artifact plans through
`BundlePlan::files()`: platform metadata plus `lepusa/runtime.json`, with
per-window bridge initialization scripts embedded in the runtime manifest.

`lepusa bundle-write` materializes those planned files under an output
directory. Project bundles carry registered official plugin routes into
`lepusa/runtime.json`, so packaged runtime data matches the same host path used
by `lepusa manifest`, `lepusa dev`, and `lepusa invoke`.

## Boundary

Lepusa owns the reusable desktop framework:

- native window and WebView runtime
- frontend-to-MoonBit command bridge
- app capabilities and permissions
- official platform plugins
- dev/build/bundle CLI

Consumer projects own product behavior, backend services, schemas, routes,
workspaces, dashboards, and domain-specific adapters.
