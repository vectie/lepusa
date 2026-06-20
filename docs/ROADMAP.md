# Lepusa Roadmap

## Milestone 0: Standalone Foundation

- Publish `lepusa` as the public framework name.
- Own public concrete API types in `lepusa` or non-internal `lepusa/*`
  packages.
- Own `LaunchPlan`, `RuntimePlan`, and `BundlePlan` as the first native backend
  boundaries.
- Own `ProjectManifest` as the app-neutral configuration boundary.
- Import useful runtime ideas from existing experiments without making Lepusa a
  wrapper layer over them.
- Keep product-specific requirements out of core packages.

## Milestone 1: Rabbita-Style Desktop App

- Add `cell_with_dispatch`, `new`, `with_startup`, `window`, validation, and
  `launch_plan` APIs with syntax close to Rabbita.
- Lower source-less `App` windows into generated Rabbita-style HTML from the
  root `Cell`.
- Add native `run` once the first runtime backend is wired: macOS now has an
  explicit `lepusa run macos --launch` path.
- Run a desktop counter app authored in MoonBit model/update/view style.
- Support direct `WindowConfig::new(..., source=...)` hosting for non-Rabbita
  assets.
- Add a smoke test that proves the WebView is nonblank.

## Milestone 2: Native Runtime

- Add `@lepusa/runtime` host/session boundary over `RuntimePlan`.
- Add pure custom-protocol asset resolution for bridge, inline, Rabbita, and
  local assets: typed and JSON protocol-handler envelopes exist
- Add the native hook JSON codec from generated bridge requests to capability
  checked `CommandRegistry` dispatch.
- Add async command registry dispatch for native plugin handlers.
- Add per-window WebView boot specs for platform backends.
- Add a portable runtime launch manifest for WebViews, bridge hooks, protocol
  mappings, command routes, and capability grants.
- Lower `Cmd` startup trees into backend-executable runtime actions.
- Add runtime lifecycle hooks for startup, shutdown, and window close events:
  initial generic and native runner lowering exists
- Add shared `@lepusa/runtime` native backend lowering over portable runtime
  operations.
- Add `RuntimeServicePlan` as the service-specific runtime handoff for
  localhost sidecars, start order, validation, supervisor requirements, and a
  shared start/readiness/shutdown supervisor handoff with native execution
  reports, backend executor hooks, and macOS/Linux/Windows native
  process/readiness execution.
- Add `NativeRuntime` as the single platform-loop facade for backend bootstrap,
  protocol asset resolution, bridge dispatch, service supervisor
  plans/reports/executors, and lifecycle steps.
- Add a portable bridge dispatch envelope for source and bundled runtimes:
  response JSON plus the WebView callback script now flow through reusable
  runtime APIs and no-window CLI probes.
- Add a portable bridge handoff envelope for source and bundled runtimes:
  sync routes carry an immediate callback script, while async routes return a
  deferred task that platform event loops can schedule without re-decoding.
- Add `@lepusa/runtime/bundled` for packaged `lepusa/runtime.json` parsing,
  asset lookup, lifecycle action selection, and bundled service plans.
- Add `@lepusa/runtime/macos`, `@lepusa/runtime/windows`, and
  `@lepusa/runtime/linux` backend descriptor packages with host availability
  checks for WKWebView, WebView2, and WebKitGTK.
