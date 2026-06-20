# Lepusa service discovery plugin

`@lepusa/plugins/service_discovery` declares a compact native contract for
discovering app-local and companion services without choosing a transport
backend. Its portable registry exposes configured endpoint metadata through
`list`, `resolve`, `status`, and `watch` handlers; native runtimes own live
resolver integration, health checks, and change notifications.

```moonbit no-check
///|
let plugin = @service_discovery.plugin()

///|
let grant = @service_discovery.capability_for_window("main")

///|
let policy = @service_discovery.ServiceDiscoveryPolicy::new().service(
  @service_discovery.ServiceEndpoint::new(
    name="api",
    url="http://127.0.0.1:8080",
    health_path="/health",
  ),
)

///|
let registry = @service_discovery.registry(policy~)
```

The manifest routes are `serviceDiscovery.list`, `serviceDiscovery.resolve`,
`serviceDiscovery.status`, `serviceDiscovery.watch`, and
`serviceDiscovery.onServiceChanged`.
