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
- Add native `run` once the first runtime backend is wired.
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
- Add per-window WebView boot specs for platform backends.
- Add a portable runtime launch manifest for WebViews, bridge hooks, protocol
  mappings, and command routes.
- Lower `Cmd` startup trees into backend-executable runtime actions.
- Add runtime lifecycle hooks for startup, shutdown, and window close events:
  initial generic and native runner lowering exists
- Add shared `@lepusa/runtime` native backend lowering over portable runtime
  operations.
- Add `@lepusa/runtime/macos`, `@lepusa/runtime/windows`, and
  `@lepusa/runtime/linux` backend descriptor packages with host availability
  checks for WKWebView, WebView2, and WebKitGTK.
- Implement or port WebView window creation for macOS, Windows, and Linux.
- Support `Source::html`, `Source::local_path`, `Source::packaged`,
  `Source::url`, and `Source::localhost` source modes.
- Validate native link behavior on each supported platform.

## Milestone 3: Typed IPC And Capabilities

- Stabilize `Plugin::command`, `command_sync`, async command behavior, and
  backend-to-frontend events.
- Add capability manifests and runtime permission checks.
- Generate a small JavaScript bridge under `window.lepusa`.
- Add tests for denied commands, malformed payloads, and plugin namespace
  collisions.

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
  - `lepusa bundle-plan`: prints a target bundle plan.
  - `lepusa bundle-write`: writes planned platform bundle files.
  - `lepusa init`: writes a standalone MoonBit project skeleton.
  - `lepusa build`: alias for materializing the current bundle plan.
  - `lepusa bundle`: alias for materializing the current bundle plan.
  - `lepusa plugin new`: writes a standalone plugin package skeleton.
  - `lepusa dev`: lowers the project to a runtime development plan.
  - `lepusa-runtime --manifest`: reads bundled runtime data for launcher stubs.
  - `lepusa-runtime asset`: resolves bundled runtime assets for protocol handlers.
- Consume standalone `lepusa.json` project manifests for planning, manifest
  generation, and bundle materialization.
- Lower `lepusa.json` startup and lifecycle command trees into runtime actions.
- Support MoonBit-authored UI apps and prebuilt frontend assets.
- Make `doctor` report platform WebView dependencies and signing
  prerequisites.

## Milestone 5: Official Plugins

Stabilize the cross-platform core set first:

- dialog: initial platform-neutral command contract exists
- opener: initial platform-neutral command contract exists
- fs: initial scoped permission contract and runtime scope manifest exist
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

- macOS `.app` and DMG path.
- Windows executable and installer path.
- Linux desktop integration and portable bundle path.
- `BundlePlan::files()` emits platform metadata, launcher stubs, and one
  runtime manifest with per-window bridge initialization scripts.
- `BundlePlan::resources()` emits target resource mappings for app icons and
  packaged asset directories.
- `BundlePlan::signing_prerequisites()` emits target signing, notarization, and
  package validation requirements.
- App metadata manifest: id, product name, version, icons, capabilities,
  assets, sidecars, signing options.
- Clean-machine install tests per platform.

## Milestone 7: Foundation Proof

- Build at least three example apps:
  - MoonBit-authored Rabbita-style UI app exists under `examples/rabbita`.
  - Static asset app from a local `dist/` directory exists under
    `examples/static`.
  - Localhost gateway app with sidecar/service readiness exists under
    `examples/gateway`.
- Verify each example can run in dev mode and bundle mode: CLI smoke tests
  cover dev mode for all three examples and bundle mode for the static example.
- Document how third-party MoonBit projects create, bundle, sign, and publish
  desktop apps.
