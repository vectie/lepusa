# Lepusa Architecture

## Goal

Make native desktop app creation easy for MoonBit projects on macOS, Windows,
and Linux without each application writing its own native launcher, WebView
bridge, IPC, permission model, plugin system, and bundler.

Lepusa is a foundation project. It must stay app-neutral.

## Layers

```text
consumer apps
  product code, domain state, backend routes, frontend views

lepusa
  stable MoonBit facade and CLI

lepusa/ui
  Rabbita-compatible HTML helpers and model/update/view programs for
  MoonBit-authored desktop UI

lepusa/runtime
  WebView windows, event loop, custom protocols, asset loading, IPC transport

lepusa/plugins/*
  dialog, opener, fs, file-dialog, process, shell, clipboard, notification,
  log, store, localhost, deep-link, single-instance, tray, auto-launch,
  window-state, updater, service-discovery

shared native utility packages
  filesystem, paths, process, OS, time, UUID, C helpers
```

## Authoring Model

Lepusa should mirror Rabbita's application style for MoonBit UI:

```moonbit nocheck
let (dispatch, cell) = @lepusa.cell_with_dispatch(
  model=init_model(),
  update~,
  view=(dispatch, model) => render_app(dispatch, model),
)
let app = @lepusa.new(cell)
  .with_startup(load_initial_state(dispatch))
  .on_window_close_requested("main", persist_state(dispatch))
  .window(
    title="Example",
    width=1000,
    height=720,
  )
let plan = app.launch_plan()
```

Equivalent lower-level hosting should remain available:

```moonbit nocheck
@lepusa.WindowConfig::new(
  title="Example",
  source=@lepusa.Source::local_path("dist"),
)
```

This gives MoonBit UI authors the familiar model/update/view flow while still
supporting arbitrary built frontend assets.

`@lepusa/ui` is the first dedicated authoring layer. Static helpers return root
`@lepusa.Html` values, while `UiProgram` adds a compact model/update/view loop
with message encode/decode, click dispatch attributes, plugin/capability
declaration, and a registry handler that returns render payloads through normal
Lepusa IPC. It still produces a root `Cell`, so the runtime boundary remains
`cell -> new(cell) -> launch_plan/runtime_plan`. The lower-level
`UiTransition::command()` remains available for native loops that later support
command-emitting UI handlers.

## Process Model

Lepusa should follow a Tauri-style split:

- Core process: MoonBit native executable with OS authority.
- WebView process: system WebView rendering frontend assets.
- IPC: all privileged work crosses a typed command/event bridge.
- Permissions: a window only gets the commands listed in its capabilities.

The implementation is MoonBit-native. Tauri is a reference design, not a
runtime dependency.

## Public API Ownership

The stable facade owns public types. Early implementation can reuse ideas or
code from existing experiments, but users should import `@lepusa` and
`@lepusa/*` packages.

Initial public surface:

```moonbit nocheck
pub type App
pub type Window
pub type WindowConfig
pub type Source
pub type Plugin
pub type Capability
pub type Cmd
pub type Event
pub type InvokeRequest
pub type InvokeResponse
pub type RuntimeConfig
pub type RuntimePlan
pub type BundleConfig
pub type BundlePlan
pub type ProjectManifest
pub type Html
pub type Dispatch

pub fn cell_with_dispatch(...) -> (Dispatch[Msg], Cell)
pub fn new(root : Cell) -> App
pub fn App::with_startup(self : App, cmd : Cmd) -> App
pub fn App::window(self : App, ...) -> App
pub fn App::launch_plan(self : App) -> Result[LaunchPlan, Array[String]]
pub fn App::runtime_plan(self : App, config? : RuntimeConfig) -> Result[
  RuntimePlan,
  Array[String],
]

pub fn Source::html(html : String) -> Source
pub fn Source::local_path(path : String) -> Source
pub fn Source::url(url : String) -> Source
pub fn Source::localhost(port~ : Int, ...) -> Source
```

## IPC

The first executable IPC boundary is `CommandRegistry`: native runtime code
receives `InvokeRequest`, finds the registered route, checks capabilities, then
returns `InvokeResponse`.

```moonbit nocheck
let registry = @lepusa.CommandRegistry::new().register_fn(
  "dialog.show",
  permission=@lepusa.Dialog,
  handler=fn(payload) { Ok(show_dialog(payload)) },
)
let response = registry.dispatch(request, capabilities~)
```

Frontend bindings should be generated or exposed consistently:

```javascript
await window.lepusa.invoke("dialog.show", { message: "Hello" })
await window.lepusa.dialog.show({ message: "Hello" })
```