- Implement or port WebView window creation for macOS, Windows, and Linux:
  first macOS WKWebView launch path and document-start bridge injection exist;
  packaged macOS `lepusa-runtime launch` consumes `lepusa/runtime.json`;
  MoonBit-side macOS bridge message dispatch exists; Objective-C
  WKScriptMessageHandler wiring for sync command responses exists; macOS
  WKURLSchemeHandler wiring for Lepusa assets exists; macOS run plans now
  expose sync versus async bridge route metadata; runtime-owned bridge message
  preparation separates native capture from sync/async dispatch and shares hook
  bootstrap plus callback script generation across macOS, Linux, and Windows;
  source and bundled runtime bridge tasks now expose route-level sync/async
  scheduling metadata for backend event loops;
  bundled runtime bridge transport now preserves packaged plugin registry state
  across repeated bridge calls; open-window macOS launches now report
  unsupported when async routes require native scheduling; Linux now has a
  first WebKitGTK source-window loop
  for resolved HTML/file/remote URLs plus sync WebKitGTK script-message bridge
  dispatch and package-owned URI scheme asset resolution for packaged manifests;
  Windows now prepares typed WebView2 boot plans, bridge bootstrap scripts, and
  the final native launch ABI for source and packaged manifests, with that ABI
  reporting unsupported until the COM creation loop lands; source and bundled
  launch-session JSON can now advertise async-capable bridge scheduling for
  native loops that wire deferred completion, including the reusable async
  bridge executor descriptor over
  `NativeRuntime::bridge_async_dispatch_callback`; source and bundled bridge
  handoffs now expose typed deferred completion envelopes; native async bridge
  scheduling and the Windows WebView creation loop remain.
- Support `Source::html`, `Source::local_path`, `Source::packaged`,
  `Source::url`, and `Source::localhost` source modes.
- Validate native link behavior on each supported platform.

## Milestone 3: Typed IPC And Capabilities

- Stabilize `Plugin::command`, `command_sync`, async command behavior, and
  backend-to-frontend events.
- Add capability manifests and runtime permission checks: launch and bundled
  runtime manifests now carry capability grants, and dispatch already enforces
  those permissions.
- Generate a small JavaScript bridge under `window.lepusa`.
- Keep denied-command, malformed-payload, and plugin namespace collision tests
  in the IPC boundary suite as the bridge grows.

## Milestone 4: CLI

- Implement:
  - `lepusa doctor`: validates public planning boundaries and reports target
    signing prerequisites.
  - `lepusa plan`: prints a runtime plan summary.
  - `lepusa manifest`: prints the native-runner launch manifest JSON.
  - `lepusa native-plan`: prints backend bootstrap JSON for platform runners.
  - `lepusa run`: prints a no-window native runner smoke summary.
  - `lepusa bridge`: prints the generated frontend IPC bridge.
  - `lepusa asset`: prints the runtime asset protocol JSON envelope.
  - `lepusa lifecycle`: prints runtime lifecycle step JSON.
  - `lepusa bridge-task`: reports source bridge task scheduling metadata.
  - `lepusa bridge-handoff`: reports source immediate/deferred native bridge handoff.
  - `lepusa bridge-dispatch`: executes source bridge messages and reports the native callback envelope.
  - `lepusa launch-session [--async-bridge]`: emits native-loop source session JSON with optional async-capable bridge scheduler metadata.
  - `lepusa bundle-plan`: prints a target bundle plan.
  - `lepusa bundle-write`: writes planned platform bundle files.
  - `lepusa init`: writes a standalone MoonBit project skeleton.
  - `lepusa build`: alias for materializing the current bundle plan.
  - `lepusa bundle`: alias for materializing the current bundle plan.
  - `lepusa plugin new`: writes a standalone plugin package skeleton.
  - `lepusa dev`: lowers the project to a runtime development plan.
  - `lepusa-runtime --manifest`: summarizes bundled runtime data for diagnostics.
  - `lepusa-runtime run`: prepares target-aware bundled runtime launch plans without opening windows.
  - `lepusa-runtime launch`: opens the first bundled macOS WKWebView from `lepusa/runtime.json`, opens bundled Linux WebKitGTK windows when GTK3/WebKit2GTK are available, and sends Windows bundled manifests through the package-owned WebView2 launch ABI until its COM loop lands.
  - `lepusa-runtime bootstrap`: emits target-aware bundled bootstrap JSON for native loops.
  - `lepusa-runtime asset`: resolves bundled runtime assets for protocol handlers.
  - `lepusa-runtime lifecycle`: selects bundled lifecycle services and actions.
  - `lepusa-runtime bridge-task`: reports packaged bridge task scheduling metadata.
  - `lepusa-runtime bridge-handoff`: reports packaged immediate/deferred native bridge handoff.
  - `lepusa-runtime bridge-dispatch`: executes packaged bridge messages and reports the native callback envelope.
  - `lepusa-runtime launch-session [--async-bridge]`: emits packaged native-loop session JSON with optional async-capable bridge scheduler metadata.
  - `lepusa-runtime invoke`: dispatches packaged bridge calls through registered official native handlers.
