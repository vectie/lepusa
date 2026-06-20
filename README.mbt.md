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
- `@lepusa/ui` HTML helpers plus `UiProgram` model/update/view state flow for
  compact MoonBit-authored desktop views
- `WindowConfig`, `Source`, `Plugin`, `Capability`, `Cmd`, `Event`, and typed
  IPC request/response contracts
- `ProjectManifest` validation plus `LaunchPlan`, `RuntimePlan`, and
  `BundlePlan` generation as the boundaries native runtime and platform
  bundler code will consume next
- `@lepusa/project` parsing for standalone `lepusa.json` app manifests,
  including official plugin expansion and capability-scoped command routing
- `@lepusa/bundle` native bundle materialization from `BundlePlan` without
  coupling build tools to CLI internals
- `@lepusa/scaffold` app and plugin skeleton generation for ecosystem tooling
  without shelling through `lepusa init`
- `@lepusa/desktop` app-facing official plugin kit that keeps plugin
  declarations, capability grants, and runtime command handlers in sync
- `@lepusa/runtime` host/session snapshots that native WebView backends can
  consume without reinterpreting app configuration
- `@lepusa/runtime.NativeRuntime` as the single native-loop facade over backend
  bootstrap, asset protocol responses, IPC dispatch, and lifecycle steps

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

The optional `@lepusa/ui` package supplies concise view helpers while still
returning root `@lepusa.Html` values:

```moonbit nocheck
///|
fn render_app(dispatch, model) {
  @ui.main_([
    @ui.h1([@ui.text("Counter")]),
    @ui.p([@ui.text("Count: \{model.count}")], attrs=[@ui.class_name("metric")]),
    @ui.p([@ui.text("Starting")], attrs=[@ui.id("status")]),
    @ui.button("Increment", attrs=[@ui.on_click("counter.increment")]),
    @ui.text_listener("ready", "#status"),
  ])
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

For official desktop APIs, `@lepusa/desktop.DesktopProject` wires the
framework parts together:

```moonbit nocheck
///|
let project = @desktop.DesktopProject::new(metadata, root)
  .window(title="Desk", source=@lepusa.Source::html("<main></main>"))
  .with_sync_plugins()

///|
let host = project.runtime_host().unwrap()