`RuntimePlan::bridge_script()` generates the first bridge. It installs
`window.lepusa`, validates routes allowed for the configured window, calls the
backend-provided `globalThis.__lepusaInvoke(request)` hook, and exposes
namespace helpers for those granted routes. This bridge is framework-neutral and
can be used from Rabbita, React, Vue, Svelte, or plain JavaScript.

Native launch-session JSON is a target-aware readiness envelope. Its `session`
field carries bridge scheduler metadata: sync-only mode is the conservative
default, while `--async-bridge` marks the session as async-capable for platform
loops that schedule deferred command tasks and later run the generated callback
script. The envelope also carries `launchCapability`, `targetCanLaunch`, and
`targetLaunchBlocker`, so tooling can distinguish prepared launch plans from
platform backends that can actually open them. The same session payload carries
an `asyncBridgeExecutor` descriptor naming
`NativeRuntime::bridge_async_dispatch_callback` and the UTF-8 bridge-message to
JavaScript-callback-script byte contract.
It also carries a `bridgeLoop` contract naming the shared
`bridge_loop_adapter().handoff_callback` and async
`bridge_loop_adapter().receive_window_message` / `drain_window` delivery
boundary for source and packaged runtime loops.
`NativeWebViewLaunchContext` is the runner-side handoff for a single WebView:
it keeps the byte-level native launch packet together with the same scheduler,
async executor, and `bridgeLoop` contract from the launch session before a
backend crosses into C, WebKit, or WebView2 code.
Open-window runners pass the queue-backed
`bridge_loop_adapter().handoff_callback` into native message handlers, so sync
commands still return callback scripts immediately while async commands are
captured for the backend drain/evaluate step.
The in-process completion API is `NativeBridgeHandoff::complete_deferred`:
platform loops capture a deferred handoff from the WebView callback, schedule
it away from the native message handler, and later receive a
`NativeBridgeCompletion` containing the original task metadata, response JSON,
and callback script to evaluate in the target WebView.
For loops that need explicit scheduling state, `NativeBridgeWorkQueue` stores
deferred async tasks in FIFO order and drains them into completion envelopes.
Its `handoff_callback(runtime)` method is the sync native message-handler
callback: immediate routes return a script immediately, while async routes are
queued for later drain. `BundledBridgeWorkQueue` mirrors the same contract for
packaged runtimes.
`NativeBridgeLoopAdapter` and `BundledBridgeLoopAdapter` wrap that queue with
its owning runtime, callback, diagnostics, and drain operation so platform
backends do not need to reassemble scheduling state around every WebView.
Their async `receive_message` method is the next platform-loop boundary: it
captures one bridge message, keeps sync routes immediate, drains async work into
completion envelopes, and returns the full list of scripts the backend must
evaluate in the WebView.
`NativeBridgeLoopEvaluationPlan` converts that script list into window-scoped
`NativeExecutableOperation::evaluate_script` operations, so source and packaged
runtime loops share one executable drain/evaluate model before platform code
crosses into C, WebKit, or WebView2 APIs.
`receive_window_message` is the per-WebView adapter entry point: it returns a
`NativeBridgeLoopDelivery` or `BundledBridgeLoopDelivery` containing the raw
loop result and executable evaluation plan for the target window.
`drain_window` exposes the split native-loop path: the message handler can
enqueue async work through `handoff_callback`, then later drain pending work
into the same delivery envelope after leaving the synchronous WebView callback.
For platform runners, `NativeBridgeLoopCallbacks` and
`BundledBridgeLoopCallbacks` bind those operations to one window label so the
native backend can keep one queue-backed handoff callback and one async drain
callback for the WebView it launched. `NativeWebViewLaunchPacket` carries that
window label with the rest of the C/WebView launch ABI.

Command rules:

- JSON schema generated from MoonBit `ToJson`/`FromJson` types where possible.
- Every command belongs to a plugin namespace.
- Every command declares whether it is sync, async, streaming, or event-only.
- Every command is denied by default unless a capability grants it.
- `Permission::command(route)` is the default permission for custom command
  routes.
- `RuntimeLaunchManifest.capabilities` carries the capability grants as native
  runtime data, so packaged apps and platform diagnostics can inspect the same
  permissions that dispatch enforces.
- Built-in permission names for project manifests are `filesystem.read`,
  `filesystem.write`, `file-dialog`, `network`, `shell`, `dialog`, `opener`,
  `clipboard`, `notification`, `localhost`, `deep-link`, `single-instance`,
  `tray`, `auto-launch`, `window-state`, `updater`, `service-discovery`,
  `process.info`, `process.environment`, and `process.control`; custom names
  use `custom:<name>`.