- Consume standalone `lepusa.json` project manifests for planning, manifest
  generation, and bundle materialization.
- Extract `@lepusa/project` as the reusable parser for standalone
  `lepusa.json` manifests, keeping CLI file loading separate from project
  semantics.
- Extract `@lepusa/bundle` as the reusable native bundle writer over
  `BundlePlan`, keeping filesystem materialization separate from CLI commands.
- Extract `@lepusa/scaffold` as reusable app/plugin skeleton generation,
  keeping ecosystem project creation separate from CLI commands.
- Lower `lepusa.json` startup and lifecycle command trees into runtime actions.
- Support MoonBit-authored UI apps and prebuilt frontend assets.
- Make `doctor` report platform WebView dependencies and signing
  prerequisites.

## Milestone 5: Official Plugins

Stabilize the cross-platform core set first:

- dialog: initial platform-neutral command contract exists
- opener: initial platform-neutral command contract exists
- fs: scoped permission contract, runtime scope manifest, and async scoped
  text/bytes/list/metadata/delete/exists/create-directory handlers exist
- fileDialog: initial scoped default-directory contract exists
- shell: initial platform-neutral command contract exists
- process: initial explicit process permission contract exists
- clipboard: initial platform-neutral command contract exists
- notification: initial platform-neutral command contract exists
- log: initial pure command-registry package exists
- store: initial pure command-registry package exists
- localhost: initial local service lifecycle contract exists
- deepLink: initial app URL scheme contract exists
- singleInstance: initial app lock and launch handoff contract exists
- tray: initial status icon and menu contract exists
- autoLaunch: initial launch-at-login contract exists
- windowState: initial window geometry persistence contract exists
- updater: initial update lifecycle contract exists
- serviceDiscovery: initial service lookup and status contract exists

Plugins with mobile-only or platform-specific behavior can follow after the
desktop core is reliable.

## Milestone 6: Bundling

- macOS `.app` and DMG artifact paths are represented in `BundlePlan`.
- Windows executable and installer artifact paths are represented in
  `BundlePlan`.
- Linux desktop integration and portable bundle artifact paths are represented
  in `BundlePlan`.
- `BundlePlan::files()` emits platform metadata, launcher stubs, and one
  runtime manifest with per-window bridge initialization scripts.
- `BundlePlan::resources()` emits target resource mappings for app icons and
  packaged asset directories.
- `BundlePlan::signing_prerequisites()` emits target signing, notarization, and
  package validation requirements.
- App metadata manifest: id, product name, version, icons, capabilities,
  assets, sidecars, typed signing options, and target-aware signing steps now
  flow into bundle manifests.
- `@lepusa/bundle` verifies materialized bundle files, resources, and runtime
  manifests after `bundle-write` as the pre-install smoke boundary.
- Clean-machine install tests per platform.

## Milestone 7: Foundation Proof

- Build at least three example apps:
  - MoonBit-authored Rabbita-style UI app exists under `examples/rabbita`.
  - Static asset app from a local `dist/` directory exists under
    `examples/static`.
  - Localhost gateway app with sidecar/service readiness exists under
    `examples/gateway`.
- Verify each example can run in dev mode and bundle mode: CLI smoke tests
  cover dev and bundle mode for all three examples.
- Document how third-party MoonBit projects create, bundle, sign, and publish
  desktop apps.