///|
let bundle = project.bundle_plan(target=@lepusa.MacOS).unwrap()
```

For programmatic project configuration, use `ProjectManifest`:

```moonbit nocheck
///|
let manifest = @lepusa.ProjectManifest::new(metadata)
  .with_window(
    @lepusa.WindowConfig::new(source=@lepusa.Source::packaged("dist")),
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

For file-backed apps, `@lepusa/project` owns reusable `lepusa.json` loading and
parsing:

```moonbit nocheck
///|
match @project.ProjectConfig::load("lepusa.json") {
  Ok(project) =>
    project.manifest().runtime_plan(project.root())
  Err(problems) =>
    fail_fast(problems)
}
```

## CLI

The native CLI is intentionally small while the runtime backend is being built:

```bash
moon run cmd/main --target native -- doctor linux
moon run cmd/main --target native -- plan
moon run cmd/main --target native -- manifest
moon run cmd/main --target native -- native-plan macos
moon run cmd/main --target native -- launch-session linux
moon run cmd/main --target native -- launch-session linux --async-bridge
moon run cmd/main --target native -- run linux --project examples/gateway/lepusa.json
moon run cmd/main --target native -- run linux --json --project examples/gateway/lepusa.json
moon run cmd/main --target native -- verify linux --project examples/static/lepusa.json
moon run cmd/main --target native -- verify linux --strict --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- run macos --launch --project examples/static/lepusa.json
moon run cmd/main --target native -- bridge
moon run cmd/main --target native -- dev
moon run cmd/main --target native -- init _build/lepusa-app
moon run cmd/main --target native -- init _build/lepusa-app --workspace /Users/kq/Workspace/lepusa
moon run cmd/main --target native -- plan --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- manifest --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- native-plan linux --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- launch-session linux --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- dev --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- asset lepusa://rabbita/main/index.html --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- lifecycle app-will-exit --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bridge-task main log.write '{"message":"ready"}' --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bridge-handoff main log.write '{"message":"ready"}' --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bridge-complete main fs.readText '{"scope":"data","path":"note.txt"}' --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bridge-dispatch main log.write '{"message":"ready"}' --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bridge-loop main fs.readText '{"scope":"data","path":"note.txt"}' --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bridge-drain main fs.readText '{"scope":"data","path":"note.txt"}' --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- plugin new file-dialog _build/lepusa-plugin-file-dialog
moon run cmd/main --target native -- plugin new file-dialog _build/lepusa-plugin-file-dialog --workspace /Users/kq/Workspace/lepusa
moon run cmd/main --target native -- bundle-plan macos
moon run cmd/main --target native -- bundle-plan macos --json
moon run cmd/main --target native -- bundle-write linux _build/lepusa-bundle --project _build/lepusa-app/lepusa.json
moon run cmd/runtime --target native -- --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- run --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- launch --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- bootstrap --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- launch-session --async-bridge --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- asset lepusa://packaged/main/index.html --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- lifecycle app-started --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- bridge-task main log.write '{"message":"ready"}' --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- bridge-handoff main log.write '{"message":"ready"}' --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- bridge-complete main fs.readText '{"scope":"data","path":"note.txt"}' --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- bridge-dispatch main log.write '{"message":"ready"}' --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- bridge-loop main fs.readText '{"scope":"data","path":"note.txt"}' --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- bridge-drain main fs.readText '{"scope":"data","path":"note.txt"}' --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/runtime --target native -- invoke main log.write '{"message":"ready"}' --manifest _build/lepusa-bundle/lepusa-app/lepusa/runtime.json
moon run cmd/main --target native -- build macos _build/lepusa-build --project _build/lepusa-app/lepusa.json
moon run cmd/main --target native -- bundle windows _build/lepusa-bundle-win
```

These commands exercise the public planning contracts and give the native
runtime and bundler work concrete outputs to consume.

`lepusa doctor [macos|windows|linux]` checks the portable runtime and bundle
plans, reports the selected target's native launch gate and signing
prerequisites, and reports host WebView availability for the platform backend
descriptors: WKWebView on macOS, WebView2 on Windows, and WebKitGTK on Linux.
It also prints typed backend preflight lines that separate host dependency
availability, WebView creation loops, and async bridge drain support.
The underlying `NativeBackendPreflight` JSON classifies the active blocker as
`dependency`, `webview-creation`, or `none`, and carries separate dependency,
WebView creation, and async bridge drain problem fields for tooling.
Passing `--json` emits one machine-readable health report with runtime,
manifest, handler coverage, bundle, native launch, signing, and platform
preflight sections.

`lepusa plan` includes resolved WebView load URLs, so backend work can consume
`RuntimePlan::windows()` directly.

`lepusa launch-session` and `lepusa-runtime launch-session` emit a target-aware
native-loop readiness envelope. Its `session` field carries the WebViews,
protocol assets, lifecycle actions, service supervision, bridge scheduling, the
async bridge executor descriptor, and the `bridgeLoop` adapter, delivery, and
drain contract. The envelope also records `requestedBridgeMode`,
`effectiveBridgeMode`, and `bridgeModeGranted`, then reports backend capability
through `launchCapability`, `backendPreflight`, `targetCanLaunch`, and
`targetLaunchBlocker`. Passing `--async-bridge` records an async-capable request;
platforms that cannot drain async completions keep the effective session
sync-only and report `bridgeModeGranted: false`.
Platform runners now lower the first WebView from that session through
`NativeWebViewLaunchContext`, which keeps the native byte packet together with
the scheduler, async executor, and `bridgeLoop` contract the backend must honor.

Generated bridges only expose command routes granted to the current window by
capabilities. `RuntimePlan::command_routes()` still reports all declared plugin
routes for metadata and bundling.

Lifecycle hooks lower to the same backend action model as startup commands, so
platform backends can handle shutdown and window-close events without reading
application construction state.

When a window omits `source`, `App` lowers the root `Cell` into a generated
Rabbita-style HTML document served from the runtime manifest as a virtual file.

`@lepusa/scaffold.write_app` writes a standalone MoonBit project skeleton with
a versioned `vectie/lepusa` module dependency. It is intentionally small:
`moon.mod`, `lepusa.json`, `src/moon.pkg`, `src/main.mbt`, and
`README.mbt.md`. The generated `src/main.mbt` starts with the current
`@lepusa/ui.UiProgram` model/update/view flow and wraps it in
`@lepusa/desktop.DesktopProject`, so custom UI handlers, official desktop
plugins, capabilities, runtime hosts, and bundle plans are derived from one
project boundary. It uses the `@lepusa/desktop` sync-safe official plugin
profile by default, so the generated MoonBit app stays launchable on native
loops that do not yet support deferred async bridge scheduling.
`write_app_with_workspace` also writes a `moon.work` file pointing at a local
Lepusa checkout, which lets new apps compile against this repository before the
framework is published to the MoonBit registry. `lepusa init` is the CLI wrapper
over that package:

```bash
moon run cmd/main --target native -- init _build/lepusa-app --workspace /Users/kq/Workspace/lepusa
```

`lepusa.json` is the app-neutral project boundary. It describes metadata,
runtime backend, windows, plugin command routes, command permission
requirements, capability grants, bundle icon resources, and bundle signing
prerequisites. Native CLI commands consume the nearest `lepusa.json` from the
current directory, or a file passed with `--project`. The reusable parser lives
in `@lepusa/project`, so tools can consume the same project contract without
depending on the CLI binary.
File paths in `lepusa.json`, including icons, packaged asset roots, local asset
roots, and filesystem scopes, are resolved relative to the config file.
Official plugins can be declared by name, for example
`{ "name": "autoLaunch" }`, `{ "name": "clipboard" }`,
`{ "name": "deepLink" }`, `{ "name": "dialog" }`, `{ "name": "fileDialog" }`,
`{ "name": "localhost" }`, `{ "name": "notification" }`, `{ "name": "log" }`,
`{ "name": "opener" }`, `{ "name": "process" }`,
`{ "name": "serviceDiscovery" }`, `{ "name": "shell" }`,
`{ "name": "singleInstance" }`, `{ "name": "store" }`, `{ "name": "tray" }`,
`{ "name": "updater" }`, `{ "name": "windowState" }`, or
`{ "name": "fs" }`;
Lepusa expands those declarations to the package's
official command contract. Custom plugins can still provide an explicit
`commands` array.
Projects can also declare `filesystemScopes`, named roots that are carried into
runtime sessions and native launch manifests for backend enforcement.
It also describes runtime behavior through `startup` and `lifecycle` commands:
`effect`, `emit`, `navigate`, and `batch` map directly to the portable
`RuntimeAction` model consumed by native backends.
When a project declares official `log`, `store`, `fs`, `opener`, `process`,
`localhost`, `serviceDiscovery`, or `windowState` plugins, the CLI binds their
MoonBit-native handlers into the project `RuntimeHost` without adding
moon-suite-specific behavior. `fs` handlers run through the async command
registry and are constrained by named `filesystemScopes`.
`process.info`, `process.cwd`, `process.env`, and `process.setEnv` are portable
handlers; `process.exit` remains a declared route for backend-owned termination
policy.

The `examples/` directory contains checked project manifests for the three
foundation app shapes: Rabbita-style MoonBit UI, packaged static assets, and a
localhost gateway with sidecar/readiness metadata.

`@lepusa/scaffold.write_plugin` writes a standalone plugin skeleton with plugin
metadata, native command registration, and a scoped capability helper.
`write_plugin_with_workspace` mirrors the same local `moon.work` support for
plugin authors. `lepusa plugin new` is the CLI wrapper over that package:

```bash
moon run cmd/main --target native -- plugin new file-dialog _build/lepusa-plugin-file-dialog --workspace /Users/kq/Workspace/lepusa
```

`BundlePlan::signing_prerequisites()` exposes target-specific distribution
requirements for macOS, Windows, and Linux. The generated bundle runtime file
includes those prerequisites so future signing, notarization, and installer
steps can consume one bundle contract.

`BundlePlan::resources()` exposes planned bundle resource mappings such as the
application icon. The generated bundle runtime file includes these mappings
under `resources`, and `@lepusa/bundle.write_plan` copies them as file data
next to generated bundle files without re-reading project configuration.
`lepusa bundle-write` is a thin CLI wrapper over that package.

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
helpers. The package validates named scopes and relative paths and provides
MoonBit handlers for scoped text, bytes, list, metadata, delete, exists, and
directory creation operations.
Core `FileSystemScope` values carry named roots through `ProjectManifest`,
`RuntimePlan`, `RuntimeSession`, and `RuntimeLaunchManifest`.

`@lepusa/plugins/file_dialog` defines file picker routes such as
`fileDialog.openFile` and `fileDialog.saveFile`, plus scoped default-directory
policy that points dialogs at declared filesystem scopes without widening core
filesystem access. Its portable registry validates picker payloads and returns
delegated open/save contracts for native OS pickers.

`@lepusa/plugins/localhost` defines local service lifecycle routes such as
`localhost.status`, `localhost.start`, `localhost.stop`, and
`localhost.waitUntilReady`, plus service metadata policy. `LocalService` and
`LocalServiceSupervisorPlan` provide the shared start, readiness, and shutdown
handoff. Its portable registry reports configured services and delegated
lifecycle actions; native backends own process execution and HTTP probing.

`@lepusa/plugins/deep_link` defines app URL scheme routes such as
`deepLink.getInitialUrls`, `deepLink.onOpenUrl`, and `deepLink.openUrl`, plus
scheme/host policy metadata. Its portable sync registry reports initial URLs,
records delegated registration/open requests, and validates scheme/host policy;
native backends own OS registration and dispatch.

`@lepusa/plugins/single_instance` defines app lock and launch handoff routes
such as `singleInstance.acquire`, `singleInstance.focus`, and
`singleInstance.onSecondLaunch`, plus instance-key policy metadata. Its
portable sync registry tracks primary/secondary launch state and focus requests;
native backends own cross-process locking and platform window activation.

`@lepusa/plugins/tray` defines system tray routes such as `tray.setIcon`,
`tray.setMenu`, `tray.setVisible`, and `tray.onMenuItemClick`, plus menu item
policy metadata. Its portable registry validates and tracks icon, tooltip,
menu, visibility, and destroy state through sync handlers, then delegates status
icon creation and OS menu behavior to native backends.

`@lepusa/plugins/auto_launch` defines launch-at-login routes such as
`autoLaunch.status`, `autoLaunch.enable`, `autoLaunch.disable`, and
`autoLaunch.setEnabled`, plus startup registration policy metadata. Its
portable sync registry validates startup metadata and tracks desired enablement
state, then delegates platform login item, registry, service, or desktop-entry
behavior to native backends.

`@lepusa/plugins/window_state` defines window persistence routes such as
`windowState.save`, `windowState.restore`, and `windowState.clear`, plus
window-label policy metadata. The portable registry stores state in the current
runtime process for `windowState.save`/`set`, `windowState.restore`/`get`, and
`windowState.clear`; `WindowStateFileStore` gives native runtimes a durable
file-backed registry once platform loops capture geometry and visibility.

`@lepusa/plugins/updater` defines update lifecycle routes such as
`updater.check`, `updater.download`, `updater.install`, and
`updater.downloadAndInstall`, plus feed/channel policy metadata. Its portable
registry validates update policy and tracks delegated check, download, install,
and restart lifecycle state; native backends own feed retrieval, signature
verification, installation, and restart.

`@lepusa/plugins/service_discovery` defines service lookup and status routes
such as `serviceDiscovery.list`, `serviceDiscovery.resolve`,
`serviceDiscovery.status`, and `serviceDiscovery.onServiceChanged`, plus
endpoint policy metadata. Its portable registry lists, resolves, and reports
configured endpoints, including endpoints derived from local services; native
backends own resolver integration, health checks, and change watching.

`@lepusa/plugins/dialog` defines platform-neutral dialog routes:
`dialog.message`, `dialog.confirm`, and `dialog.prompt`. Its portable registry
validates payloads and returns deterministic runtime-owned responses; native
backends own the actual OS dialog implementation.

`@lepusa/plugins/clipboard` provides sync text clipboard handlers backed by
native system clipboard stubs for desktop runtimes, plus an in-process
`ClipboardStore` for deterministic tests. `@lepusa/plugins/notification`
provides sync permission and show handlers backed by macOS/Linux native
delivery when available, plus an in-process `NotificationCenter` for
deterministic tests and fallback hosts.

`@lepusa/plugins/opener` declares platform-neutral URL and path opener routes:
`opener.openUrl`, `opener.openPath`, and `opener.revealPath`. Its portable
registry validates payloads and calls the platform opener through native stubs
(`open`, `xdg-open`, or ShellExecute/explorer), returning launch status without
holding product-specific state.

`@lepusa/plugins/shell` declares explicit shell execution and process lifecycle
routes. Its portable registry validates commands against an optional allow-list
and tracks delegated spawned process state, stdin writes, and kill requests;
native backends own actual OS execution and platform-specific restrictions.

`@lepusa/plugins/process` declares process metadata, environment, and control
routes behind split `process.info`, `process.environment`, and
`process.control` permissions. The portable sync registry implements process
metadata, current-directory, and environment handlers; native backends own
process termination policy.

`@lepusa/plugins/catalog` centralizes official plugin lookup for framework
tooling. Project parsing uses it to expand name-only official plugin
declarations and bind MoonBit handlers where they exist, including scoped async
filesystem handlers and portable sync process, localhost, service-discovery,
deep-link, single-instance, tray, auto-launch, and window-state handlers.

`lepusa manifest` emits the portable native-runner JSON from
`RuntimeHost::launch_manifest()`: WebView boot data, bridge hook names,
document-start scripts, protocol mappings, inline virtual files with MIME
types, declared command routes, and registered native routes.

`lepusa native-plan [macos|windows|linux]` emits the selected backend's
`NativeRunnerPlan::bootstrap_json()`, including the portable runtime manifest,
per-window WebView specs, startup operations, and prelowered lifecycle
operations that a platform runner needs. The bootstrap also includes
`bridgeScheduler`, the shared sync-only/async-capable launch policy derived
from registered bridge routes.

`lepusa launch-session [macos|windows|linux]` prepares the selected backend and
emits a readiness envelope around the same canonical `NativeLaunchSession`
shape used by packaged runtime manifests: concrete WebView launch plans,
executable operations, bridge scheduler policy, async bridge executor metadata,
service supervisor plan, requested versus effective bridge mode, and target
launch capability.

`lepusa run [macos|windows|linux] --project lepusa.json` lowers the same
`NativeRunnerPlan` and prints a compact runner smoke summary: selected backend,
WebView engine, first URL, bridge URL, local services, startup operations, and
lifecycle steps. The summary also includes `target-can-launch` and a blocker
message when the selected target is known to be missing a native WebView launch
loop. Passing `--json` emits the same canonical `RunReport` used by packaged
runtime reports. It is intentionally a no-window command unless `--launch` is
passed.

`lepusa verify [macos|windows|linux] --project lepusa.json` runs the no-write
foundation proof for an app: runtime plan, dev plan, launch manifest, bridge
asset, nonblank initial WebView content for resolvable assets, handler
coverage, native launch session, and bundle runtime contract.
Add `--strict` when the command should act as a release gate: missing concrete
handlers and known target launch blockers become failures instead of warnings.
This keeps framework-development proofs useful while still giving CI a direct
answer for "can this target ship?"
Passing `--json` emits the selected target, strict mode, final pass/fail, and
the canonical verifier lines as a machine-readable report.
The native-session line reports scheduler readiness separately from selected
target launch readiness, so Windows and async-bridge blockers are visible even
outside strict mode.
`lepusa doctor` prints the same target launch-gate blocker as a warning so
local diagnostics stay non-fatal while still showing whether the selected
target can launch natively today.

`@lepusa/runtime` turns a `RuntimePlan` into a `RuntimeSession`: resolved
window frames, protocol mappings, virtual files, generated bridge source, and
command dispatch through the declared capabilities.
`NativeRunnerPlan` keeps full per-window `RuntimeWebViewSpec` records alongside
the portable launch manifest so backend implementations can create windows
without re-deriving bridge hooks or initialization scripts.
It also exposes `lifecycleOperations` from the current `RuntimeSession`; each
step carries the operations and resulting session snapshot so native backends
can resolve assets after shutdown or window-event navigation without retaining
app construction state.

`RuntimeSession::resolve_asset(url)` is the pure custom-protocol boundary for
native WebViews. It resolves `lepusa://runtime/bridge.js`, inline/Rabbita
virtual files, safe local asset paths, and packaged app assets without doing
platform file IO.
`RuntimeSession::resolve_asset_json(url)` and
`RuntimeHost::resolve_asset_json(url)` expose the same boundary as a stable
JSON envelope for native protocol handlers: virtual content, local file paths,
packaged file paths, or a structured error.
`lepusa asset <url> --project lepusa.json` prints that envelope directly, so
desktop projects can smoke-test the custom protocol without starting a WebView.

`RuntimeHost::dispatch_json(input)` is the native hook boundary for WebView IPC.
It decodes the bridge request object, verifies the route is declared by the
runtime plan, checks capabilities through the command registry, and returns the
JSON response shape expected by `window.lepusa`.
`RuntimeHost::dispatch_json_async(input)` is the native loop path for async
plugin handlers; sync handlers still run through the same permission checks.
`RuntimeHost::bridge_dispatch_task(message)` and
`NativeRuntime::bridge_dispatch_task(message)` wrap the same bridge request as a
target-window response task with route metadata and a sync/async mode, so native
loops can immediately answer sync commands or schedule async commands and later
evaluate the generated response script. The task JSON includes the original
bridge message and `requiresAsyncDispatch` flag so native handlers do not need
to re-derive scheduling metadata. Bundled manifests expose the same contract
through `BundledRuntime::bridge_dispatch_task(message)`.
`RuntimeHost::bridge_handoff(message)` and `NativeRuntime::bridge_handoff(message)`
combine that task with an immediate dispatch result for sync routes, or a
deferred handoff for async routes. This is the narrow callback shape native
event loops use before they schedule async work.
`NativeBridgeHandoff::complete_deferred(runtime)` turns that deferred task into
a `NativeBridgeCompletion`, preserving the original task metadata together with
the response JSON and JavaScript callback script the platform loop should
evaluate. Immediate handoffs intentionally reject deferred completion so backend
code cannot accidentally run a sync command twice.
`NativeBridgeWorkQueue` is the shared FIFO queue for platform loops:
`handoff_callback(runtime)` returns immediate scripts for sync routes, enqueues
deferred async routes, and lets the loop drain completions later before
evaluating each callback script in the target WebView. Packaged runtimes expose
the same shape as `BundledBridgeWorkQueue`.
`NativeBridgeLoopAdapter` and `BundledBridgeLoopAdapter` bundle the runtime,
queue, native message callback, pending-state diagnostics, and drain operation
into the object platform event loops should keep beside each WebView host.
Their async `receive_message` method accepts one UTF-8 WebView bridge message
and returns a loop result: immediate scripts for sync routes, drained completion
scripts for async routes, and JSON diagnostics for backend tests.
`NativeBridgeLoopEvaluationPlan` lowers those scripts into target-window
`evaluate-script` operations, giving every platform runner the same operation
shape for its drain/evaluate step.
`receive_window_message` returns a `NativeBridgeLoopDelivery` /
`BundledBridgeLoopDelivery`, pairing the raw loop result with that executable
plan for the target window.
`drain_window` returns the same delivery shape for async tasks previously
captured by the message-handler handoff callback, which is the native loop path
for post-callback WebView evaluation. The callback bundles also expose
`drain_window_scripts`, a compact UTF-8 JavaScript payload for native loops that
only need to evaluate the completed callback scripts.
`RuntimeHost::dispatch_bridge_message(message)` and
`BundledRuntime::dispatch_bridge_message(message)` execute that captured bridge
message and return the response JSON plus the callback script a native WebView
loop evaluates after sync or async command completion.

`lepusa bridge-task <window> <plugin.command> [payload] --project lepusa.json`
prints that source-project scheduling task without starting a WebView.
`lepusa bridge-handoff <window> <plugin.command> [payload] --project lepusa.json`
prints the immediate-or-deferred native callback handoff for that bridge
message.
`lepusa bridge-complete <window> <plugin.command> [payload] --project lepusa.json`
executes the deferred-completion path and prints the completion envelope used by
native event loops after async work finishes.
`lepusa bridge-dispatch <window> <plugin.command> [payload] --project lepusa.json`
executes the same bridge message and prints the native callback envelope without
starting a WebView.
`lepusa bridge-loop <window> <plugin.command> [payload] --project lepusa.json`
feeds one source-project WebView message through the bridge-loop adapter and
prints the immediate script, drained async completions, and evaluation scripts
plus the native executable evaluation plan a platform loop should run.
`lepusa bridge-drain <window> <plugin.command> [payload] --project lepusa.json`
simulates the split native loop: the message-handler handoff callback runs
first, then pending async work drains into a target-window delivery envelope.
`lepusa invoke <window> <plugin.command> [payload] --project lepusa.json`
executes the same host dispatch path from the CLI. It is a native smoke-test
tool for project configuration, official plugin registration, and capability
grants.
`lepusa lifecycle <event> [window] --project lepusa.json` prints the runtime
step JSON for startup, shutdown, and window lifecycle events without starting a
native window loop.

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
resolved WebViews, asset protocol, capability grants, capability-filtered
routes, runtime session, startup operations, lifecycle steps, and bridge
scheduling routes. It also prints the concrete inspect, manifest, verify, run,
and bundle commands for each desktop target, so a generated or file-backed app
has an immediate local development loop without extra project-specific scripts.
`lepusa dev --json` emits the same plan plus reusable command templates as a
structured artifact for native runners and external tooling. This is the stable
boundary the platform-specific window loops will execute.

`RuntimeHost::runner_plan()` is the platform-neutral native-loop contract:
launch manifest, resolved WebViews, stepped runtime session, and startup
operations in one object. Platform packages map this plan to WKWebView,
WebView2, or WebKitGTK without rebuilding app state.
`RuntimeRunnerPlan::lifecycle_step(event)` returns the same operation/session
shape that `lepusa lifecycle` prints.

`@lepusa/runtime` also exposes `NativeBackend` and `NativeRuntime`, the shared
lowering boundary for platform packages. `NativeRuntime` binds a backend and
host once, then gives platform loops bootstrap JSON, asset JSON, dispatch JSON,
service supervisor plans/reports/executors, and lifecycle step JSON without
making each backend rebuild those paths.
`@lepusa.RunReport` is the shared launch summary returned by source and
packaged runtime adapters, so CLI output and future native loops use one status
vocabulary for prepared, launched, failed, and unsupported runs. It also carries
target launch readiness separately from run status, so tooling can distinguish a
valid prepared plan from a target whose WebView loop is not implemented yet.
Native runner plans also report bridge sync and async route sets, giving
platform loops an explicit scheduling contract before they open a WebView.
They also expose executable operation views for frontend event scripts and
window navigations, so native loops do not need to parse operation JSON to
drive lifecycle/startup work. Prepared source and packaged run plans append
startup frontend event scripts to the matching WebView initialization script,
so launchers consume the same operation boundary they report.
`@lepusa/runtime/macos`, `@lepusa/runtime/windows`, and
`@lepusa/runtime/linux` now provide small backend descriptors and host
availability checks for WKWebView, WebView2, and WebKitGTK. Each platform
package exposes `runtime(host)` and `detect_runtime(host)` helpers that return
the same `NativeRuntime` facade, plus `launch_capability()` declarations for
WebView creation and async bridge drain support. Platform packages also expose
service executor helpers, and native launch paths run service startup before
opening a WebView, then run service shutdown after the window loop returns.
macOS, Linux, and Windows start tracked sidecar processes, poll HTTP readiness
URLs, and stop tracked processes through platform-owned native hooks.

`Source::localhost(...)` supports gateway-style apps that load a local HTTP
service and optionally declare the sidecar command plus readiness URL metadata.
This data appears in `RuntimeSession::local_services()` and launch-manifest
`localServices` for native runners to supervise.

`lepusa bundle-plan` now also validates concrete bundle artifact plans through
`BundlePlan::files()`: platform metadata, manifest-aware launcher stubs, and
`lepusa/runtime.json`, with per-window bridge initialization scripts embedded
in the runtime manifest. Passing `--json` emits target metadata, planned
resources, signing prerequisites and steps, and planned bundle files for CI and
native runner tooling.

`@lepusa/bundle.write_plan` materializes those planned files under an output
directory. `lepusa bundle-write` is the CLI wrapper. Project bundles carry
registered official plugin routes into
`lepusa/runtime.json`, so packaged runtime data matches the same host path used
by `lepusa manifest`, `lepusa dev`, and `lepusa invoke`.
When the selected bundle target matches an available host runtime backend and
the local `cmd/runtime` native binary exists, `bundle-write` also embeds a
target-named `lepusa-runtime` executable beside the launcher and verifies it
with a `runtime-executable` check. `BundlePlan::runtime_executable_path()`
exposes that target location before materialization. Cross-target bundles keep
a launcher fallback to `lepusa-runtime` on `PATH` until Lepusa owns
cross-compiled runtime artifacts.
`bundle-write` also verifies that the generated `lepusa/runtime.json` lowers
into a target native launch session that passes the selected backend launch
capability, and that resolvable initial WebView content is present and
nonblank. Windows bundles and bundles with async bridge routes stay unverified
until the backend advertises WebView creation and async bridge drain/evaluate
support. Passing `--json` emits target, identifier, signing prerequisites, and
the reusable `BundleWriteResult` payload with written files, resources, and
verification checks for CI tooling.
Generated desktop launcher stubs call
`lepusa-runtime launch --manifest <runtime.json>`. The runtime opens the first
macOS WKWebView from the packaged `lepusa/runtime.json` today. The Linux
package owns WebKitGTK source and packaged-window loops when GTK3 and
WebKit2GTK are available, including a package-owned `lepusa://` URI scheme
callback for MoonBit-resolved runtime, virtual, local, and packaged assets.
Windows source and packaged runs prepare typed WebView2 boot plans and declare
the missing WebView2 creation loop through the same target launch-capability
gate used by `doctor`, `verify --strict`, and platform launch attempts.
`lepusa-runtime run --manifest <runtime.json>` uses a target-aware planning path
without opening a window, so bundles have a cheap validation probe.
`lepusa-runtime bootstrap
--manifest <runtime.json>` emits the target-aware packaged runtime bootstrap
for platform loops: manifest path, bundle root, app metadata, native backend,
WebView engine, WebView specs, service supervisor plan, startup operations,
lifecycle operations, bridge routes, bridge scheduler policy, and the canonical
runtime object that a backend consumes.
`lepusa-runtime launch-session --manifest <runtime.json>` emits the packaged
native host readiness envelope: prepared WebView launch plans, executable
startup and lifecycle operations, bridge scheduler policy, and service
supervisor plan under `session`, plus target launch capability and blocker
fields for packaged native loops.
`lepusa-runtime --manifest <runtime.json>` remains a manifest summary probe and
reports the bundled service supervisor requirement plus sidecar start order.
`lepusa-runtime asset <url> --manifest <runtime.json>` resolves the bundled
manifest's runtime bridge, virtual files, local roots, and packaged roots using
the same JSON envelope shape expected by native protocol handlers.
`lepusa-runtime lifecycle <event> [window] --manifest <runtime.json>` reads the
same bundled manifest and returns the local services and portable actions a
native loop should process for that lifecycle event.
`lepusa-runtime bridge-task <window> <plugin.command> [payload] --manifest <runtime.json>`
returns the MoonBit-owned bridge scheduling task for a packaged command:
target window, response hook, original bridge message, route, and sync/async
dispatch mode. Native loops can use this as the packaged-manifest probe before
wiring platform-specific message handlers.
`lepusa-runtime bridge-handoff <window> <plugin.command> [payload] --manifest <runtime.json>`
returns the packaged immediate-or-deferred handoff that native event loops use
when deciding whether to answer a WebView callback immediately or schedule
async completion.
`lepusa-runtime bridge-complete <window> <plugin.command> [payload] --manifest <runtime.json>`
executes the packaged deferred-completion path and returns the same completion
envelope native event loops use after async work finishes.
`lepusa-runtime bridge-dispatch <window> <plugin.command> [payload] --manifest <runtime.json>`
executes the packaged bridge message and returns the response JSON plus
callback script that a native event loop evaluates back into the target WebView.
`lepusa-runtime bridge-loop <window> <plugin.command> [payload] --manifest <runtime.json>`
feeds one packaged WebView message through the bundled bridge-loop adapter and
returns the immediate script, drained async completions, and evaluation scripts
plus the native executable evaluation plan a platform loop should evaluate.
`lepusa-runtime bridge-drain <window> <plugin.command> [payload] --manifest <runtime.json>`
simulates the packaged split native loop: handoff callback first, then
target-window drain delivery for pending async work.
`lepusa-runtime invoke <window> <plugin.command> [payload] --manifest <runtime.json>`
executes a packaged bridge command against the manifest's registered official
native handlers. It checks the requested window's `allowedRoutes` before
dispatching and returns the same JSON response shape as project-hosted
`lepusa invoke`.
`@lepusa/runtime/bundled` owns the reusable manifest parser and bootstrap,
asset, lifecycle, bridge-task, bridge-loop, and invoke JSON behind those
commands, so native platform loops can consume bundled runtime data without
depending on CLI internals.
`BundledRuntime::new(manifest)` keeps the native command registry state alive
for repeated bridge calls. It also owns bundled bridge message preparation,
sync/async dispatch, target-window response-hook lookup, and response-callback
scripts, while the manifest helper remains useful for one-shot probes.
Bundled native run plans expose startup and lifecycle event scripts plus window
navigations as typed runtime values, so packaged app loops can consume the same
native-operation boundary as source-project runs.
Source and bundled native run plans also serialize to compact handoff artifacts
that carry native metadata plus the canonical launch session, while the
launch-session CLIs wrap that session with target readiness metadata for tools
that need to distinguish prepared plans from launchable platform backends and
their host dependency preflight state.
`NativeBackendPreflight` keeps the collapsed `problem` for human summaries, and
adds `problemKind`, `dependencyProblem`, `webviewCreationProblem`, and
`asyncBridgeDrainProblem` so release tooling can distinguish an unavailable
system dependency from framework backend work that is still intentionally
gated.
The macOS runner prepares and injects the generated bridge as a document-start
WKUserScript, together with a native hook bootstrap and
`window.webkit.messageHandlers.__lepusaInvoke` dispatch path for sync command
responses. Native launch paths refuse async bridge routes with an explicit
scheduler requirement until a backend launch capability declares that its event
loop can drain queued completions and evaluate the resulting scripts without
blocking the WebView callback. Launch-session JSON also carries
`asyncBridgeExecutor`, which names `NativeRuntime::bridge_async_dispatch_callback`
and its UTF-8 bridge-message to JavaScript-callback-script byte contract. The
same `bridgeScheduler` field appears in source and bundled bootstrap JSON so
platform loops and CLI diagnostics read one launch policy.
`NativeRuntime.prepare_bridge_message`, `bridge_dispatch_task`, and
`dispatch_bridge_message` own the MoonBit side of that path by resolving the
target window, response hook, route scheduling mode, sync/async dispatch, and
response-callback script. macOS, Linux, and Windows share the same runtime
hook-bootstrap and response-script helpers instead of duplicating bridge
callback semantics in each backend.
The same runner registers a `WKURLSchemeHandler` for the Lepusa asset protocol.
MoonBit still owns asset resolution; the Objective-C stub only turns the
runtime asset packet into WebKit response/data/finish calls.
The Linux source-window loop injects the same `window.lepusa` bridge plus a
WebKitGTK message-handler bootstrap, so sync native commands can round-trip
through MoonBit in an opened WebKitGTK window. Its WebKitGTK URI-scheme
handler also calls back into MoonBit for runtime asset resolution, keeping
packaged Linux windows on the same `lepusa://` contract as macOS.
`Source::packaged("dist")` also emits an asset resource mapping and
`lepusa bundle-write` copies that directory into `lepusa/assets/<window>`.
The generated bundle runtime manifest rewrites packaged protocol roots to that
bundle-relative location, while runtime asset probes return `packaged-file`
envelopes for `lepusa://packaged/<window>/...` URLs.

## Boundary

Lepusa owns the reusable desktop framework:

- native window and WebView runtime
- frontend-to-MoonBit command bridge
- app capabilities and permissions
- official platform plugins
- dev/build/bundle CLI

Consumer projects own product behavior, backend services, schemas, routes,
workspaces, dashboards, and domain-specific adapters.