- `RuntimePlan::command_routes()` lists every declared route, while
  `RuntimePlan::window_command_routes(label)` returns only routes granted to
  that window.

## Capabilities

Use a small manifest format before inventing a large policy engine:

```json
{
  "identifier": "dev.example.app",
  "plugins": [
    {
      "name": "dialog",
      "commands": [
        { "name": "show", "permission": "dialog" }
      ]
    }
  ],
  "capabilities": [
    {
      "name": "main-dialog",
      "windows": ["main"],
      "permissions": ["dialog"]
    }
  ]
}
```

Route grants stay available for commands whose default permission is their own
route:

```json
{
  "name": "main-core",
  "windows": ["main"],
  "commands": ["core.invoke"]
}
```

Permissions should be checked in the core process, not only in frontend
bindings. File access should prefer scoped roots and persisted scopes over broad
filesystem access.

## Sources And Assets

Support first-class source modes:

- `Source::html`: embedded memory source for examples and tests.
- `Source::local_path`: local static directory or entry HTML.
- `Source::url`: development server or app-owned local server.
- `Source::localhost`: local gateway source with optional sidecar command and
  readiness URL metadata.
- `Source::packaged`: prebuilt app assets that bundle into the native package.
- `Source::rabbita`: MoonBit-authored UI mounted into a generated shell.

Production builds should prefer packaged assets served through a custom
protocol. Loopback localhost should be available for apps that truly own a
local service.

`RuntimePlan` resolves each `WindowConfig` into a `ResolvedWindow`:

- source-less `App` windows become generated Rabbita HTML backed by the app
  root `Cell`
- remote URLs stay remote and require no protocol mapping
- localhost sources stay HTTP URLs and may emit local service metadata
- local paths become `asset_protocol://local/<window>/index.html`
- packaged assets become `asset_protocol://packaged/<window>/index.html`
- inline HTML becomes `asset_protocol://inline/<window>/index.html`
- Rabbita mounts become `asset_protocol://rabbita/<window>/index.html`

Native WebView backends should consume `ResolvedWindow::url()` and install the
listed `ProtocolMapping` values instead of re-resolving app configuration.

`@lepusa/runtime` is the first package on the runtime side of that boundary. It
accepts a `RuntimePlan`, produces a `RuntimeSession` snapshot with window frame
data, protocol mappings, virtual files, bridge source, and routes, and exposes
command dispatch through the plan's capability set. Platform backends should add
event loop and WebView ownership underneath this package instead of reaching
back into app construction APIs.

`RuntimeSession::resolve_asset(url)` is the custom-protocol contract native
backends should call from their WebView protocol handler. It resolves the
generated bridge, inline virtual files, safe local asset paths, and safe
packaged asset paths while rejecting traversal attempts before platform file IO
happens.
`RuntimeSession::resolve_asset_json(url)` and
`RuntimeHost::resolve_asset_json(url)` expose the same decision as a compact
backend wire envelope: `{ok,url,mimeType,body}` for virtual content, local file
paths, or packaged file paths, and `{ok:false,url,error}` for denial or misses.
The CLI command `lepusa asset <url>` runs that exact path against the current
project manifest, giving backend implementers and app authors a no-window smoke
test for protocol mappings and virtual asset generation.

`RuntimeHost::dispatch_json(input)` is the native hook contract. The generated
bridge sends a JSON object with `id`, `windowLabel`/`window_label`, `plugin`,
`command`, and string `payload`; the runtime decodes it into `InvokeRequest`,
dispatches through `CommandRegistry` with plan capabilities, and encodes the
`{id,payload}` or `{id,error}` response expected by the frontend bridge.
`CommandRegistry` supports both sync and async command handlers. Native loops
should use `RuntimeHost::dispatch_json_async(input)` so platform plugins can
perform filesystem, process, network, or OS work without blocking the bridge
contract. The sync dispatch methods remain for pure in-memory handlers and
tests.

Native-to-frontend events use the matching generated bridge hook. The bridge
installs `window.lepusa.listen(name, handler)`,
`window.lepusa.unlisten(name, handler)`, and
`globalThis.__lepusaDispatchEvent(event)`. Platform backends should call the
per-WebView `eventDispatchHook` from `RuntimeWebViewBoot` or
`RuntimeWebViewSpec` when delivering `Event::to_json()` payloads into the page.
`RuntimeSession::apply_actions` resolves `Cmd::emit` into per-WebView
`FrontendEventDispatch` values, including the hook name and exact JavaScript
expression to evaluate. `AppTarget` emits one dispatch per WebView; window and
WebView targets resolve to the matching label before the platform boundary.

`RuntimePlan::actions(cmd)` lowers app commands into backend-executable
`RuntimeAction` values. Startup commands become `startupActions` in the launch
manifest, so native runners can emit frontend events, navigate windows, and
run named effects without understanding the authoring `Cmd` tree.

The same startup queue is lowered to portable `NativeOperation` values in
`NativeRunnerPlan`. Non-startup lifecycle hooks are prelowered into
`lifecycleOperations` in the native runner bootstrap JSON, so platform runners
can service shutdown and window events from one backend-owned contract. Each
lifecycle step carries the resulting `RuntimeSession` snapshot so navigations
can update protocol mappings and virtual assets without re-reading manifests.
`RuntimeRunnerPlan::lifecycle_step(event)` exposes the platform-neutral form,
and `lepusa lifecycle <event> [window]` prints it for no-window smoke tests.

`@lepusa/runtime` owns `NativeBackend`, `NativeLaunchPlan`,
`NativeRunnerPlan`, and `NativeRuntime`. `NativeRuntime` is the platform-loop
facade: it binds a backend and `RuntimeHost` once, then exposes bootstrap JSON,
asset resolution JSON, IPC dispatch JSON, service supervisor plans/reports, and
lifecycle step JSON from one object. Platform packages should consume that
facade instead of reassembling host, runner, protocol, command dispatch, and
sidecar supervision paths themselves. Source and packaged runtime paths both
lower launch summaries into root `@lepusa.RunReport` values so backends, CLI
probes, and future supervisors share one status and counter contract.
`NativeExecutionPlan` exposes startup evaluation scripts and navigations as
typed views; source and bundled prepared run plans append startup frontend
event scripts to the matching `NativeWebViewPlan` initialization script before a
platform runner opens the window.

Platform packages only need to describe their native engine and host
availability:

- `@lepusa/runtime/macos`: WKWebView via Cocoa/WebKit.
- `@lepusa/runtime/windows`: WebView2.
- `@lepusa/runtime/linux`: WebKitGTK.

Each platform package exposes `runtime(host)` and `detect_runtime(host)` helpers
that return the shared `NativeRuntime` facade. Platform packages consume the
same `RuntimeHost` boundary and must not re-read app manifests, capabilities,
or source configuration.

Lifecycle hooks use the same lowering path. App authors attach commands to
`AppStarted`, `AppWillExit`, `WindowCloseRequested(label)`, or
`WindowClosed(label)`, and platform backends call
`RuntimeHost::lifecycle_actions(event)` from their event loop.
`startupActions` is the immediate boot queue; `lifecycleHooks` is the event-loop
view of the same model for native runners that dispatch lifecycle events.
`RuntimeSession::apply_actions(actions)` is the portable execution step: it
returns backend operations to perform and an updated session with navigation
asset mappings already applied. Native backends should translate
`RuntimeStartService`, `RuntimeDispatchEvent`, `RuntimeRunEffect`, and
`RuntimeNavigateWindow` to platform calls instead of mutating session
internals.

`RuntimeHost::webviews()` produces the pending WebView creation specs platform
backends need: resolved load URL, frame options, asset protocol, native hook
names, allowed routes, and document-start initialization scripts. The platform
layer should translate these specs to WKWebView, WebView2, or WebKitGTK calls
without re-reading `App`, `WindowConfig`, or manifest state.
`RuntimeHost::dev_plan()` is the portable development-run boundary over the
same host: it returns WebView specs, the stepped runtime session, and startup
operations in one object so CLI and platform backends do not reconstruct boot
state separately.
`RuntimeHost::runner_plan()` is the native-loop form of the same handoff: it
adds the launch manifest to the resolved WebViews, stepped session, and startup
operations so platform packages can translate a single runtime object. Local
services are emitted as `RuntimeStartService` operations before app startup
commands.
`RuntimeServicePlan` is the service-specific view over the same data. It exposes
declared services, startup services, start order, validation, and a
`requiresSupervisor` flag so dev tools and native runners can supervise
localhost sidecars without parsing project manifests or generic operation JSON.
It also lowers to `LocalServiceSupervisorPlan`, the shared start, readiness,
and shutdown handoff consumed by native platform loops.
`NativeServiceSupervisorPlan` decorates that handoff with backend and WebView
engine metadata, and every platform source/bundled run plan exposes it so
WKWebView, WebView2, and WebKitGTK loops can share the same sidecar supervisor
contract before wiring platform-specific process spawning and readiness probes.
`NativeServiceSupervisorReport` is the execution result envelope for that same
contract. It records per-action prepared, started, ready, stopped, skipped, or
failed states so platform loops can report real process/readiness outcomes
without changing the app-facing service model.
`NativeServiceExecutor` is the backend hook surface beneath the report: a
platform backend supplies start, readiness, and stop handlers, then executes
startup or shutdown action sets and receives a `NativeServiceSupervisorReport`.
This keeps process spawning and HTTP probing owned by platform code while
preserving one framework-level service contract. The macOS, Linux, and Windows
packages map those hooks to native process launch, HTTP readiness polling, and
tracked shutdown.
`BundledRuntimeManifest::service_plan()` provides the same sidecar view for
packaged `lepusa/runtime.json` files, keeping source-run and bundle-run
supervision contracts aligned; bundled service plans lower to the same
`LocalServiceSupervisorPlan`.
`NativeRuntime::new(backend, host)` is the backend-owned wrapper over that
handoff. It is the narrow surface a real WKWebView/WebView2/WebKitGTK loop
needs while creating windows, serving custom protocol requests, handling bridge
IPC, and dispatching lifecycle events.

`RuntimePlan::launch_manifest()` is the portable native-runner contract owned by
the public facade. It serializes backend, asset protocol, bridge URL, protocol
mappings, inline virtual files with MIME types, command routes, registered
native routes, per-window allowed routes, lifecycle hooks, and document-start
scripts into stable JSON.
`RuntimeHost::launch_manifest()` adds the concrete registered native routes
from a command registry, while bundle and platform packages consume the same
manifest instead of inventing their own runtime files.
`RuntimeHost::dispatch()` is stricter than a raw registry call: the route must
be declared by the plan, present in the registry, and granted by the active
window capabilities before a handler can run.
`RuntimeLaunchManifest::resolve_asset(url)` is the facade-level custom protocol
resolver for native runners that consume only the launch manifest.
`@lepusa/project` owns the standalone `lepusa.json` boundary: it parses app
metadata, windows, sources, official plugins, capabilities, filesystem scopes,
startup commands, and lifecycle hooks into a `ProjectConfig` carrying a
`ProjectManifest`, root `Cell`, and `CommandRegistry`. `ProjectConfig::load`
is the file-backed entry point; it reads the manifest and resolves relative
paths from the config file directory. The CLI delegates to that package API
instead of carrying its own project loader.
`@lepusa/runtime/bundled` is the runtime-executable companion for packaged
apps: it parses `lepusa/runtime.json`, drives generated launcher stubs through
target-aware bundled launch plans, emits bundled bootstrap JSON for native
loops, exposes typed WebView boot data, preserves capability grants, resolves
bundled asset URLs, dispatches registered official plugin commands, and selects
local services plus lifecycle actions without re-entering project configuration.

`@lepusa/runtime/macos` owns macOS-specific backend integration. It is a native
package with a small C stub that validates the system WebKit framework is
available, prepares the first WebView load URL from typed runtime assets or a
packaged bundled manifest, and enters a Cocoa/WKWebView run loop through an
explicit `launch(runtime)` or `launch_bundled(manifest)` call.
Objective-C window creation lives under this package, not in the portable
facade or CLI. `prepare_run(runtime)` and `prepare_bundled_run(manifest)` are
the testable boundaries: they preserve custom-scheme Lepusa URLs, attach the
asset protocol to the run plan, carry startup/lifecycle execution entries, and
split registered bridge routes into sync versus async command sets. They also
merge the generated Lepusa bridge with a macOS-native hook bootstrap script.
The C stub installs that combined source as a `WKUserScript` at document
start, so launched pages receive `window.lepusa`, `__lepusaInvoke`, and the
future `__lepusaInvokeResponse` callback surface before application code runs.
The macOS C stub registers a `WKScriptMessageHandler` under the generated
native hook name. The handler passes the posted JSON string into MoonBit,
receives a response script, and evaluates it back in the WebView so
`window.lepusa.invoke(...)` can resolve sync commands in a real window.
The same stub registers a `WKURLSchemeHandler` for the app asset protocol.
Protocol requests are passed back to MoonBit, which resolves runtime bridge,
virtual, local, and packaged assets and returns a compact packet describing
either in-memory content or a file path; Objective-C only adapts that packet to
WebKit response calls.
`NativeRuntime::prepare_bridge_message(message)` is the MoonBit-owned
capture boundary shared by platform packages: it resolves the target WebView
and response hook without executing the command.
`NativeRuntime::bridge_dispatch_task(message)` adds the decoded route and
sync/async scheduling mode to that prepared message, so platform loops can
answer sync routes inline or move async routes onto their event loop before
evaluating the generated response script. The prepared message can also dispatch
through `NativeRuntime.dispatch_bridge_message_sync` or
`NativeRuntime.dispatch_bridge_message` and return the JavaScript source that
calls the matching response hook in the page. macOS, Linux, and Windows use the
same runtime WebKit/WebView2 hook-bootstrap helpers and response-script helper,
so platform code does not duplicate callback semantics.
`@lepusa/runtime/bundled` exposes the matching `BundledRuntime` bridge
transport for packaged `lepusa/runtime.json` launches, preserving official
plugin state across repeated bridge calls and the same dispatch task contract
for packaged manifests. Wiring that dispatch task from the native message
handler onto each backend event loop is the remaining native integration step
for async commands. `MacOSOpenWindow` reports the shared
`RunUnsupported` status when the plan contains async command routes, so the
current sync Objective-C callback cannot accidentally launch a partially working
async bridge.
The platform packages expose `NativeLaunchCapability` so WebView creation and
async bridge drain/evaluate support are declared in one place and consumed by
`doctor`, `verify --strict`, launch-session readiness rendering, and open-window
launch paths.
`lepusa run macos --launch` is the first protocol-complete GUI entry point. The
Linux package also owns a first WebKitGTK source-window loop: it resolves the
first runtime WebView to an HTML/file/remote URL, injects document-start bridge
scripts, registers the generated WebKitGTK script-message handler, and evaluates
MoonBit-produced response scripts so sync `window.lepusa.invoke(...)` calls can
resolve in the opened window. The same native loop registers the generated
asset protocol as a WebKitGTK URI scheme and asks MoonBit to resolve runtime,
virtual, local, and packaged assets, so Linux packaged manifests can open their
first `lepusa://` WebView through `launch_bundled(manifest)`. The Windows
package prepares typed WebView2 boot plans for source and packaged manifests,
merges the generated bridge with a `chrome.webview.postMessage` bootstrap, and
routes launch attempts through the same capability gate. Windows currently
declares the WebView2 creation loop unavailable until the COM creation path
lands.

## Bundling

`BundlePlan` is a pure framework contract: it computes platform metadata and
`lepusa/runtime.json` without touching the filesystem. The runtime manifest
includes per-window WebView boot data and initialization scripts, so bundle
writers do not emit a separate default bridge file that can drift from
multi-window runtime state. `@lepusa/bundle` owns native filesystem
materialization through `write_plan`, which writes the planned files into an
output directory and applies executable permissions where the plan asks for
them. Its post-write checks parse `lepusa/runtime.json`, prepare the bundled
native launch session, and apply the target `NativeLaunchCapability`, so
pre-install smoke verification cannot mark a Windows or async-bridge bundle
ready before the selected backend owns the required native loop. The native CLI
delegates `lepusa bundle-write` to that package.
`BundlePlan::runtime_manifest()` exposes the same typed native-runner manifest
without forcing tooling to scan `BundlePlan::files()`. When created from a
registry-aware project path, it also preserves the registered native routes that
the host exposes to command dispatch.

This split keeps application configuration, runtime planning, and installer
work separate. Future macOS, Windows, and Linux packaging code should consume
`BundlePlan::files()` rather than duplicating bundle layout decisions.

## Local Services

Some apps are gateway-first instead of static-asset-first. Lepusa should
support that shape without absorbing the product service:

```text
Lepusa window
  -> loads http://127.0.0.1:<bound-port>/ or packaged fallback assets
  -> grants runtime plugins through capabilities
  -> supervises optional sidecar/local service startup
  -> records discoverable service status

App service
  -> owns routes, state, auth, persistence, and product contracts
```

Framework support needed for this mode:

- localhost source with readiness probe metadata
- optional sidecar process lifecycle from `localServices`
- tray and restart actions
- deep-link registration and dispatch through the official `deepLink` contract
- external open, clipboard, file dialogs, auto-launch, and updater plugins
- service discovery/status files

`Source::localhost(...)` lowers to a normal HTTP WebView URL and, when given a
command, emits a `LocalService` entry into `RuntimeSession` and
`RuntimeLaunchManifest.localServices`. Platform backends own process spawning,
readiness polling, retry UI, and shutdown policy; Lepusa core only carries the
portable service contract.

## Bundling

Lepusa's bundler should own platform templates:

- macOS: `.app`, Info.plist, icon, optional DMG, signing/notarization hooks.
- Windows: executable metadata, icon, WebView2 handling, installer path.
- Linux: executable, desktop file, icons, AppImage/deb/rpm-oriented manifests.

Consumer apps should provide metadata, assets, capabilities, sidecars, and
signing configuration. They should not need to maintain native launcher code.

`BundlePlan::files()` is the first artifact boundary. It generates platform
metadata plus shared runtime assets:

- macOS: `Contents/Info.plist`, launcher stub, runtime manifest
- Windows: app manifest, `.cmd` command launcher, runtime manifest
- Linux: `.desktop` entry, executable launcher, runtime manifest

The next bundler step should write these files and add platform signing or
installer packaging without inventing another configuration model.

`BundlePlan::resources()` is the companion boundary for binary or externally
owned assets. The first resource type is the application icon, mapped to the
target's native bundle location and recorded in the generated bundle runtime
file under `resources`.
Packaged asset resources keep their source path as bundler input, while the
generated bundle runtime manifest rewrites `package:` protocol mappings to the
bundle-relative `lepusa/assets/<window>` directory.
`lepusa bundle-write` copies planned resources to those bundle paths; future
installer/signing steps should consume the same `BundleResource` list.

`BundlePlan::signing_prerequisites()` is the signing boundary for that next
step. It lists target-specific identities, tools, notarization tools, runtime
dependencies, and validators, and the generated bundle runtime file includes
the same list under `signingPrerequisites`.

## Official Plugins

Official plugins live under `vectie/lepusa/plugins/*`. Each plugin package
should expose the same small surface:

- a `plugin()` declaration for `ProjectManifest` and `App`
- capability helpers scoped to all windows or one window
- registry helpers when the plugin can be implemented in MoonBit
- package-local validation, payload decoding, and policy contracts

`@lepusa/plugins/log` and `@lepusa/plugins/store` are pure cross-platform
packages with MoonBit command registries. `@lepusa/plugins/fs` declares the
official filesystem command routes, read/write capability helpers, scoped
relative path policy, and async handlers for scoped text, bytes, list,
metadata, delete, exists, and directory creation operations.
`@lepusa/plugins/file_dialog` declares file picker routes, scoped
default-directory policy, and delegated picker validation handlers.
`@lepusa/plugins/localhost` declares local service lifecycle and readiness
routes, plus portable metadata handlers for configured local services.
`@lepusa/plugins/deep_link` declares app URL scheme registration and dispatch
routes.
`@lepusa/plugins/single_instance` declares app lock, focus, and second-launch
handoff routes. `@lepusa/plugins/tray` declares system tray icon, menu, and
menu-click routes, plus delegated tray state handlers.
`@lepusa/plugins/auto_launch` declares launch-at-login
status and enablement routes, plus delegated enablement handlers.
`@lepusa/plugins/window_state` declares window
geometry persistence routes. `@lepusa/plugins/updater` declares update check,
download, install, and restart routes, plus delegated update lifecycle handlers.
`@lepusa/plugins/service_discovery`
declares service lookup, status, watch, change-event routes, and portable
metadata handlers for configured endpoints.
`@lepusa/plugins/dialog` declares message, confirm, and prompt routes, plus
portable deterministic async handlers for runtime-owned dialogs.
`@lepusa/plugins/clipboard` and `@lepusa/plugins/notification` declare
clipboard and notification routes and provide in-process async handlers for
text clipboard state, notification permission, and notification show requests.
`@lepusa/plugins/shell` declares shell execution and process lifecycle routes
and provides delegated process-table handlers with optional command allow-list
validation.
`@lepusa/plugins/deep_link` and `@lepusa/plugins/single_instance` declare app
launch handoff routes and provide portable state handlers for initial URLs,
delegated URL opens, primary-instance acquisition, and focus requests.
`@lepusa/plugins/process` declares process metadata, environment, and control
routes behind split process permissions.
Native platform effects should be implemented by runtime backends behind those
contracts, not by widening core access.
`@lepusa/plugins/catalog` is the aggregate lookup package for tools that need
official plugin declarations or MoonBit handler registration without importing
every plugin package directly.

## CLI Boundary

The CLI should be thin over public framework contracts. Early commands should
exercise planning without reaching into private structs:

```text
lepusa doctor [macos|windows|linux]
  -> validates app/runtime/bundle planning and reports signing prerequisites

lepusa plan
  -> prints runtime backend, windows, plugins, capabilities, command routes

lepusa manifest
  -> prints the portable native-runner JSON manifest

lepusa dev [--json]
  -> prints the runtime development plan consumed by platform runners, with structured JSON for tooling

lepusa run <target>
  -> prints a no-window native runner smoke summary from NativeRunnerPlan

lepusa run macos --launch
  -> prepares and opens the first macOS WKWebView window

lepusa verify [macos|windows|linux]
  -> runs a no-write project proof across runtime, dev, manifest, native session, and bundle contracts

lepusa bridge-task <window> <plugin.command> [payload]
  -> emits source-project bridge task message plus scheduling metadata for native handlers

lepusa bridge-handoff <window> <plugin.command> [payload]
  -> emits source-project immediate/deferred bridge callback handoff

lepusa bridge-dispatch <window> <plugin.command> [payload]
  -> executes a source-project bridge message and emits response callback script

lepusa bridge-loop <window> <plugin.command> [payload]
  -> feeds one source-project bridge message through the adapter loop and emits scripts to evaluate

lepusa bridge-drain <window> <plugin.command> [payload]
  -> runs source handoff callback first, then drains pending async bridge work into a delivery envelope

lepusa-runtime --manifest <lepusa/runtime.json>
  -> reads a bundled runtime manifest and prints a summary

lepusa-runtime run --manifest <lepusa/runtime.json>
  -> prepares a target-aware bundled runtime launch plan and reports launch readiness without opening a window

lepusa-runtime launch --manifest <lepusa/runtime.json>
  -> opens the first bundled macOS WKWebView window or reports unsupported for other targets

lepusa-runtime bootstrap --manifest <lepusa/runtime.json>
  -> emits bundled bootstrap JSON for native platform loops

lepusa-runtime asset <url> --manifest <lepusa/runtime.json>
  -> resolves bundled runtime assets for native protocol handlers

lepusa-runtime lifecycle <event> [window] --manifest <lepusa/runtime.json>
  -> selects bundled local services and actions for native lifecycle dispatch

lepusa-runtime bridge-task <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
  -> emits bundled bridge task message plus scheduling metadata for native message handlers

lepusa-runtime bridge-handoff <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
  -> emits bundled immediate/deferred bridge callback handoff

lepusa-runtime bridge-dispatch <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
  -> executes a bundled bridge message and emits response callback script

lepusa-runtime bridge-loop <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
  -> feeds one bundled bridge message through the adapter loop and emits scripts to evaluate

lepusa-runtime bridge-drain <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
  -> runs bundled handoff callback first, then drains pending async bridge work into a delivery envelope

lepusa-runtime invoke <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
  -> dispatches a packaged bridge command through registered official native handlers

lepusa bundle-plan <target>
  -> prints platform bundle name, executable name, app identifier, file count
```

The invoke command and reusable `BundledRuntime` object enforce the packaged
manifest boundary: a route must be present in `registeredRoutes` and allowed by
the target webview's `allowedRoutes` before it reaches the native registry.
Platform loops should construct one `BundledRuntime` per app instance so
stateful handlers such as `store` survive repeated bridge calls.

Native run/build/bundle commands should consume the same `RuntimePlan` and
`BundlePlan` objects rather than maintaining parallel configuration paths.

`@lepusa/scaffold` owns standalone app and plugin skeleton generation. The CLI
commands `lepusa init` and `lepusa plugin new` are wrappers over
`write_app` and `write_plugin`, so editors, package managers, and future
ecosystem tools can create Lepusa projects without invoking the CLI. The
workspace variants `write_app_with_workspace` and
`write_plugin_with_workspace` add a local `moon.work` manifest that points at a
Lepusa checkout, giving unpublished framework builds a compileable onboarding
path without changing the publish-ready `moon.mod` dependency.

Project manifests may declare official plugins by name only. The CLI expands
official package names such as `autoLaunch`, `deepLink`, `singleInstance`,
`tray`, `updater`, `windowState`, `serviceDiscovery`, `log`, `store`, and `fs`
to their official command contracts before planning, while plugins with
explicit `commands` arrays keep their manifest-defined surface.
They may also declare `filesystemScopes`, which lower into runtime sessions and
native launch manifests as named roots. The scope data is separate from command
capabilities: capabilities decide which windows may call filesystem commands,
while scopes tell native backends where those commands are allowed to operate.

## Manifest Boundary

`ProjectManifest` owns reusable app-neutral configuration:

- app metadata
- windows and sources
- plugins and command routes
- command permission requirements and capability grants
- filesystem scopes
- startup and lifecycle command trees
- runtime config

It intentionally does not own product routes, schemas, persistent state, or
frontend component code. It lowers into `App`, `LaunchPlan`, `RuntimePlan`, and
`BundlePlan`.
Project JSON command objects map to the same portable command model as MoonBit
app code: `effect`, `emit`, `navigate`, and `batch` lower through
`RuntimePlan::actions(cmd)` into backend-executable runtime operations.

## Non-Goals

- Do not require Rust/Tauri glue in each MoonBit app.
- Do not depend on Tauri as the normal runtime.
- Do not be a compatibility-only wrapper over an existing experiment.
- Do not move app domain logic, backend routes, schemas, or product adapters
  into Lepusa.
- Do not make Rabbita mandatory for non-MoonBit frontend assets.
- Do not expose broad filesystem or shell access by default.
